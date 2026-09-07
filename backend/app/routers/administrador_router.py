from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.security import get_usuario_atual
from app.models import TipoPerfil, Usuario
from app.schemas.evento_schema import EventoResponse

router = APIRouter(prefix="/administrador", tags=["Administrador"])


def _exigir_administrador(usuario: dict = Depends(get_usuario_atual)):
    if usuario["perfil"] != TipoPerfil.ADMINISTRADOR.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas administradores podem acessar esta rota.",
        )
    return usuario


@router.get("/meus-eventos", response_model=List[EventoResponse])
def meus_eventos(
    db: Session = Depends(get_db),
    usuario: dict = Depends(_exigir_administrador),
):
    admin = db.query(Usuario).filter(Usuario.id == usuario["id"]).first()
    if not admin:
        raise HTTPException(status_code=404, detail="Usuário não encontrado.")

    return admin.eventos_administrados
