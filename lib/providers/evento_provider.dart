import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/evento_model.dart';

const String baseUrl = 'http://127.0.0.1:8000';
const storage = FlutterSecureStorage();

final eventosProvider = AsyncNotifierProvider<EventosNotifier, List<Evento>>(() {
  return EventosNotifier();
});

class EventosNotifier extends AsyncNotifier<List<Evento>> {
  @override
  Future<List<Evento>> build() async {
    return fetchEventos();
  }

  Future<List<Evento>> fetchEventos() async {
    final token = await storage.read(key: 'jwt_token');
    final response = await http.get(
      Uri.parse('$baseUrl/eventos/'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((json) => Evento.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      throw Exception('Sessão expirada. Faça login novamente.');
    } else {
      throw Exception('Falha ao carregar eventos: ${response.statusCode}');
    }
  }

  // --- MÉTODO ADICIONADO PARA CORRIGIR O ERRO DE COMPILAÇÃO ---
  Future<Map<String, dynamic>> criarEvento(Evento novoEvento) async {
    try {
      final token = await storage.read(key: 'jwt_token');
      final response = await http.post(
        Uri.parse('$baseUrl/eventos/'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(novoEvento.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        ref.invalidateSelf(); // Invalida o estado para recarregar a lista automaticamente
        return {'sucesso': true, 'mensagem': 'Evento criado com sucesso!'};
      }

      final body = jsonDecode(response.body);
      return {
        'sucesso': false,
        'mensagem': body['detail'] ?? 'Erro ao criar evento.',
      };
    } catch (e) {
      return {
        'sucesso': false,
        'mensagem': 'Falha de conexão com o servidor.',
      };
    }
  }

  Future<bool> excluirEvento(int id) async {
    try {
      final token = await storage.read(key: 'jwt_token');
      final response = await http.delete(
        Uri.parse('$baseUrl/eventos/$id'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        ref.invalidateSelf();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> editarEvento(Evento evento) async {
    try {
      final token = await storage.read(key: 'jwt_token');
      final response = await http.put(
        Uri.parse('$baseUrl/eventos/${evento.id}'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(evento.toJson()),
      );

      if (response.statusCode == 200) {
        ref.invalidateSelf();
        return {'sucesso': true, 'mensagem': 'Evento atualizado!'};
      }

      final body = jsonDecode(response.body);
      return {'sucesso': false, 'mensagem': body['detail'] ?? 'Erro ao atualizar.'};
    } catch (e) {
      return {'sucesso': false, 'mensagem': 'Erro de conexão.'};
    }
  }
}