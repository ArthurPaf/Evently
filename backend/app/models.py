from sqlalchemy import Column, Integer, String, Enum
from app.database import Base
import enum
from sqlalchemy import ForeignKey, DateTime, Date
from sqlalchemy.orm import relationship
from datetime import datetime

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

class Barraca(Base):
    __tablename__ = "barracas"

    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String, nullable=False)
    evento_id = Column(Integer, ForeignKey("eventos.id"))
    responsavel_id = Column(Integer, ForeignKey("usuarios.id")) # Vendedor

    # Relacionamentos
    evento = relationship("Evento", back_populates="barracas")
    responsavel = relationship("User")

class TipoPerfil(str, enum.Enum):
    ORGANIZADOR = "organizador"
    VENDEDOR = "vendedor"
    CLIENTE = "cliente"

class User(Base):
    __tablename__ = "usuarios"

    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    senha_hash = Column(String, nullable=False)
    perfil = Column(Enum(TipoPerfil), default=TipoPerfil.CLIENTE)