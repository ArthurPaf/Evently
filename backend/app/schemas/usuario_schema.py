from pydantic import BaseModel, EmailStr
from app.models import TipoPerfil
from pydantic import BaseModel
from typing import Optional
from pydantic import BaseModel
from datetime import datetime
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

class EventoCreate(BaseModel):
    nome: str
    local: Optional[str] = None
    data_inicio: datetime
    data_fim: datetime

    class Config:
        from_attributes = True

class EventoSchema(BaseModel):
    id: int
    nome: str
    local: Optional[str] = None
    data_inicio: Union[date, datetime, str]
    data_fim: Union[date, datetime, str]
    organizador_id: int

    class Config:
        from_attributes = True

class VendedorResponse(BaseModel):
    id: int
    nome: str
    email: str

    class Config:
        from_attributes = True

class AdministradorResponse(BaseModel):
    id: int
    nome: str
    email: str
 
    class Config:
        from_attributes = True