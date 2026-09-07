class Carteira {
  final int id;
  final int eventoId;
  final double saldoDigital;
  final String codigoIdentificador;

  Carteira({
    required this.id,
    required this.eventoId,
    required this.saldoDigital,
    required this.codigoIdentificador,
  });

  factory Carteira.fromJson(Map<String, dynamic> json) {
    return Carteira(
      id: json['id'],
      eventoId: json['evento_id'],
      saldoDigital: (json['saldo_digital'] as num).toDouble(),
      codigoIdentificador: json['codigo_identificador'],
    );
  }
}