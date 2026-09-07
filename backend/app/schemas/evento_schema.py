from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from app.schemas.usuario_schema import AdministradorResponse

class EventoBase(BaseModel):
    nome: str
    local: Optional[str] = None
    data_inicio: Optional[datetime] = None
    data_fim: Optional[datetime] = None

class EventoCreate(EventoBase):
    administrador_ids: List[int] = []  # IDs dos administradores vinculados a este evento

class EventoResponse(EventoBase):
    id: int
    organizador_id: int
    administradores: List[AdministradorResponse] = []

    class Config:
        from_attributes = True  # Pydantic v2 (no v1 use `orm_mode = True`)