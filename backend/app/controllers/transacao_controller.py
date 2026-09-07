from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models import Carteira, Transacao, ItemTransacao, TipoTransacao, Produto, Barraca
from app.schemas.carteira_schema import RecargaCreate, VendaCreate


def buscar_ou_criar_carteira(db: Session, cliente_id: int, evento_id: int):
    carteira = (
        db.query(Carteira)
        .filter(Carteira.cliente_id == cliente_id, Carteira.evento_id == evento_id)
        .first()
    )
    if carteira:
        return carteira, False

    carteira = Carteira(cliente_id=cliente_id, evento_id=evento_id)
    db.add(carteira)
    db.commit()
    db.refresh(carteira)
    return carteira, True


def buscar_carteira_por_codigo(db: Session, evento_id: int, codigo: str) -> Carteira:
    carteira = (
        db.query(Carteira)
        .filter(
            Carteira.evento_id == evento_id,
            Carteira.codigo_identificador == codigo.upper(),
        )
        .with_for_update()  # trava a linha: evita duas vendas simultâneas debitarem o mesmo saldo
        .first()
    )
    if not carteira:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Cartão/código não encontrado para este evento.",
        )
    return carteira


def realizar_recarga(
    db: Session, evento_id: int, dados: RecargaCreate, realizado_por_id: int
) -> Transacao:
    if dados.valor <= 0:
        raise HTTPException(status_code=400, detail="O valor da recarga deve ser maior que zero.")

    carteira = buscar_carteira_por_codigo(db, evento_id, dados.codigo_identificador)
    carteira.saldo_digital += dados.valor

    transacao = Transacao(
        carteira_id=carteira.id,
        tipo=TipoTransacao.RECARGA,
        valor_total=dados.valor,
        realizado_por_id=realizado_por_id,
    )
    db.add(transacao)
    db.commit()
    db.refresh(transacao)
    return transacao


def realizar_venda(
    db: Session, barraca_id: int, dados: VendaCreate, vendedor_id: int
) -> Transacao:
    barraca = db.query(Barraca).filter(Barraca.id == barraca_id).first()
    if not barraca:
        raise HTTPException(status_code=404, detail="Barraca não encontrada.")

    if not dados.itens:
        raise HTTPException(status_code=400, detail="A venda precisa ter ao menos um item.")

    carteira = buscar_carteira_por_codigo(db, barraca.evento_id, dados.codigo_identificador)

    valor_total = 0.0
    itens_para_criar = []
    for item in dados.itens:
        produto = (
            db.query(Produto)
            .filter(Produto.id == item.produto_id, Produto.barraca_id == barraca_id)
            .first()
        )
        if not produto:
            raise HTTPException(
                status_code=404,
                detail=f"Produto {item.produto_id} não encontrado nesta barraca.",
            )
        if item.quantidade <= 0:
            raise HTTPException(status_code=400, detail="Quantidade deve ser maior que zero.")

        subtotal = produto.preco * item.quantidade
        valor_total += subtotal
        itens_para_criar.append(
            ItemTransacao(
                produto_id=produto.id,
                quantidade=item.quantidade,
                preco_unitario=produto.preco,  # snapshot: preserva o preço mesmo se mudar depois
            )
        )

    if carteira.saldo_digital < valor_total:
        raise HTTPException(status_code=400, detail="Saldo insuficiente.")

    carteira.saldo_digital -= valor_total

    transacao = Transacao(
        carteira_id=carteira.id,
        tipo=TipoTransacao.VENDA,
        valor_total=valor_total,
        barraca_id=barraca_id,
        realizado_por_id=vendedor_id,
        itens=itens_para_criar,
    )
    db.add(transacao)
    db.commit()
    db.refresh(transacao)
    return transacao