import enum
from sqlalchemy import Column, Enum, Integer, String
from app.database import Base


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