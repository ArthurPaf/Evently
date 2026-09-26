from typing import List
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
from app.controllers.transacao_controller import (
    realizar_recarga, realizar_venda, estornar_venda, realizar_reembolso,
)
from app.relatorio_utils import gerar_relatorio_pdf
from app.relatorio_excel_utils import gerar_relatorio_excel
from app.schemas.carteira_schema import (
    RecargaCreate, VendaCreate, ReembolsoCreate, TransacaoResponse,
)

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


@router.get("/barracas/{barraca_id}/vendas", response_model=List[TransacaoResponse])
def listar_vendas_da_barraca(
    barraca_id: int,
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual),
):
    """Últimas vendas da barraca — usado pelo vendedor para localizar uma venda a estornar."""
    barraca = db.query(Barraca).filter(Barraca.id == barraca_id).first()
    if not barraca:
        raise HTTPException(status_code=404, detail="Barraca não encontrada.")
    if not _usuario_pode_vender_na_barraca(db, barraca, usuario):
        raise HTTPException(status_code=403, detail="Sem permissão para ver vendas desta barraca.")

    return (
        db.query(Transacao)
        .filter(Transacao.barraca_id == barraca_id, Transacao.tipo == TipoTransacao.VENDA)
        .order_by(Transacao.data_hora.desc())
        .limit(50)
        .all()
    )


# --- ESTORNO DE VENDA ---

@router.post(
    "/transacoes/{transacao_id}/estornar",
    response_model=TransacaoResponse,
    status_code=status.HTTP_201_CREATED,
)
def estornar_transacao(
    transacao_id: int,
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual),
):
    venda = db.query(Transacao).filter(Transacao.id == transacao_id).first()
    if not venda:
        raise HTTPException(status_code=404, detail="Transação não encontrada.")

    carteira = db.query(Carteira).filter(Carteira.id == venda.carteira_id).first()
    evento = db.query(Evento).filter(Evento.id == carteira.evento_id).first() if carteira else None

    # Permissão: organizador/admin do evento, OU o próprio vendedor que
    # processou a venda (pode corrigir o próprio erro na hora).
    pode_estornar = False
    if evento and usuario_gerencia_evento(db, evento, usuario):
        pode_estornar = True
    elif usuario["perfil"] == TipoPerfil.VENDEDOR.value and venda.realizado_por_id == usuario["id"]:
        pode_estornar = True

    if not pode_estornar:
        raise HTTPException(status_code=403, detail="Sem permissão para estornar esta venda.")

    return estornar_venda(db, transacao_id, realizado_por_id=usuario["id"])


# --- REEMBOLSO DE SALDO (organizador dono ou administrador vinculado ao evento) ---

@router.post(
    "/eventos/{evento_id}/reembolsos",
    response_model=TransacaoResponse,
    status_code=status.HTTP_201_CREATED,
)
def criar_reembolso(
    evento_id: int,
    dados: ReembolsoCreate,
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual),
):
    evento = db.query(Evento).filter(Evento.id == evento_id).first()
    if not evento:
        raise HTTPException(status_code=404, detail="Evento não encontrado.")
    if not usuario_gerencia_evento(db, evento, usuario):
        raise HTTPException(
            status_code=403, detail="Sem permissão para reembolsar clientes deste evento."
        )

    return realizar_reembolso(
        db, evento_id, dados.codigo_identificador, dados.valor, realizado_por_id=usuario["id"]
    )


# --- DASHBOARD (exclusivo do organizador dono — administrador não vê dados financeiros) ---

