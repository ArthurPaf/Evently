from typing import List
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.security import get_usuario_atual
from app.models import TipoPerfil, Carteira, Transacao, Usuario, Evento
from app.controllers.transacao_controller import buscar_ou_criar_carteira
from app.email_utils import enviar_cartao_virtual
from app.schemas.carteira_schema import CarteiraResponse, TransacaoResponse

router = APIRouter(prefix="/clientes", tags=["Cliente / Carteira Digital"])


def _exigir_cliente(usuario: dict = Depends(get_usuario_atual)):
    if usuario["perfil"] != TipoPerfil.CLIENTE.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas clientes podem acessar esta rota.",
        )
    return usuario


@router.post("/eventos/{evento_id}/entrar", response_model=CarteiraResponse)
def entrar_no_evento(
    evento_id: int,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    usuario: dict = Depends(_exigir_cliente),
):
    """Cria (ou retorna, se já existir) a carteira digital do cliente para este evento."""
    carteira, criada_agora = buscar_ou_criar_carteira(db, usuario["id"], evento_id)

    if criada_agora:
        cliente = db.query(Usuario).filter(Usuario.id == usuario["id"]).first()
        evento = db.query(Evento).filter(Evento.id == evento_id).first()
        if cliente and evento:
            # Não bloqueia a resposta: o envio acontece em segundo plano
            background_tasks.add_task(
                enviar_cartao_virtual,
                cliente.email,
                cliente.nome,
                evento.nome,
                carteira.codigo_identificador,
            )

    return carteira


@router.get("/eventos/{evento_id}/minha-carteira", response_model=CarteiraResponse)
def minha_carteira(
    evento_id: int,
    db: Session = Depends(get_db),
    usuario: dict = Depends(_exigir_cliente),
):
    carteira = (
        db.query(Carteira)
        .filter(Carteira.cliente_id == usuario["id"], Carteira.evento_id == evento_id)
        .first()
    )
    if not carteira:
        raise HTTPException(
            status_code=404, detail="Você ainda não possui carteira para este evento."
        )
    return carteira


@router.get("/carteiras/{carteira_id}/extrato", response_model=List[TransacaoResponse])
def meu_extrato(
    carteira_id: int,
    db: Session = Depends(get_db),
    usuario: dict = Depends(_exigir_cliente),
):
    carteira = db.query(Carteira).filter(Carteira.id == carteira_id).first()
    if not carteira:
        raise HTTPException(status_code=404, detail="Carteira não encontrada.")
    if carteira.cliente_id != usuario["id"]:
        raise HTTPException(status_code=403, detail="Sem permissão para ver este extrato.")

    return (
        db.query(Transacao)
        .filter(Transacao.carteira_id == carteira_id)
        .order_by(Transacao.data_hora.desc())
        .all()
    )