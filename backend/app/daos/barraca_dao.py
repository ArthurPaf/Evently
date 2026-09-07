import logging
from typing import Optional
from sqlalchemy.orm import Session
from app.models import Barraca, Usuario
from app.schemas.barraca_schema import BarracaCreate, BarracaUpdate

logger = logging.getLogger("evently_backend")


class BarracaDAO:

    @staticmethod
    def criar_barraca(
        db: Session,
        barraca: BarracaCreate,
        evento_id: int,
        responsavel_id: int,
    ):
        try:
            logger.info(
                f"Tentando salvar barraca '{barraca.nome}' para o evento ID {evento_id}"
            )
            db_barraca = Barraca(
                nome=barraca.nome,
                tipo=barraca.tipo,
                evento_id=evento_id,
                responsavel_id=responsavel_id,
            )

            if barraca.vendedor_ids:
                vendedores = (
                    db.query(Usuario)
                    .filter(Usuario.id.in_(barraca.vendedor_ids))
                    .all()
                )
                db_barraca.vendedores = vendedores

            db.add(db_barraca)
            db.commit()
            db.refresh(db_barraca)
            logger.info(
                f"Barraca '{barraca.nome}' salva no banco com ID {db_barraca.id}!"
            )
            return db_barraca
        except Exception as e:
            db.rollback()
            logger.error(
                f"ERRO CRÍTICO ao salvar barraca no banco: {str(e)}",
                exc_info=True,
            )
            raise e

    @staticmethod
    def listar_barracas_por_evento(db: Session, evento_id: int):
        logger.info(f"Buscando barracas do evento ID {evento_id}")
        return db.query(Barraca).filter(Barraca.evento_id == evento_id).all()

    @staticmethod
    def atualizar_barraca(db: Session, barraca_id: int, barraca_data: BarracaUpdate):
        barraca = db.query(Barraca).filter(Barraca.id == barraca_id).first()
        if not barraca:
            return None

        if hasattr(barraca_data, "model_dump"):
            dados = barraca_data.model_dump(exclude_unset=True)
        else:
            dados = barraca_data.dict(exclude_unset=True)

        chaves_protegidas = {"id", "evento_id", "responsavel_id", "vendedor_ids"}

        for chave, valor in dados.items():
            if chave not in chaves_protegidas and valor is not None:
                setattr(barraca, chave, valor)

        if "vendedor_ids" in dados and dados["vendedor_ids"] is not None:
            vendedores = (
                db.query(Usuario)
                .filter(Usuario.id.in_(dados["vendedor_ids"]))
                .all()
            )
            barraca.vendedores = vendedores

        db.commit()
        db.refresh(barraca)
        return barraca

    @staticmethod
    def deletar_barraca(db: Session, barraca_id: int) -> bool:
        barraca = db.query(Barraca).filter(Barraca.id == barraca_id).first()
        if not barraca:
            return False
        db.delete(barraca)
        db.commit()
        return True