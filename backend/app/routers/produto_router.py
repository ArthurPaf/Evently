from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.controllers.produto_controller import ProdutoController
from app.database import get_db
from app.schemas.produto_schema import (
    ProdutoCreate,
    ProdutoResponse,
    ProdutoUpdate,
)
from app.security import get_usuario_atual
from app.permissions import (
    usuario_gerencia_evento,
    buscar_evento_por_barraca,
    buscar_evento_por_produto,
)

router = APIRouter(prefix="/barracas/{barraca_id}/produtos", tags=["Produtos"])
produto_direct_router = APIRouter(prefix="/produtos", tags=["Produtos"])


@router.post("/", response_model=ProdutoResponse, status_code=status.HTTP_201_CREATED)
def criar_produto(
    barraca_id: int,
    produto: ProdutoCreate,
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual),
):
    evento = buscar_evento_por_barraca(db, barraca_id)
    if not evento:
        raise HTTPException(status_code=404, detail="Barraca não encontrada.")
    if not usuario_gerencia_evento(db, evento, usuario):
        raise HTTPException(status_code=403, detail="Sem permissão para criar produtos nesta barraca.")

    return ProdutoController.criar_produto(db, barraca_id, produto)


@router.get("/", response_model=List[ProdutoResponse])
def listar_produtos(
    barraca_id: int,
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual),  # qualquer logado (organizador, admin ou vendedor da barraca)
):
    return ProdutoController.listar_produtos_por_barraca(db, barraca_id)


# --- ROTAS DIRETAS DE EDIÇÃO E EXCLUSÃO DE PRODUTO ---

@produto_direct_router.put("/{produto_id}/", response_model=ProdutoResponse)
def atualizar_produto(
    produto_id: int,
    produto_data: ProdutoUpdate,
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual),
):
    evento = buscar_evento_por_produto(db, produto_id)
    if not evento:
        raise HTTPException(status_code=404, detail="Produto não encontrado.")
    if not usuario_gerencia_evento(db, evento, usuario):
        raise HTTPException(status_code=403, detail="Sem permissão para editar este produto.")

    produto_atualizado = ProdutoController.atualizar_produto(db, produto_id, produto_data)
    if not produto_atualizado:
        raise HTTPException(status_code=404, detail="Produto não encontrado.")
    return produto_atualizado


@produto_direct_router.delete("/{produto_id}/", status_code=status.HTTP_200_OK)
def deletar_produto(
    produto_id: int,
    db: Session = Depends(get_db),
    usuario: dict = Depends(get_usuario_atual),
):
    evento = buscar_evento_por_produto(db, produto_id)
    if not evento:
        raise HTTPException(status_code=404, detail="Produto não encontrado.")
    if not usuario_gerencia_evento(db, evento, usuario):
        raise HTTPException(status_code=403, detail="Sem permissão para excluir este produto.")

    sucesso = ProdutoController.deletar_produto(db, produto_id)
    if not sucesso:
        raise HTTPException(status_code=404, detail="Produto não encontrado.")
    return {"mensagem": "Produto excluído com sucesso."}