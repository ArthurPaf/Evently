from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.schemas.barraca_schema import BarracaCreate, BarracaResponse
from app.daos import barraca_dao
from app.security import get_usuario_atual

router = APIRouter(prefix="/eventos/{evento_id}/barracas", tags=["Barracas"])

@router.post("/", response_model=BarracaResponse)
def criar_barraca_evento(
    evento_id: int, 
    barraca: BarracaCreate, 
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual)
):
    # Corrigido de usuario_atual.id para usuario.id
    return barraca_dao.criar_barraca(db, barraca, evento_id, responsavel_id=usuario["id"])

@router.get("/", response_model=List[BarracaResponse])
def listar_barracas_evento(
    evento_id: int, 
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual)
):
    return barraca_dao.listar_barracas_por_evento(db, evento_id)