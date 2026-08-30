from sqlalchemy.orm import Session
from fastapi import HTTPException
from app import schemas
from app.daos.evento_dao import EventoDAO, BarracaDAO

def criar_evento(db: Session, evento: schemas.EventoCreate, organizador_id: int):
    # Regra de negócio: A data de fim não pode ser menor que a data de início
    if evento.data_fim < evento.data_inicio:
        raise HTTPException(status_code=400, detail="Data de término não pode ser anterior à data de início.")
    
    return EventoDAO.criar_evento(db, evento, organizador_id)

def listar_eventos_do_organizador(db: Session, organizador_id: int):
    return EventoDAO.listar_por_organizador(db, organizador_id)

def criar_barraca(db: Session, barraca: schemas.BarracaCreate):
    # Regra de negócio: Validar se o evento ao qual a barraca será vinculada realmente existe
    evento_existente = EventoDAO.buscar_por_id(db, barraca.evento_id)
    if not evento_existente:
        raise HTTPException(status_code=404, detail="Evento não encontrado.")
    
    return BarracaDAO.criar_barraca(db, barraca)