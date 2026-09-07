import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/vendedor_model.dart';

const String _baseUrl = 'http://127.0.0.1:8000';

class VendedorService {
  final http.Client _client;
  final FlutterSecureStorage _storage;

  VendedorService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Lista todos os usuários com perfil "vendedor"
  Future<List<Vendedor>> listarVendedores() async {
    final url = Uri.parse('$_baseUrl/admin/vendedores');
    final headers = await _headers();

    final response = await _client.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((json) => Vendedor.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar vendedores (${response.statusCode})');
    }
  }

  // Cadastra um novo vendedor (apenas organizador pode)
  // Retorna um Map com 'sucesso' e 'mensagem' para exibir feedback na tela.
  Future<Map<String, dynamic>> criarVendedor({
    required String nome,
    required String email,
    required String senha,
  }) async {
    final url = Uri.parse('$_baseUrl/admin/vendedores');
    final headers = await _headers();

    try {
      final response = await _client.post(
        url,
        headers: headers,
        body: jsonEncode({
          'nome': nome,
          'email': email,
          'senha': senha,
          // 'perfil' não precisa ser enviado: o backend força TipoPerfil.VENDEDOR
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'sucesso': true, 'mensagem': 'Vendedor cadastrado com sucesso!'};
      } else {
        final body = jsonDecode(response.body);
        final mensagem = body['detail'] ?? 'Erro ao cadastrar vendedor.';
        return {'sucesso': false, 'mensagem': mensagem};
      }
    } catch (e) {
      return {'sucesso': false, 'mensagem': 'Falha de conexão com o servidor.'};
    }
  }
}

final vendedorServiceProvider = Provider<VendedorService>((ref) {
  return VendedorService();
});

// FutureProvider para listar vendedores (usado no multi-select da barraca)
final vendedoresProvider = FutureProvider<List<Vendedor>>((ref) async {
  final service = ref.watch(vendedorServiceProvider);
  return await service.listarVendedores();
});