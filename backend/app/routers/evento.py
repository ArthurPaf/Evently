from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app import security
from app.controllers import evento_controller
from app.models import TipoPerfil
from app.schemas import evento_schema, barraca_schema

router = APIRouter(prefix="/eventos", tags=["Gestão de Eventos"])

@router.post("/", response_model=evento_schema.EventoResponse)
def criar_evento(
    evento: evento_schema.EventoCreate, 
    db: Session = Depends(get_db),
    usuario = Depends(security.get_usuario_atual)
):
    if usuario["perfil"] != TipoPerfil.ORGANIZADOR.value:
        raise HTTPException(status_code=403, detail="Apenas organizadores podem criar eventos.")
    
    return evento_controller.criar_evento(db, evento, usuario["id"])

@router.get("/", response_model=List[evento_schema.EventoResponse])
def listar_eventos(
    db: Session = Depends(get_db),
    usuario = Depends(security.get_usuario_atual)
):
    return evento_controller.listar_eventos_do_organizador(db, usuario["id"])

@router.post("/barracas", response_model=barraca_schema.BarracaResponse)
def criar_barraca(
    barraca: barraca_schema.BarracaCreate,
    db: Session = Depends(get_db),
    usuario = Depends(security.get_usuario_atual)
):
    if usuario["perfil"] != TipoPerfil.ORGANIZADOR.value:
        raise HTTPException(status_code=403, detail="Apenas organizadores podem criar barracas.")
    
    return evento_controller.criar_barraca(db, barraca)