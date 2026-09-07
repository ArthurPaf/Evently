class Administrador {
  final int id;
  final String nome;
  final String email;

  Administrador({
    required this.id,
    required this.nome,
    required this.email,
  });

  factory Administrador.fromJson(Map<String, dynamic> json) {
    return Administrador(
      id: json['id'],
      nome: json['nome'],
      email: json['email'],
    );
  }
}