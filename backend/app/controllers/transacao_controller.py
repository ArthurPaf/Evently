from typing import Optional
from decimal import Decimal
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models import Carteira, Transacao, ItemTransacao, TipoTransacao, Produto, Barraca, Evento


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


def realizar_recarga(db: Session, evento_id: int, dados, realizado_por_id: int) -> Transacao:
    if dados.valor <= 0:
        raise HTTPException(status_code=400, detail="O valor da recarga deve ser maior que zero.")

    evento = db.query(Evento).filter(Evento.id == evento_id).first()
    if evento and evento.encerrado:
        raise HTTPException(status_code=400, detail="Este evento já foi encerrado.")

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


def realizar_recarga_propria(db: Session, cliente_id: int, evento_id: int, valor: float) -> Transacao:
    """
    Recarga feita pelo próprio cliente (pagamento simulado, sem gateway real).
    """
    if valor <= 0:
        raise HTTPException(status_code=400, detail="O valor deve ser maior que zero.")

    evento = db.query(Evento).filter(Evento.id == evento_id).first()
    if evento and evento.encerrado:
        raise HTTPException(status_code=400, detail="Este evento já foi encerrado.")

    carteira, _ = buscar_ou_criar_carteira(db, cliente_id, evento_id)
    carteira.saldo_digital += valor

    transacao = Transacao(
        carteira_id=carteira.id,
        tipo=TipoTransacao.RECARGA,
        valor_total=valor,
        realizado_por_id=cliente_id,
    )
    db.add(transacao)
    db.commit()
    db.refresh(transacao)
    return transacao


def realizar_venda(db: Session, barraca_id: int, dados, vendedor_id: int) -> Transacao:
    barraca = db.query(Barraca).filter(Barraca.id == barraca_id).first()
    if not barraca:
        raise HTTPException(status_code=404, detail="Barraca não encontrada.")

    if barraca.evento and barraca.evento.encerrado:
        raise HTTPException(status_code=400, detail="Este evento já foi encerrado.")

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
                preco_unitario=produto.preco,
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


def estornar_venda(db: Session, transacao_id: int, realizado_por_id: int, dados=None) -> Transacao:
    """Devolve apenas as unidades escolhidas, sem modificar os itens originais."""
    # Serializa estornos da mesma venda e recarrega o estado lido pela autorização.
    venda = (
        db.query(Transacao).filter(Transacao.id == transacao_id)
        .populate_existing().with_for_update().first()
    )
    if not venda:
        raise HTTPException(status_code=404, detail="Transação não encontrada.")
    if venda.tipo != TipoTransacao.VENDA:
        raise HTTPException(status_code=400, detail="Apenas vendas podem ser estornadas.")
    if venda.estornada:
        raise HTTPException(status_code=400, detail="Esta venda já foi estornada.")

    itens_venda = {item.id: item for item in venda.itens}
    restantes = {
        item.id: item.quantidade - item.quantidade_estornada for item in venda.itens
    }
    if dados is None:
        quantidades = {item_id: qtd for item_id, qtd in restantes.items() if qtd > 0}
    else:
        quantidades = {}
        for item in dados.itens:
            if item.item_id not in itens_venda:
                raise HTTPException(status_code=400, detail="Produto não pertence a esta venda.")
            if item.item_id in quantidades:
                raise HTTPException(status_code=400, detail="Item repetido no pedido de estorno.")
            if item.quantidade <= 0 or item.quantidade > restantes[item.item_id]:
                raise HTTPException(status_code=400, detail="Quantidade maior que as unidades disponíveis para estorno.")
            quantidades[item.item_id] = item.quantidade

    if not quantidades and (dados is not None or itens_venda):
        raise HTTPException(status_code=400, detail="Não há unidades para estornar.")

    valor = sum(
        (Decimal(str(itens_venda[item_id].preco_unitario)) * qtd
         for item_id, qtd in quantidades.items()),
        Decimal("0"),
    )
    # Compatibilidade com vendas antigas sem detalhamento de itens.
    if not itens_venda:
        valor = Decimal(str(venda.valor_total)) - Decimal(str(venda.valor_estornado))

    carteira = (
        db.query(Carteira)
        .filter(Carteira.id == venda.carteira_id)
        .populate_existing()
        .with_for_update()
        .first()
    )
    if not carteira:
        raise HTTPException(status_code=404, detail="Carteira não encontrada.")

    carteira.saldo_digital = float(Decimal(str(carteira.saldo_digital)) + valor)
    venda.estornada = all(quantidades.get(item_id, 0) == qtd for item_id, qtd in restantes.items())

    estorno = Transacao(
        carteira_id=venda.carteira_id,
        tipo=TipoTransacao.ESTORNO,
        valor_total=float(valor),
        barraca_id=venda.barraca_id,
        realizado_por_id=realizado_por_id,
        estorno_de=venda,
    )
    for item_id, qtd in quantidades.items():
        original = itens_venda[item_id]
        devolvido = ItemTransacao(
            produto_id=original.produto_id,
            quantidade=qtd,
            preco_unitario=original.preco_unitario,
        )
        estorno.itens.append(devolvido)
        original.estornos.append(devolvido)
    db.add(estorno)
    db.commit()
    db.refresh(estorno)
    return estorno


def realizar_reembolso(
    db: Session,
    evento_id: int,
    codigo_identificador: str,
    valor: Optional[float],
    realizado_por_id: int,
) -> Transacao:
    """
    Devolve (total ou parcialmente) o saldo digital de um cliente.
    Não representa dinheiro real saindo do sistema — é o registro contábil
    de que o organizador devolveu esse valor fisicamente/manualmente ao
    cliente (ex: saldo não utilizado ao final do evento).
    """
    carteira = buscar_carteira_por_codigo(db, evento_id, codigo_identificador)

    valor_reembolso = valor if valor is not None else carteira.saldo_digital

    if valor_reembolso <= 0:
        raise HTTPException(status_code=400, detail="Não há saldo para reembolsar.")
    if valor_reembolso > carteira.saldo_digital:
        raise HTTPException(
            status_code=400, detail="Valor de reembolso maior que o saldo disponível."
        )

    carteira.saldo_digital -= valor_reembolso

    transacao = Transacao(
        carteira_id=carteira.id,
        tipo=TipoTransacao.REEMBOLSO,
        valor_total=valor_reembolso,
        realizado_por_id=realizado_por_id,
    )
    db.add(transacao)
    db.commit()
    db.refresh(transacao)
    return transacao
