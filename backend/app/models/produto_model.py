from sqlalchemy import Column, Integer, String, Float, ForeignKey
from sqlalchemy.orm import relationship
from app.database import Base

class Produto(Base):
    __tablename__ = "produtos"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    nome = Column(String(255), nullable=False)
    preco = Column(Float, nullable=False)
    
    barraca_id = Column(
        Integer, 
        ForeignKey("barracas.id", ondelete="CASCADE"), 
        nullable=False
    )

    barraca = relationship("Barraca", back_populates="produtos")