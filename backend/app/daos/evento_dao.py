from sqlalchemy.orm import Session
from app import models
from app.models import Usuario


class EventoDAO:
    @staticmethod
    def criar_evento(db: Session, evento, organizador_id: int):
        novo_evento = models.Evento(
            nome=evento.nome,
            data_inicio=evento.data_inicio,
            data_fim=evento.data_fim,
            local=evento.local,
            organizador_id=organizador_id
        )

        administrador_ids = getattr(evento, "administrador_ids", None)
        if administrador_ids:
            administradores = (
                db.query(Usuario).filter(Usuario.id.in_(administrador_ids)).all()
            )
            novo_evento.administradores = administradores

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

    @staticmethod
    def editar_evento(db: Session, evento_id: int, evento_data):
        evento = db.query(models.Evento).filter(models.Evento.id == evento_id).first()
        if evento:
            evento.nome = evento_data.nome
            evento.local = evento_data.local
            evento.data_inicio = evento_data.data_inicio
            evento.data_fim = evento_data.data_fim

            administrador_ids = getattr(evento_data, "administrador_ids", None)
            if administrador_ids is not None:
                administradores = (
                    db.query(Usuario).filter(Usuario.id.in_(administrador_ids)).all()
                )
                evento.administradores = administradores

            db.commit()
            db.refresh(evento)
        return evento