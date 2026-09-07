class Vendedor {
  final int id;
  final String nome;
  final String email;

  Vendedor({
    required this.id,
    required this.nome,
    required this.email,
  });

  factory Vendedor.fromJson(Map<String, dynamic> json) {
    return Vendedor(
      id: json['id'],
      nome: json['nome'],
      email: json['email'],
    );
  }
}