class Produto {
  final int? id;
  final String nome;
  final double preco;
  final int? barracaId;

  Produto({
    this.id,
    required this.nome,
    required this.preco,
    this.barracaId,
  });

  factory Produto.fromJson(Map<String, dynamic> json) {
    return Produto(
      id: json['id'] as int?,
      nome: json['nome'] as String? ?? '',
      preco: (json['preco'] as num?)?.toDouble() ?? 0.0,
      barracaId: json['barraca_id'] as int? ?? json['barracaId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nome': nome,
      'preco': preco,
      if (barracaId != null) 'barraca_id': barracaId,
    };
  }
}