import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/administrador_model.dart';
import '../models/evento_model.dart';

const String _baseUrl = 'http://127.0.0.1:8000';

class AdministradorService {
  final http.Client _client;
  final FlutterSecureStorage _storage;

  AdministradorService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // --- Ações do organizador: cadastrar/listar administradores ---

  Future<List<Administrador>> listarAdministradores() async {
    final url = Uri.parse('$_baseUrl/admin/administradores');
    final headers = await _headers();
    final response = await _client.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((json) => Administrador.fromJson(json)).toList();
    }
    throw Exception('Falha ao carregar administradores (${response.statusCode})');
  }

  Future<Map<String, dynamic>> criarAdministrador({
    required String nome,
    required String email,
    required String senha,
  }) async {
    final url = Uri.parse('$_baseUrl/admin/administradores');
    final headers = await _headers();

    try {
      final response = await _client.post(
        url,
        headers: headers,
        body: jsonEncode({'nome': nome, 'email': email, 'senha': senha}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'sucesso': true, 'mensagem': 'Administrador cadastrado com sucesso!'};
      } else {
        final body = jsonDecode(response.body);
        return {
          'sucesso': false,
          'mensagem': body['detail'] ?? 'Erro ao cadastrar administrador.',
        };
      }
    } catch (e) {
      return {'sucesso': false, 'mensagem': 'Falha de conexão com o servidor.'};
    }
  }

  // --- Ações do próprio administrador logado ---

  Future<List<Evento>> meusEventos() async {
    final url = Uri.parse('$_baseUrl/administrador/meus-eventos');
    final headers = await _headers();
    final response = await _client.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((json) => Evento.fromJson(json)).toList();
    } else if (response.statusCode == 403) {
      throw Exception('Acesso negado: esta conta não é de administrador.');
    }
    throw Exception('Falha ao carregar seus eventos (${response.statusCode})');
  }

  // Edita um evento que o administrador gerencia.
  // Usa a mesma rota PUT /eventos/{id} do organizador, agora liberada
  // no backend também para administradores vinculados a esse evento.
  Future<Map<String, dynamic>> editarEvento(Evento evento) async {
    final url = Uri.parse('$_baseUrl/eventos/${evento.id}');
    final headers = await _headers();

    try {
      final response = await _client.put(
        url,
        headers: headers,
        body: jsonEncode(evento.toJson()),
      );

      if (response.statusCode == 200) {
        return {'sucesso': true, 'mensagem': 'Evento atualizado!'};
      }
      final body = jsonDecode(response.body);
      return {'sucesso': false, 'mensagem': body['detail'] ?? 'Erro ao atualizar.'};
    } catch (e) {
      return {'sucesso': false, 'mensagem': 'Erro de conexão.'};
    }
  }
}

final administradorServiceProvider = Provider<AdministradorService>((ref) {
  return AdministradorService();
});

// Lista de administradores existentes (usado no multi-select ao editar evento)
final administradoresProvider = FutureProvider<List<Administrador>>((ref) async {
  final service = ref.watch(administradorServiceProvider);
  return await service.listarAdministradores();
});

// Eventos que o administrador logado gerencia
final meusEventosAdministradorProvider = FutureProvider<List<Evento>>((ref) async {
  final service = ref.watch(administradorServiceProvider);
  return await service.meusEventos();
});