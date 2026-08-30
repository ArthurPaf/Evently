from pydantic import BaseModel, EmailStr
from app.models import TipoPerfil
from datetime import date
from pydantic import BaseModel
from typing import Optional


# --- SCHEMAS DE USUÁRIO ---
class UserCreate(BaseModel):
    nome: str
    email: EmailStr
    senha: str
    perfil: TipoPerfil = TipoPerfil.CLIENTE

# Dados retornados (sem a senha, por segurança!)
class UserResponse(BaseModel):
    id: int
    nome: str
    email: EmailStr
    perfil: TipoPerfil

    class Config:
        from_attributes = True

# Esquema do Token
class Token(BaseModel):
    access_token: str
    token_type: str