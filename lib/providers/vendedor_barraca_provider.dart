import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/barraca_model.dart';

const String _baseUrl = 'http://127.0.0.1:8000';

class VendedorBarracaService {
  final http.Client _client;
  final FlutterSecureStorage _storage;

  VendedorBarracaService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Retorna apenas as barracas em que o vendedor logado está vinculado
  Future<List<Barraca>> minhasBarracas() async {
    final url = Uri.parse('$_baseUrl/vendedor/minhas-barracas');
    final headers = await _headers();

    final response = await _client.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((json) => Barraca.fromJson(json)).toList();
    } else if (response.statusCode == 403) {
      throw Exception('Acesso negado: esta conta não é de vendedor.');
    } else {
      throw Exception('Falha ao carregar suas barracas (${response.statusCode})');
    }
  }
}

final vendedorBarracaServiceProvider = Provider<VendedorBarracaService>((ref) {
  return VendedorBarracaService();
});

final minhasBarracasProvider = FutureProvider<List<Barraca>>((ref) async {
  final service = ref.watch(vendedorBarracaServiceProvider);
  return await service.minhasBarracas();
});