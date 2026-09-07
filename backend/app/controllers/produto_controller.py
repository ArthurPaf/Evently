from sqlalchemy.orm import Session
from app.models.produto_model import Produto
from app.schemas.produto_schema import ProdutoCreate, ProdutoUpdate

class ProdutoController:
    @staticmethod
    def listar_produtos_por_barraca(db: Session, barraca_id: int):
        return db.query(Produto).filter(Produto.barraca_id == barraca_id).all()

    @staticmethod
    def criar_produto(db: Session, barraca_id: int, produto_data: ProdutoCreate):
        novo_produto = Produto(
            nome=produto_data.nome,
            preco=produto_data.preco,
            barraca_id=barraca_id,
        )
        db.add(novo_produto)
        db.commit()
        db.refresh(novo_produto)
        return novo_produto

    @staticmethod
    def atualizar_produto(db: Session, produto_id: int, produto_data: ProdutoUpdate):
        produto = db.query(Produto).filter(Produto.id == produto_id).first()
        if not produto:
            return None

        dados_atualizar = produto_data.model_dump(exclude_unset=True)
        for chave, valor in dados_atualizar.items():
            setattr(produto, chave, valor)

        db.commit()
        db.refresh(produto)
        return produto

    @staticmethod
    def deletar_produto(db: Session, produto_id: int) -> bool:
        produto = db.query(Produto).filter(Produto.id == produto_id).first()
        if not produto:
            return False
        db.delete(produto)
        db.commit()
        return True