class Evento {
  final int id;
  final String nome;
  final String dataInicio;
  final String dataFim;

  Evento({required this.id, required this.nome, required this.dataInicio, required this.dataFim});

  factory Evento.fromJson(Map<String, dynamic> json) {
    return Evento(
      id: json['id'],
      nome: json['nome'],
      dataInicio: json['data_inicio'],
      dataFim: json['data_fim'],
    );
  }
}