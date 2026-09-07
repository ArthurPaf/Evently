import enum
from sqlalchemy import Column, Enum, Integer, String
from app.database import Base
from sqlalchemy.orm import relationship


class TipoPerfil(str, enum.Enum):
    ORGANIZADOR = "organizador"
    ADMINISTRADOR = "administrador"
    VENDEDOR = "vendedor"
    CLIENTE = "cliente"

class Usuario(Base):
    __tablename__ = "usuarios"

    id = Column(Integer, primary_key=True)
    eventos = relationship("Evento", back_populates="organizador")
    nome = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    senha_hash = Column(String, nullable=False)
    perfil = Column(Enum(TipoPerfil), default=TipoPerfil.CLIENTE)

    # Barracas em que esse usuário atua como vendedor (many-to-many)
    barracas_vendidas = relationship(
        "Barraca",
        secondary="barraca_vendedores",
        back_populates="vendedores",
    )

    # Eventos em que esse usuário atua como administrador (many-to-many)
    eventos_administrados = relationship(
        "Evento",
        secondary="evento_administradores",
        back_populates="administradores",
    )