from typing import List, Optional
from pydantic import BaseModel
from app.schemas.usuario_schema import VendedorResponse

class BarracaBase(BaseModel):
    nome: str
    tipo: str

class BarracaCreate(BarracaBase):
    vendedor_ids: List[int] = []  # IDs dos usuários vendedores selecionados

class BarracaUpdate(BaseModel):
    nome: Optional[str] = None
    tipo: Optional[str] = None
    vendedor_ids: Optional[List[int]] = None  # None = não mexe; [] = remove todos

class BarracaResponse(BaseModel):
    id: int
    nome: str
    tipo: str
    evento_id: int
    responsavel_id: Optional[int] = None
    vendedores: List[VendedorResponse] = []

    class Config:
        from_attributes = True