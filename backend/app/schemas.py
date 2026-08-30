from pydantic import BaseModel, EmailStr
from app.models import TipoPerfil
from datetime import date
from typing import List, Optional

# --- SCHEMAS DE EVENTO ---
class EventoCreate(BaseModel):
    nome: str
    data_inicio: date
    data_fim: date

class EventoResponse(BaseModel):
    id: int
    nome: str
    data_inicio: date
    data_fim: date
    organizador_id: int

    class Config:
        from_attributes = True

# --- SCHEMAS DE BARRACA ---
class BarracaCreate(BaseModel):
    nome: str
    evento_id: int
    responsavel_id: int

class BarracaResponse(BaseModel):
    id: int
    nome: str
    evento_id: int
    responsavel_id: int

    class Config:
        from_attributes = True


# --- SCHEMAS DE USUÁRIO ---
# Dados exigidos para cadastrar um usuário
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