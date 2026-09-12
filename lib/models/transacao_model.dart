class ItemVenda {
  final int produtoId;
  final String? nomeProduto;
  final int quantidade;
  final double precoUnitario;

  ItemVenda({
    required this.produtoId,
    this.nomeProduto,
    required this.quantidade,
    required this.precoUnitario,
  });

  factory ItemVenda.fromJson(Map<String, dynamic> json) {
    return ItemVenda(
      produtoId: json['produto_id'],
      nomeProduto: json['nome_produto'],
      quantidade: json['quantidade'],
      precoUnitario: (json['preco_unitario'] as num).toDouble(),
    );
  }
}

class Transacao {
  final int id;
  final String tipo; // "recarga" ou "venda"
  final double valorTotal;
  final DateTime dataHora;
  final int? barracaId;
  final List<ItemVenda> itens;

  Transacao({
    required this.id,
    required this.tipo,
    required this.valorTotal,
    required this.dataHora,
    this.barracaId,
    this.itens = const [],
  });

  factory Transacao.fromJson(Map<String, dynamic> json) {
    final rawData = json['data_hora'] as String;
    // O backend grava o horário em UTC (datetime.utcnow()). Se a string não
    // vier com indicador de fuso ('Z'), o Dart assume "hora local" por
    // padrão — o que causava o horário aparecer adiantado. Forçamos aqui a
    // interpretação correta como UTC e convertemos para o horário do
    // dispositivo.
    final dataUtc = DateTime.parse(rawData.endsWith('Z') ? rawData : '${rawData}Z');

    return Transacao(
      id: json['id'],
      tipo: json['tipo'],
      valorTotal: (json['valor_total'] as num).toDouble(),
      dataHora: dataUtc.toLocal(),
      barracaId: json['barraca_id'],
      itens: json['itens'] != null
          ? (json['itens'] as List).map((i) => ItemVenda.fromJson(i)).toList()
          : [],
    );
  }
}