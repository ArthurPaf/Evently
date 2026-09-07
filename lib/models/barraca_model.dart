import 'vendedor_model.dart';

class Barraca {
  final int? id;
  final String nome;
  final String tipo;
  final int? eventoId;
  final int? responsavelId;
  final List<int> vendedorIds; // usado ao ENVIAR (criar/editar)
  final List<Vendedor> vendedores; // usado ao RECEBER (exibir)

  Barraca({
    this.id,
    required this.nome,
    required this.tipo,
    this.eventoId,
    this.responsavelId,
    this.vendedorIds = const [],
    this.vendedores = const [],
  });

  // Converte o JSON do FastAPI (Python) para o Objeto Dart
  factory Barraca.fromJson(Map<String, dynamic> json) {
    return Barraca(
      id: json['id'],
      nome: json['nome'] ?? '',
      tipo: json['tipo'] ?? '',
      eventoId: json['evento_id'],
      responsavelId: json['responsavel_id'],
      vendedores: json['vendedores'] != null
          ? (json['vendedores'] as List)
              .map((v) => Vendedor.fromJson(v))
              .toList()
          : [],
    );
  }

  // Converte o Objeto Dart para JSON (Envia no POST/PUT)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nome': nome,
      'tipo': tipo,
      'evento_id': eventoId,
      'responsavel_id': responsavelId,
      'vendedor_ids': vendedorIds,
    };
  }

  // Facilita criar uma cópia com os vendedores atualizados
  Barraca copyWith({List<int>? vendedorIds}) {
    return Barraca(
      id: id,
      nome: nome,
      tipo: tipo,
      eventoId: eventoId,
      responsavelId: responsavelId,
      vendedorIds: vendedorIds ?? this.vendedorIds,
      vendedores: vendedores,
    );
  }
}