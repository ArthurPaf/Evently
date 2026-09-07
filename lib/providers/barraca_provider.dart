import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/barraca_model.dart';
import '../models/evento_model.dart';

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

  // Lista os eventos em que o vendedor tem ao menos uma barraca vinculada
  Future<List<Evento>> meusEventos() async {
    final url = Uri.parse('$_baseUrl/vendedor/meus-eventos');
    final headers = await _headers();

    final response = await _client.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((json) => Evento.fromJson(json)).toList();
    } else if (response.statusCode == 403) {
      throw Exception('Acesso negado: esta conta não é de vendedor.');
    } else {
      throw Exception('Falha ao carregar seus eventos (${response.statusCode})');
    }
  }

  // Lista apenas as barracas do vendedor dentro de um evento específico
  Future<List<Barraca>> minhasBarracasNoEvento(int eventoId) async {
    final url = Uri.parse('$_baseUrl/vendedor/eventos/$eventoId/barracas');
    final headers = await _headers();

    final response = await _client.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((json) => Barraca.fromJson(json)).toList();
    } else {
      throw Exception('Falha ao carregar suas barracas (${response.statusCode})');
    }
  }
}

final vendedorServiceProvider = Provider<VendedorService>((ref) {
  return VendedorService();
});

// Lista de eventos do vendedor logado
final meusEventosVendedorProvider = FutureProvider<List<Evento>>((ref) async {
  final service = ref.watch(vendedorServiceProvider);
  return await service.meusEventos();
});

// Barracas do vendedor dentro de um evento específico
final barracasDoEventoVendedorProvider =
    FutureProvider.family<List<Barraca>, int>((ref, eventoId) async {
  final service = ref.watch(vendedorServiceProvider);
  return await service.minhasBarracasNoEvento(eventoId);
});