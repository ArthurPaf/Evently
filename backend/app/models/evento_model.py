from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Table
from sqlalchemy.orm import relationship
from app.database import Base

# Tabela associativa Evento <-> Usuario (administradores)
evento_administradores = Table(
    "evento_administradores",
    Base.metadata,
    Column("evento_id", Integer, ForeignKey("eventos.id", ondelete="CASCADE"), primary_key=True),
    Column("usuario_id", Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), primary_key=True),
)

class Evento(Base):
    __tablename__ = "eventos"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    nome = Column(String(255), nullable=False)
    local = Column(String(255), nullable=True)
    data_inicio = Column(DateTime, nullable=True)
    data_fim = Column(DateTime, nullable=True)
    organizador_id = Column(Integer, ForeignKey("usuarios.id"))

    organizador = relationship("Usuario", back_populates="eventos")
    barracas = relationship(
        "Barraca",
        back_populates="evento",
        cascade="all, delete-orphan"
    )

    # Administradores vinculados a esse evento (many-to-many)
    administradores = relationship(
        "Usuario",
        secondary=evento_administradores,
        back_populates="eventos_administrados",
    )