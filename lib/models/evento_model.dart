import 'administrador_model.dart';

class Evento {
  final int id;
  final String nome;
  final String local;
  final String dataInicio;
  final String dataFim;
  final List<int> administradorIds; // usado ao ENVIAR (criar/editar)
  final List<Administrador> administradores; // usado ao RECEBER (exibir)

  Evento({
    required this.id,
    required this.nome,
    required this.local,
    required this.dataInicio,
    required this.dataFim,
    this.administradorIds = const [],
    this.administradores = const [],
  });

  factory Evento.fromJson(Map<String, dynamic> json) {
    return Evento(
      id: json['id'] ?? 0,
      nome: json['nome'] ?? '',
      local: json['local'] ?? '',
      dataInicio: json['data_inicio'] ?? json['dataInicio'] ?? '',
      dataFim: json['data_fim'] ?? json['dataFim'] ?? '',
      administradores: json['administradores'] != null
          ? (json['administradores'] as List)
              .map((a) => Administrador.fromJson(a))
              .toList()
          : [],
    );
  }

  // Envia apenas os campos esperados pelo EventoCreate do Pydantic
  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'local': local,
      'data_inicio': dataInicio, // Certifique-se de estar no formato YYYY-MM-DD
      'data_fim': dataFim,       // Certifique-se de estar no formato YYYY-MM-DD
      'administrador_ids': administradorIds,
    };
  }
}