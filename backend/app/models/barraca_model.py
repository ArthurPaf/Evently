import enum
from sqlalchemy import Column, Integer, ForeignKey, String
from sqlalchemy.orm import relationship
from app.database import Base


class Barraca(Base):
    __tablename__ = "barracas"

    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String, nullable=False)
    tipo = Column(String, nullable=False)
    
    # Chaves Estrangeiras
    evento_id = Column(Integer, ForeignKey("eventos.id"))
    responsavel_id = Column(Integer, ForeignKey("usuarios.id"))

    # Relacionamentos
    # Garanta que no model Evento exista: barracas = relationship("Barraca", back_populates="evento")
    evento = relationship("Evento", back_populates="barracas")
    
    # Garanta que o nome da string bate exatamente com a classe em user.py (ex: "User")
    responsavel = relationship("User")