from pydantic import BaseModel
from typing import Optional

class ProdutoBase(BaseModel):
    nome: str
    preco: float

class ProdutoCreate(ProdutoBase):
    barraca_id: int

class ProdutoUpdate(BaseModel):
    nome: Optional[str] = None
    preco: Optional[float] = None

class ProdutoResponse(ProdutoBase):
    id: int
    barraca_id: int

    class Config:
        from_attributes = True  # Pydantic v2 (se usar v1, utilize orm_mode = True)