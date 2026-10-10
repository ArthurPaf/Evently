class ItemVenda {
  final int id;
  final int produtoId;
  final String? nomeProduto;
  final int quantidade;
  final double precoUnitario;
  final int quantidadeEstornada;

  int get quantidadeDisponivel => quantidade - quantidadeEstornada;

  ItemVenda({
    this.id = 0,
    required this.produtoId,
    this.nomeProduto,
    required this.quantidade,
    required this.precoUnitario,
    this.quantidadeEstornada = 0,
  });

  factory ItemVenda.fromJson(Map<String, dynamic> json) {
    return ItemVenda(
      id: json['id'] ?? 0,
      produtoId: json['produto_id'],
      nomeProduto: json['nome_produto'],
      quantidade: json['quantidade'],
      precoUnitario: (json['preco_unitario'] as num).toDouble(),
      quantidadeEstornada: json['quantidade_estornada'] ?? 0,
    );
  }
}

class Transacao {
  final int id;
  final String tipo; // "recarga", "venda", "estorno" ou "reembolso"
  final double valorTotal;
  final DateTime dataHora;
  final int? barracaId;
  final bool estornada;
  final double valorEstornado;
  final String? nomeCliente;
  final List<ItemVenda> itens;

  Transacao({
    required this.id,
    required this.tipo,
    required this.valorTotal,
    required this.dataHora,
    this.barracaId,
    this.estornada = false,
    this.valorEstornado = 0,
    this.nomeCliente,
    this.itens = const [],
  });

  factory Transacao.fromJson(Map<String, dynamic> json) {
    final rawData = json['data_hora'] as String;
    // O backend grava o horário em UTC (datetime.utcnow()). Forçamos aqui a
    // interpretação correta como UTC e convertemos para o horário local.
    final dataUtc = DateTime.parse(
      rawData.endsWith('Z') ? rawData : '${rawData}Z',
    );

    return Transacao(
      id: json['id'],
      tipo: json['tipo'],
      valorTotal: (json['valor_total'] as num).toDouble(),
      dataHora: dataUtc.toLocal(),
      barracaId: json['barraca_id'],
      estornada: json['estornada'] ?? false,
      valorEstornado: (json['valor_estornado'] as num? ?? 0).toDouble(),
      nomeCliente: json['nome_cliente'] as String?,
      itens: json['itens'] != null
          ? (json['itens'] as List).map((i) => ItemVenda.fromJson(i)).toList()
          : [],
    );
  }
}
