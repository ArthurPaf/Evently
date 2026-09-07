import 'dart:convert';
import 'package:flutter_application/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/barraca_model.dart';
import 'dart:developer' as developer;

// DICA: Use 'http://10.0.2.2:8000' se estiver rodando no Emulador Android.
// Use 'http://127.0.0.1:8000' para Web/Windows ou IP local para celular físico.
const String _baseUrl = 'http://127.0.0.1:8000'; 

class BarracaService {
  final http.Client _client;
  final String? _token;
  final _storage = const FlutterSecureStorage();

  BarracaService({http.Client? client, String? token})
      : _client = client ?? http.Client(),
        _token = token;

  // Busca o token do parâmetro, do provider ou diretamente do disco (Fallback seguro)
  Future<Map<String, String>> _getHeaders([String? overrideToken]) async {
    final tokenParaUsar = overrideToken ?? _token ?? await _storage.read(key: 'jwt_token');

    print('🔑 [DEBUG] Token utilizado na requisição: $tokenParaUsar');

    return {
      'Content-Type': 'application/json',
      if (tokenParaUsar != null && tokenParaUsar.isNotEmpty)
        'Authorization': 'Bearer $tokenParaUsar',
    };
  }

  // Buscar barracas por ID do evento
  Future<List<Barraca>> buscarBarracas(int eventoId, {String? token}) async {
    final url = Uri.parse('$_baseUrl/eventos/$eventoId/barracas/');
    final headers = await _getHeaders(token);

    try {
      final response = await _client
          .get(url, headers: headers)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Tempo limite de conexão esgotado.'),
          );

      if (response.statusCode == 200) {
        final List<dynamic> listJson = jsonDecode(response.body);
        return listJson.map((json) => Barraca.fromJson(json)).toList();
      } else {
        throw Exception('Falha ao carregar barracas (${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Erro ao conectar com o servidor: $e');
    }
  }

  // Criar barraca
  // Criar barraca
Future<bool> criarBarraca(Barraca barraca, {String? token}) async {
  if (barraca.eventoId == null) {
    developer.log('❌ [ERRO] Impossível criar barraca sem eventoId', name: 'BarracaService');
    return false;
  }

  // URL corrigida apontando para a rota do evento: /eventos/{evento_id}/barracas/
  final url = Uri.parse('$_baseUrl/eventos/${barraca.eventoId}/barracas/');
  final headers = await _getHeaders(token);

  try {
    final response = await _client.post(
      url,
      headers: headers,
      body: jsonEncode(barraca.toJson()),
    );

    developer.log('STATUS POST: ${response.statusCode}', name: 'BarracaService');
    developer.log('RESPOSTA POST: ${response.body}', name: 'BarracaService');

    return response.statusCode == 200 || response.statusCode == 201;
  } catch (e) {
    developer.log('❌ Erro de conexão no POST: $e', name: 'BarracaService');
    return false;
  }
}

  // Editar barraca
  Future<bool> editarBarraca(Barraca barraca, {String? token}) async {
    if (barraca.id == null) return false;

    final headers = await _getHeaders(token);
    developer.log('📡 [PUT] Headers enviados: $headers', name: 'BarracaService');

    final url = Uri.parse('$_baseUrl/barracas/${barraca.id}/');
    try {
      final response = await _client.put(
        url,
        headers: headers,
        body: jsonEncode(barraca.toJson()),
      );

      developer.log('STATUS PUT: ${response.statusCode}', name: 'BarracaService');
      developer.log('RESPOSTA PUT: ${response.body}', name: 'BarracaService');

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      developer.log('❌ Erro de conexão no PUT: $e', name: 'BarracaService');
      return false;
    }
  }

  // Excluir barraca
  Future<bool> excluirBarraca(int id, {String? token}) async {
    final url = Uri.parse('$_baseUrl/barracas/$id/');
    final headers = await _getHeaders(token);

    try {
      final response = await _client.delete(
        url,
        headers: headers,
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }
}

// Provider do serviço
final barracaServiceProvider = Provider<BarracaService>((ref) {
  final authState = ref.watch(authProvider);
  return BarracaService(token: authState.token);
});

// FutureProvider para listar as barracas do evento
final barracasProvider = FutureProvider.family<List<Barraca>, int>((ref, eventoId) async {
  final service = ref.watch(barracaServiceProvider);
  return await service.buscarBarracas(eventoId);
});