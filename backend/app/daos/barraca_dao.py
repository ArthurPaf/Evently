import logging
from sqlalchemy.orm import Session
from app.models import Barraca
from app.schemas.barraca_schema import BarracaCreate

logger = logging.getLogger("evently_backend")

def criar_barraca(db: Session, barraca: BarracaCreate, evento_id: int, responsavel_id: int):
    try:
        logger.info(f"Tentando salvar barraca '{barraca.nome}' para o evento ID {evento_id}")
        db_barraca = Barraca(
            nome=barraca.nome,
            tipo=barraca.tipo,
            evento_id=evento_id,
            responsavel_id=responsavel_id
        )
        db.add(db_barraca)
        db.commit()
        db.refresh(db_barraca)
        logger.info(f"Barraca '{barraca.nome}' salva no banco com ID {db_barraca.id}!")
        return db_barraca
    except Exception as e:
        db.rollback()
        logger.error(f"ERRO CRÍTICO ao salvar barraca no banco: {str(e)}", exc_info=True)
        raise e

def listar_barracas_por_evento(db: Session, evento_id: int):
    logger.info(f"Buscando barracas do evento ID {evento_id}")
    return db.query(Barraca).filter(Barraca.evento_id == evento_id).all()