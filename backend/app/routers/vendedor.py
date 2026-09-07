from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.security import get_usuario_atual
from app.models import TipoPerfil, Usuario
from app.schemas.barraca_schema import BarracaResponse
from app.schemas.evento_schema import EventoResponse

router = APIRouter(prefix="/vendedor", tags=["Vendedor"])


def _exigir_vendedor(usuario: dict = Depends(get_usuario_atual)):
    if usuario["perfil"] != TipoPerfil.VENDEDOR.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas vendedores podem acessar esta rota.",
        )
    return usuario


def _buscar_vendedor(db: Session, usuario_id: int) -> Usuario:
    vendedor = db.query(Usuario).filter(Usuario.id == usuario_id).first()
    if not vendedor:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")
    return vendedor


@router.get("/meus-eventos", response_model=List[EventoResponse])
def meus_eventos(
    db: Session = Depends(get_db),
    usuario: dict = Depends(_exigir_vendedor),
):
    vendedor = _buscar_vendedor(db, usuario["id"])

    # Pega os eventos (sem repetir) das barracas em que o vendedor está vinculado
    eventos_vistos = {}
    for barraca in vendedor.barracas_vendidas:
        eventos_vistos[barraca.evento_id] = barraca.evento

    return list(eventos_vistos.values())


@router.get("/eventos/{evento_id}/barracas", response_model=List[BarracaResponse])
def minhas_barracas_no_evento(
    evento_id: int,
    db: Session = Depends(get_db),
    usuario: dict = Depends(_exigir_vendedor),
):
    vendedor = _buscar_vendedor(db, usuario["id"])

    # Filtra apenas as barracas desse vendedor que pertencem a esse evento
    return [
        barraca
        for barraca in vendedor.barracas_vendidas
        if barraca.evento_id == evento_id
    ]