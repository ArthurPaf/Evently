from datetime import date
from pydantic import BaseModel


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