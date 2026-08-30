from sqlalchemy.orm import Session
from app import models, schemas

class EventoDAO:
    @staticmethod
    def criar_evento(db: Session, evento: schemas.EventoCreate, organizador_id: int):
        novo_evento = models.Evento(
            nome=evento.nome,
            data_inicio=evento.data_inicio,
            data_fim=evento.data_fim,
            organizador_id=organizador_id
        )
        db.add(novo_evento)
        db.commit()
        db.refresh(novo_evento)
        return novo_evento

    @staticmethod
    def listar_por_organizador(db: Session, organizador_id: int):
        return db.query(models.Evento).filter(models.Evento.organizador_id == organizador_id).all()

    @staticmethod
    def buscar_por_id(db: Session, evento_id: int):
        return db.query(models.Evento).filter(models.Evento.id == evento_id).first()

class BarracaDAO:
    @staticmethod
    def criar_barraca(db: Session, barraca: schemas.BarracaCreate):
        nova_barraca = models.Barraca(
            nome=barraca.nome,
            evento_id=barraca.evento_id,
            responsavel_id=barraca.responsavel_id
        )
        db.add(nova_barraca)
        db.commit()
        db.refresh(nova_barraca)
        return nova_barraca