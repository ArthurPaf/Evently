from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime


class CarteiraResponse(BaseModel):
    id: int
    evento_id: int
    saldo_digital: float
    codigo_identificador: str

    class Config:
        from_attributes = True


class RecargaCreate(BaseModel):
    codigo_identificador: str
    valor: float


class ItemVendaInput(BaseModel):
    produto_id: int
    quantidade: int


class VendaCreate(BaseModel):
    codigo_identificador: str
    itens: List[ItemVendaInput]


class ItemVendaResponse(BaseModel):
    produto_id: int
    nome_produto: Optional[str] = None
    quantidade: int
    preco_unitario: float

    class Config:
        from_attributes = True


class TransacaoResponse(BaseModel):
    id: int
    tipo: str
    valor_total: float
    data_hora: datetime
    barraca_id: Optional[int] = None
    itens: List[ItemVendaResponse] = []

    class Config:
        from_attributes = True