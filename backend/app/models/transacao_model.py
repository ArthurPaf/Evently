import enum
import uuid
from datetime import datetime
from sqlalchemy import (
    Column, Integer, Float, String, DateTime, ForeignKey, Enum, UniqueConstraint
)
from sqlalchemy.orm import relationship
from app.database import Base


class TipoTransacao(str, enum.Enum):
    RECARGA = "recarga"
    VENDA = "venda"


def gerar_codigo_identificador() -> str:
    # Código curto, usado tanto no conteúdo do QR Code quanto na digitação manual
    return uuid.uuid4().hex[:8].upper()


class Carteira(Base):
    """
    Carteira digital de um cliente DENTRO de um evento específico.
    O saldo é "closed-loop": só existe e só pode ser gasto dentro do
    evento em que foi carregado.
    """
    __tablename__ = "carteiras"
    __table_args__ = (
        UniqueConstraint("cliente_id", "evento_id", name="uq_cliente_evento"),
    )

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    cliente_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    evento_id = Column(Integer, ForeignKey("eventos.id", ondelete="CASCADE"), nullable=False)
    saldo_digital = Column(Float, nullable=False, default=0.0)
    codigo_identificador = Column(
        String(16), unique=True, nullable=False, default=gerar_codigo_identificador
    )

    cliente = relationship("Usuario")
    evento = relationship("Evento")
    transacoes = relationship(
        "Transacao", back_populates="carteira", cascade="all, delete-orphan"
    )


class Transacao(Base):
    __tablename__ = "transacoes"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    carteira_id = Column(Integer, ForeignKey("carteiras.id", ondelete="CASCADE"), nullable=False)
    tipo = Column(Enum(TipoTransacao), nullable=False)
    valor_total = Column(Float, nullable=False)
    barraca_id = Column(Integer, ForeignKey("barracas.id"), nullable=True)  # só em vendas
    realizado_por_id = Column(Integer, ForeignKey("usuarios.id"), nullable=True)  # vendedor/organizador/admin
    data_hora = Column(DateTime, nullable=False, default=datetime.utcnow)

    carteira = relationship("Carteira", back_populates="transacoes")
    barraca = relationship("Barraca")
    itens = relationship(
        "ItemTransacao", back_populates="transacao", cascade="all, delete-orphan"
    )


class ItemTransacao(Base):
    __tablename__ = "itens_transacao"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    transacao_id = Column(Integer, ForeignKey("transacoes.id", ondelete="CASCADE"), nullable=False)
    produto_id = Column(Integer, ForeignKey("produtos.id"), nullable=False)
    quantidade = Column(Integer, nullable=False)
    preco_unitario = Column(Float, nullable=False)  # snapshot do preço no momento da venda

    transacao = relationship("Transacao", back_populates="itens")
    produto = relationship("Produto")

    @property
    def nome_produto(self):
        return self.produto.nome if self.produto else None