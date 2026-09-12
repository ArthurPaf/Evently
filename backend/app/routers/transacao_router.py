from sqlalchemy import func, desc
from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.security import get_usuario_atual
from app.models import (
    TipoPerfil, Evento, Barraca, Carteira, Transacao,
    ItemTransacao, TipoTransacao, Produto, Usuario,
)
from app.permissions import usuario_gerencia_evento
from app.controllers.transacao_controller import realizar_recarga, realizar_venda
from app.relatorio_utils import gerar_relatorio_pdf
from app.schemas.carteira_schema import RecargaCreate, VendaCreate, TransacaoResponse

router = APIRouter(tags=["Transações"])


# --- RECARGA (organizador dono ou administrador vinculado ao evento) ---

@router.post(
    "/eventos/{evento_id}/recargas",
    response_model=TransacaoResponse,
    status_code=status.HTTP_201_CREATED,
)
def criar_recarga(
    evento_id: int,
    dados: RecargaCreate,
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual),
):
    evento = db.query(Evento).filter(Evento.id == evento_id).first()
    if not evento:
        raise HTTPException(status_code=404, detail="Evento não encontrado.")
    if not usuario_gerencia_evento(db, evento, usuario):
        raise HTTPException(
            status_code=403, detail="Sem permissão para realizar recargas neste evento."
        )

    return realizar_recarga(db, evento_id, dados, realizado_por_id=usuario["id"])


# --- VENDA (vendedor vinculado à barraca, ou organizador/admin do evento) ---

def _usuario_pode_vender_na_barraca(db: Session, barraca: Barraca, usuario: dict) -> bool:
    if usuario["perfil"] == TipoPerfil.VENDEDOR.value:
        vendedor = db.query(Usuario).filter(Usuario.id == usuario["id"]).first()
        return vendedor is not None and barraca in vendedor.barracas_vendidas
    return usuario_gerencia_evento(db, barraca.evento, usuario)


@router.post(
    "/barracas/{barraca_id}/vendas",
    response_model=TransacaoResponse,
    status_code=status.HTTP_201_CREATED,
)
def criar_venda(
    barraca_id: int,
    dados: VendaCreate,
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual),
):
    barraca = db.query(Barraca).filter(Barraca.id == barraca_id).first()
    if not barraca:
        raise HTTPException(status_code=404, detail="Barraca não encontrada.")

    if not _usuario_pode_vender_na_barraca(db, barraca, usuario):
        raise HTTPException(status_code=403, detail="Sem permissão para vender nesta barraca.")

    return realizar_venda(db, barraca_id, dados, vendedor_id=usuario["id"])


# --- DASHBOARD (exclusivo do organizador dono — administrador não vê dados financeiros) ---

def _calcular_dashboard(db: Session, evento_id: int) -> dict:
    """
    Monta os dados do dashboard. Compartilhado entre a rota que retorna JSON
    (para exibir no app) e a rota que exporta o relatório em PDF, evitando
    duplicar a mesma lógica de consulta nos dois lugares.
    """
    base_vendas = (
        db.query(Transacao)
        .join(Carteira, Transacao.carteira_id == Carteira.id)
        .filter(Carteira.evento_id == evento_id, Transacao.tipo == TipoTransacao.VENDA)
    )

    total_vendido = base_vendas.with_entities(
        func.coalesce(func.sum(Transacao.valor_total), 0.0)
    ).scalar()
    numero_transacoes = base_vendas.count()

    produtos_mais_vendidos = (
        db.query(
            Produto.nome,
            func.sum(ItemTransacao.quantidade).label("quantidade_total"),
            func.sum(ItemTransacao.quantidade * ItemTransacao.preco_unitario).label("valor_total"),
        )
        .join(Transacao, ItemTransacao.transacao_id == Transacao.id)
        .join(Carteira, Transacao.carteira_id == Carteira.id)
        .join(Produto, ItemTransacao.produto_id == Produto.id)
        .filter(Carteira.evento_id == evento_id, Transacao.tipo == TipoTransacao.VENDA)
        .group_by(Produto.nome)
        .order_by(func.sum(ItemTransacao.quantidade).desc())
        .limit(10)
        .all()
    )

    # Vendas por barraca — ordenado da que mais lucrou para a que menos lucrou
    vendas_por_barraca = (
        db.query(
            Barraca.nome,
            func.coalesce(func.sum(Transacao.valor_total), 0.0).label("valor_total"),
        )
        .join(Transacao, Transacao.barraca_id == Barraca.id)
        .join(Carteira, Transacao.carteira_id == Carteira.id)
        .filter(Carteira.evento_id == evento_id, Transacao.tipo == TipoTransacao.VENDA)
        .group_by(Barraca.nome)
        .order_by(desc("valor_total"))
        .all()
    )

    # O banco grava em UTC (datetime.utcnow()); convertemos para o horário
    # do Brasil antes de agrupar, senão o gráfico fica adiantado.
    data_hora_local = func.timezone(
        "America/Sao_Paulo", func.timezone("UTC", Transacao.data_hora)
    )
    # Agrupa por DIA + HORA (não só hora), para não misturar horários de
    # dias diferentes em eventos de 2, 3 ou mais dias.
    periodo_expr = func.date_trunc("hour", data_hora_local)

    vendas_por_periodo_raw = (
        db.query(
            periodo_expr.label("periodo"),
            func.coalesce(func.sum(Transacao.valor_total), 0.0).label("valor_total"),
        )
        .join(Carteira, Transacao.carteira_id == Carteira.id)
        .filter(Carteira.evento_id == evento_id, Transacao.tipo == TipoTransacao.VENDA)
        .group_by(periodo_expr)
        .order_by(periodo_expr)
        .all()
    )

    vendas_por_periodo = [
        {"periodo": periodo.strftime("%d/%m %Hh"), "valor_total": float(valor)}
        for periodo, valor in vendas_por_periodo_raw
    ]

    return {
        "total_vendido": total_vendido,
        "numero_transacoes": numero_transacoes,
        "produtos_mais_vendidos": [
            {"nome": nome, "quantidade": int(qtd), "valor_total": float(valor)}
            for nome, qtd, valor in produtos_mais_vendidos
        ],
        "vendas_por_barraca": [
            {"barraca": nome, "valor_total": float(valor)} for nome, valor in vendas_por_barraca
        ],
        "vendas_por_periodo": vendas_por_periodo,
    }


def _verificar_acesso_dashboard(db: Session, evento_id: int, usuario: dict) -> Evento:
    evento = db.query(Evento).filter(Evento.id == evento_id).first()
    if not evento:
        raise HTTPException(status_code=404, detail="Evento não encontrado.")
    if (
        usuario["perfil"] != TipoPerfil.ORGANIZADOR.value
        or evento.organizador_id != usuario["id"]
    ):
        raise HTTPException(
            status_code=403,
            detail="Apenas o organizador do evento pode ver o dashboard financeiro.",
        )
    return evento


@router.get("/eventos/{evento_id}/dashboard")
def dashboard_evento(
    evento_id: int,
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual),
):
    _verificar_acesso_dashboard(db, evento_id, usuario)
    return _calcular_dashboard(db, evento_id)


@router.get("/eventos/{evento_id}/dashboard/exportar")
def exportar_dashboard_pdf(
    evento_id: int,
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual),
):
    evento = _verificar_acesso_dashboard(db, evento_id, usuario)
    dados = _calcular_dashboard(db, evento_id)
    pdf_bytes = gerar_relatorio_pdf(evento.nome, dados)

    nome_arquivo = f"relatorio_{evento.nome}.pdf".replace(" ", "_")
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{nome_arquivo}"'},
    )