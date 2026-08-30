from sqlalchemy import Column, Date, ForeignKey, Integer, String
from sqlalchemy.orm import relationship
from app.database import Base  # <-- CORRIGIDO AQUI


class Evento(Base):
    __tablename__ = "eventos"

    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String, nullable=False)
    data_inicio = Column(Date, nullable=False)
    data_fim = Column(Date, nullable=False)
    organizador_id = Column(Integer, ForeignKey("usuarios.id"))

    # Relacionamentos
    organizador = relationship("User")
    barracas = relationship("Barraca", back_populates="evento")