def _calcular_vendas_por_vendedor(db: Session, evento_id: int) -> list:
    vendas = (
        db.query(
            Usuario.id,
            Usuario.nome,
            func.count(Transacao.id),
            func.sum(Transacao.valor_total),
        )
        .select_from(Transacao)
        .join(Carteira, Transacao.carteira_id == Carteira.id)
        .join(Usuario, Transacao.realizado_por_id == Usuario.id)
        .filter(
            Carteira.evento_id == evento_id,
            Usuario.perfil == TipoPerfil.VENDEDOR,
            Transacao.tipo == TipoTransacao.VENDA,
            Transacao.estornada == False,  # noqa: E712
        )
        .group_by(Usuario.id, Usuario.nome)
        .order_by(func.sum(Transacao.valor_total).desc(), Usuario.id)
        .all()
    )
    return [
        {"vendedor_id": usuario_id, "vendedor": nome,
         "numero_vendas": int(quantidade), "valor_total": float(total)}
        for usuario_id, nome, quantidade, total in vendas
    ]


def _calcular_dashboard(db: Session, evento_id: int) -> dict:
    base_vendas = (
        db.query(Transacao)
        .join(Carteira, Transacao.carteira_id == Carteira.id)
        .filter(
            Carteira.evento_id == evento_id,
            Transacao.tipo == TipoTransacao.VENDA,
            Transacao.estornada == False,  # noqa: E712 — vendas estornadas não contam como receita
        )
    )

    total_vendido = base_vendas.with_entities(
        func.coalesce(func.sum(Transacao.valor_total), 0.0)
    ).scalar()
    numero_transacoes = base_vendas.count()

    total_reembolsado = (
        db.query(func.coalesce(func.sum(Transacao.valor_total), 0.0))
        .join(Carteira, Transacao.carteira_id == Carteira.id)
        .filter(Carteira.evento_id == evento_id, Transacao.tipo == TipoTransacao.REEMBOLSO)
        .scalar()
    )

    numero_estornos = (
        db.query(Transacao)
        .join(Carteira, Transacao.carteira_id == Carteira.id)
        .filter(Carteira.evento_id == evento_id, Transacao.tipo == TipoTransacao.ESTORNO)
        .count()
    )

    produtos_mais_vendidos = (
        db.query(
            Produto.nome,
            func.sum(ItemTransacao.quantidade).label("quantidade_total"),
            func.sum(ItemTransacao.quantidade * ItemTransacao.preco_unitario).label("valor_total"),
        )
        .join(Transacao, ItemTransacao.transacao_id == Transacao.id)
        .join(Carteira, Transacao.carteira_id == Carteira.id)
        .join(Produto, ItemTransacao.produto_id == Produto.id)
        .filter(
            Carteira.evento_id == evento_id,
            Transacao.tipo == TipoTransacao.VENDA,
            Transacao.estornada == False,  # noqa: E712
        )
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
        .filter(
            Carteira.evento_id == evento_id,
            Transacao.tipo == TipoTransacao.VENDA,
            Transacao.estornada == False,  # noqa: E712
        )
        .group_by(Barraca.nome)
        .order_by(desc("valor_total"))
        .all()
    )

    data_hora_local = func.timezone(
        "America/Sao_Paulo", func.timezone("UTC", Transacao.data_hora)
    )
    periodo_expr = func.date_trunc("hour", data_hora_local)

    vendas_por_periodo_raw = (
        db.query(
            periodo_expr.label("periodo"),
            func.coalesce(func.sum(Transacao.valor_total), 0.0).label("valor_total"),
        )
        .join(Carteira, Transacao.carteira_id == Carteira.id)
        .filter(
            Carteira.evento_id == evento_id,
            Transacao.tipo == TipoTransacao.VENDA,
            Transacao.estornada == False,  # noqa: E712
        )
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
        "total_reembolsado": total_reembolsado,
        "numero_estornos": numero_estornos,
        "vendas_por_vendedor": _calcular_vendas_por_vendedor(db, evento_id),
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


@router.get("/eventos/{evento_id}/dashboard/exportar-excel")
def exportar_dashboard_excel(
    evento_id: int,
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual),
):
    evento = _verificar_acesso_dashboard(db, evento_id, usuario)
    dados = _calcular_dashboard(db, evento_id)
    excel_bytes = gerar_relatorio_excel(evento.nome, dados)

    nome_arquivo = f"relatorio_{evento.nome}.xlsx".replace(" ", "_")
    return Response(
        content=excel_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{nome_arquivo}"'},
    )
