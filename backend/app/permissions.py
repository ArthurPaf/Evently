from typing import Optional
from sqlalchemy.orm import Session
from app.models import Evento, Barraca, Produto, Usuario, TipoPerfil


def usuario_gerencia_evento(db: Session, evento: Evento, usuario: dict) -> bool:
    """
    Retorna True se o usuário logado pode criar/editar/excluir
    barracas e produtos, e editar os dados deste evento.

    Regras:
    - Organizador: só se for o dono do evento (organizador_id == usuario id)
    - Administrador: só se estiver vinculado a esse evento (many-to-many)
    - Qualquer outro perfil (vendedor, cliente): nunca
    """
    if usuario["perfil"] == TipoPerfil.ORGANIZADOR.value:
        return evento.organizador_id == usuario["id"]

    if usuario["perfil"] == TipoPerfil.ADMINISTRADOR.value:
        admin = db.query(Usuario).filter(Usuario.id == usuario["id"]).first()
        if not admin:
            return False
        return any(e.id == evento.id for e in admin.eventos_administrados)

    return False


def buscar_evento_por_barraca(db: Session, barraca_id: int) -> Optional[Evento]:
    barraca = db.query(Barraca).filter(Barraca.id == barraca_id).first()
    if not barraca:
        return None
    return barraca.evento


def buscar_evento_por_produto(db: Session, produto_id: int) -> Optional[Evento]:
    produto = db.query(Produto).filter(Produto.id == produto_id).first()
    if not produto or not produto.barraca:
        return None
    return produto.barraca.evento