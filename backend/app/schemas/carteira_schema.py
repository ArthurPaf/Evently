from typing import List, Optional
from pydantic import BaseModel, Field
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


class RecargaPropriaCreate(BaseModel):
    valor: float


class ReembolsoCreate(BaseModel):
    codigo_identificador: str
    valor: Optional[float] = None  # None = reembolsa todo o saldo restante


class ReembolsoProprioCreate(BaseModel):
    valor: Optional[float] = Field(default=None, gt=0, allow_inf_nan=False)


class ItemVendaInput(BaseModel):
    produto_id: int
    quantidade: int


class VendaCreate(BaseModel):
    codigo_identificador: str
    itens: List[ItemVendaInput]


class ItemEstornoInput(BaseModel):
    item_id: int = Field(gt=0, strict=True)
    quantidade: int = Field(gt=0, strict=True)


class EstornoCreate(BaseModel):
    # Sem corpo continua significando estorno total, para compatibilidade.
    itens: List[ItemEstornoInput] = Field(min_length=1)


class ItemVendaResponse(BaseModel):
    id: int
    produto_id: int
    nome_produto: Optional[str] = None
    quantidade: int
    preco_unitario: float
    quantidade_estornada: int = 0

    class Config:
        from_attributes = True


class TransacaoResponse(BaseModel):
    id: int
    tipo: str
    valor_total: float
    data_hora: datetime
    barraca_id: Optional[int] = None
    estornada: bool = False
    valor_estornado: float = 0.0
    estorno_de_id: Optional[int] = None
    nome_cliente: Optional[str] = None
    itens: List[ItemVendaResponse] = []

    class Config:
        from_attributes = True
