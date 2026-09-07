from sqlalchemy import func
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.security import get_usuario_atual
from app.models import (
    TipoPerfil, Evento, Barraca, Carteira, Transacao,
    ItemTransacao, TipoTransacao, Produto, Usuario,
)
from app.permissions import usuario_gerencia_evento
from app.controllers.transacao_controller import realizar_recarga, realizar_venda
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


# --- DASHBOARD (organizador dono ou administrador vinculado ao evento) ---

@router.get("/eventos/{evento_id}/dashboard")
def dashboard_evento(
    evento_id: int,
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual),
):
    evento = db.query(Evento).filter(Evento.id == evento_id).first()
    if not evento:
        raise HTTPException(status_code=404, detail="Evento não encontrado.")
    if not usuario_gerencia_evento(db, evento, usuario):
        raise HTTPException(
            status_code=403, detail="Sem permissão para ver o dashboard deste evento."
        )

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

    vendas_por_barraca = (
        db.query(
            Barraca.nome,
            func.coalesce(func.sum(Transacao.valor_total), 0.0).label("valor_total"),
        )
        .join(Transacao, Transacao.barraca_id == Barraca.id)
        .join(Carteira, Transacao.carteira_id == Carteira.id)
        .filter(Carteira.evento_id == evento_id, Transacao.tipo == TipoTransacao.VENDA)
        .group_by(Barraca.nome)
        .all()
    )

    vendas_por_hora = (
        db.query(
            func.extract("hour", Transacao.data_hora).label("hora"),
            func.coalesce(func.sum(Transacao.valor_total), 0.0).label("valor_total"),
        )
        .join(Carteira, Transacao.carteira_id == Carteira.id)
        .filter(Carteira.evento_id == evento_id, Transacao.tipo == TipoTransacao.VENDA)
        .group_by(func.extract("hour", Transacao.data_hora))
        .order_by("hora")
        .all()
    )

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
        "vendas_por_hora": [
            {"hora": int(hora), "valor_total": float(valor)} for hora, valor in vendas_por_hora
        ],
    }