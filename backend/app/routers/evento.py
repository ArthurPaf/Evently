from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app import security
from app.controllers import evento_controller
from app.daos.evento_dao import EventoDAO
from app.models import TipoPerfil
from app.models.evento_model import Evento
from app.permissions import usuario_gerencia_evento
from app.schemas import evento_schema, barraca_schema

router = APIRouter(prefix="/eventos", tags=["Gestão de Eventos"])


def _exigir_organizador(usuario: dict = Depends(security.get_usuario_atual)):
    if usuario["perfil"] != TipoPerfil.ORGANIZADOR.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas organizadores podem realizar esta ação.",
        )
    return usuario


@router.post("/", response_model=evento_schema.EventoResponse)
def criar_evento(
    evento: evento_schema.EventoCreate,
    db: Session = Depends(get_db),
    usuario=Depends(_exigir_organizador),  # só organizador cria eventos
):
    return evento_controller.criar_evento(db, evento, usuario["id"])


@router.get("/", response_model=List[evento_schema.EventoResponse])
def listar_eventos(
    db: Session = Depends(get_db),
    usuario=Depends(_exigir_organizador),
):
    return evento_controller.listar_eventos_do_organizador(db, usuario["id"])


@router.post("/barracas", response_model=barraca_schema.BarracaResponse)
def criar_barraca(
    barraca: barraca_schema.BarracaCreate,
    db: Session = Depends(get_db),
    usuario=Depends(_exigir_organizador),
):
    return evento_controller.criar_barraca(db, barraca)


@router.get("/publicos", response_model=List[evento_schema.EventoResponse])
def listar_eventos_publicos(
    db: Session = Depends(get_db),
    usuario: dict = Depends(security.get_usuario_atual),  # qualquer perfil logado (inclusive cliente)
):
    return db.query(Evento).all()


@router.put("/{evento_id}", response_model=evento_schema.EventoResponse)
def editar_evento(
    evento_id: int,
    evento: evento_schema.EventoCreate,
    db: Session = Depends(get_db),
    usuario: dict = Depends(security.get_usuario_atual),  # organizador OU administrador vinculado
):
    evento_existente = EventoDAO.buscar_por_id(db, evento_id)
    if not evento_existente:
        raise HTTPException(status_code=404, detail="Evento não encontrado.")

    if not usuario_gerencia_evento(db, evento_existente, usuario):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Sem permissão para editar este evento.",
        )

    # Sempre passa o dono real pro controller, pra não quebrar a checagem
    # interna dele (que compara organizador_id == organizador_id do dono).
    return evento_controller.editar_evento(
        db, evento_id, evento, evento_existente.organizador_id
    )


@router.delete("/{evento_id}", status_code=status.HTTP_204_NO_CONTENT)
def deletar_evento(
    evento_id: int,
    db: Session = Depends(get_db),
    usuario: dict = Depends(_exigir_organizador),  # exclusão continua só do organizador dono
):
    evento = db.query(Evento).filter(Evento.id == evento_id).first()

    if not evento:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Evento não encontrado",
        )

    if evento.organizador_id != usuario["id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Sem permissão para excluir este evento.",
        )

    db.delete(evento)
    db.commit()
    return None