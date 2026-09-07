from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.daos.barraca_dao import BarracaDAO
from app.database import get_db
from app.schemas.barraca_schema import BarracaCreate, BarracaResponse, BarracaUpdate
from app.security import get_usuario_atual
from app.models import Evento
from app.permissions import usuario_gerencia_evento, buscar_evento_por_barraca

router = APIRouter(prefix="/eventos/{evento_id}/barracas", tags=["Barracas"])
barraca_direct_router = APIRouter(prefix="/barracas", tags=["Barracas"])


def _verificar_acesso_por_evento_id(evento_id: int, db: Session, usuario: dict) -> Evento:
    evento = db.query(Evento).filter(Evento.id == evento_id).first()
    if not evento:
        raise HTTPException(status_code=404, detail="Evento não encontrado.")
    if not usuario_gerencia_evento(db, evento, usuario):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Sem permissão para gerenciar barracas deste evento.",
        )
    return evento


@router.post("/", response_model=BarracaResponse, status_code=status.HTTP_201_CREATED)
def criar_barraca_evento(
    evento_id: int,
    barraca: BarracaCreate,
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual),
):
    _verificar_acesso_por_evento_id(evento_id, db, usuario)
    return BarracaDAO.criar_barraca(
        db, barraca, evento_id, responsavel_id=usuario["id"]
    )


@router.get("/", response_model=List[BarracaResponse])
def listar_barracas_evento(
    evento_id: int,
    db: Session = Depends(get_db),
):
    return BarracaDAO.listar_barracas_por_evento(db, evento_id)


# --- ROTAS DE EDIÇÃO E EXCLUSÃO ---

@barraca_direct_router.put("/{barraca_id}/", response_model=BarracaResponse)
def atualizar_barraca(
    barraca_id: int,
    barraca_data: BarracaUpdate,
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual),
):
    evento = buscar_evento_por_barraca(db, barraca_id)
    if not evento:
        raise HTTPException(status_code=404, detail="Barraca não encontrada.")
    if not usuario_gerencia_evento(db, evento, usuario):
        raise HTTPException(status_code=403, detail="Sem permissão para editar esta barraca.")

    barraca_atualizada = BarracaDAO.atualizar_barraca(db, barraca_id, barraca_data)
    if not barraca_atualizada:
        raise HTTPException(status_code=404, detail="Barraca não encontrada.")
    return barraca_atualizada


@barraca_direct_router.delete("/{barraca_id}/", status_code=status.HTTP_200_OK)
def deletar_barraca(
    barraca_id: int,
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual),
):
    evento = buscar_evento_por_barraca(db, barraca_id)
    if not evento:
        raise HTTPException(status_code=404, detail="Barraca não encontrada.")
    if not usuario_gerencia_evento(db, evento, usuario):
        raise HTTPException(status_code=403, detail="Sem permissão para excluir esta barraca.")

    sucesso = BarracaDAO.deletar_barraca(db, barraca_id)
    if not sucesso:
        raise HTTPException(status_code=404, detail="Barraca não encontrada.")
    return {"mensagem": "Barraca excluída com sucesso."}