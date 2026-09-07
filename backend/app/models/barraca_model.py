from sqlalchemy import Column, Integer, String, ForeignKey, Table
from sqlalchemy.orm import relationship
from app.database import Base

# Tabela associativa Barraca <-> Usuario (vendedores)
barraca_vendedores = Table(
    "barraca_vendedores",
    Base.metadata,
    Column("barraca_id", Integer, ForeignKey("barracas.id", ondelete="CASCADE"), primary_key=True),
    Column("usuario_id", Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), primary_key=True),
)

class Barraca(Base):
    __tablename__ = "barracas"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    nome = Column(String(255), nullable=False)
    tipo = Column(String(255), nullable=False)
    evento_id = Column(
        Integer, 
        ForeignKey("eventos.id", ondelete="CASCADE"), 
        nullable=False
    )
    responsavel_id = Column(Integer, ForeignKey("usuarios.id"), nullable=True)
    evento = relationship("Evento", back_populates="barracas")
    
    produtos = relationship(
        "Produto", 
        back_populates="barraca", 
        cascade="all, delete-orphan"
    )

    # Vendedores que trabalham nessa barraca (many-to-many)
    vendedores = relationship(
        "Usuario",
        secondary=barraca_vendedores,
        back_populates="barracas_vendidas",
    )