from typing import Optional
from pydantic import BaseModel

class BarracaBase(BaseModel):
    nome: str
    tipo: str

class BarracaCreate(BarracaBase):
    pass  # O Flutter envia apenas nome e tipo. evento_id e responsavel_id sao injetados pelo backend.

class BarracaResponse(BaseModel):
    id: int
    nome: str
    tipo: str
    evento_id: int
    # Permite que o campo venha nulo do banco de dados sem quebrar a API
    responsavel_id: Optional[int] = None

    class Config:
        from_attributes = True