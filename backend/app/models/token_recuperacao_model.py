import uuid
from datetime import datetime, timedelta
from sqlalchemy import Column, Integer, String, DateTime, Boolean, ForeignKey
from app.database import Base


def gerar_token() -> str:
    return uuid.uuid4().hex


def gerar_expiracao() -> datetime:
    return datetime.utcnow() + timedelta(minutes=30)


class TokenRecuperacaoSenha(Base):
    __tablename__ = "tokens_recuperacao_senha"

    id = Column(Integer, primary_key=True, autoincrement=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    token = Column(String(64), unique=True, nullable=False, default=gerar_token)
    expira_em = Column(DateTime, nullable=False, default=gerar_expiracao)
    usado = Column(Boolean, nullable=False, default=False)
    criado_em = Column(DateTime, nullable=False, default=datetime.utcnow)