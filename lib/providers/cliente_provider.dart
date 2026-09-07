import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/evento_model.dart';
import '../models/carteira_model.dart';
import '../models/transacao_model.dart';

const String _baseUrl = 'http://127.0.0.1:8000';

class ClienteService {
  final http.Client _client;
  final FlutterSecureStorage _storage;

  ClienteService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Evento>> listarEventosPublicos() async {
    final url = Uri.parse('$_baseUrl/eventos/publicos');
    final headers = await _headers();
    final response = await _client.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((json) => Evento.fromJson(json)).toList();
    }
    throw Exception('Falha ao carregar eventos (${response.statusCode})');
  }

  // Cria (ou recupera, se já existir) a carteira do cliente para esse evento
  Future<Carteira> entrarNoEvento(int eventoId) async {
    final url = Uri.parse('$_baseUrl/clientes/eventos/$eventoId/entrar');
    final headers = await _headers();
    final response = await _client.post(url, headers: headers);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Carteira.fromJson(jsonDecode(response.body));
    }
    throw Exception('Falha ao entrar no evento (${response.statusCode})');
  }

  Future<List<Transacao>> meuExtrato(int carteiraId) async {
    final url = Uri.parse('$_baseUrl/clientes/carteiras/$carteiraId/extrato');
    final headers = await _headers();
    final response = await _client.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((json) => Transacao.fromJson(json)).toList();
    }
    throw Exception('Falha ao carregar extrato (${response.statusCode})');
  }
}

final clienteServiceProvider = Provider<ClienteService>((ref) {
  return ClienteService();
});

final eventosPublicosProvider = FutureProvider<List<Evento>>((ref) async {
  final service = ref.watch(clienteServiceProvider);
  return await service.listarEventosPublicos();
});

// Carteira do cliente para um evento específico (buscada sob demanda ao entrar)
final carteiraProvider =
    FutureProvider.family<Carteira, int>((ref, eventoId) async {
  final service = ref.watch(clienteServiceProvider);
  return await service.entrarNoEvento(eventoId);
});

final extratoProvider =
    FutureProvider.family<List<Transacao>, int>((ref, carteiraId) async {
  final service = ref.watch(clienteServiceProvider);
  return await service.meuExtrato(carteiraId);
});