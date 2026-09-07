from sqlalchemy.orm import Session
from fastapi import HTTPException
from app.schemas import usuario_schema
from app.daos.evento_dao import EventoDAO
from app.daos.barraca_dao import BarracaDAO

def criar_evento(db: Session, evento: usuario_schema.EventoCreate, organizador_id: int):
    # Regra de negócio: A data de fim não pode ser menor que a data de início
    if evento.data_fim < evento.data_inicio:
        raise HTTPException(status_code=400, detail="Data de término não pode ser anterior à data de início.")
    
    return EventoDAO.criar_evento(db, evento, organizador_id)

def listar_eventos_do_organizador(db: Session, organizador_id: int):
    return EventoDAO.listar_por_organizador(db, organizador_id)

def editar_evento(db: Session, evento_id: int, evento: usuario_schema.EventoCreate, organizador_id: int):
    evento_existente = EventoDAO.buscar_por_id(db, evento_id)
    if not evento_existente:
        raise HTTPException(status_code=404, detail="Evento não encontrado.")
    
    if evento_existente.organizador_id != organizador_id:
        raise HTTPException(status_code=403, detail="Sem permissão para alterar este evento.")

    if evento.data_fim < evento.data_inicio:
        raise HTTPException(status_code=400, detail="Data de término não pode ser anterior à data de início.")

    return EventoDAO.editar_evento(db, evento_id, evento)

def excluir_evento(db: Session, evento_id: int, organizador_id: int):
    evento_existente = EventoDAO.buscar_por_id(db, evento_id)
    if not evento_existente:
        raise HTTPException(status_code=404, detail="Evento não encontrado.")

    if evento_existente.organizador_id != organizador_id:
        raise HTTPException(status_code=403, detail="Sem permissão para excluir este evento.")

    return EventoDAO.excluir_evento(db, evento_id)

def criar_barraca(db: Session, barraca: usuario_schema.BarracaCreate):
    # Regra de negócio: Validar se o evento ao qual a barraca será vinculada realmente existe
    evento_existente = EventoDAO.buscar_por_id(db, barraca.evento_id)
    if not evento_existente:
        raise HTTPException(status_code=404, detail="Evento não encontrado.")
    
    return BarracaDAO.criar_barraca(db, barraca)