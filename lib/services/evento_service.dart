import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/evento_model.dart';

const String baseUrl = 'http://127.0.0.1:8000';
const storage = FlutterSecureStorage();

// Função auxiliar para injetar o Token JWT nos cabeçalhos
Future<Map<String, String>> _getHeaders() async {
  final token = await storage.read(key: 'jwt_token');
  return {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}

// 1. LISTAR EVENTOS (Resolve o carregamento infinito / Status 401)
Future<List<Evento>> listarEventosService() async {
  try {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/eventos/'), // Mantém a barra final exigida pelo FastAPI
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((json) => Evento.fromJson(json)).toList();
    } else {
      print('❌ Erro HTTP ao listar eventos: ${response.statusCode}');
      return [];
    }
  } catch (e) {
    print('❌ Erro de conexão ao listar eventos: $e');
    return [];
  }
}

// 2. CRIAR EVENTO (Autenticado)
Future<Map<String, dynamic>> criarEventoService(Evento novoEvento) async {
  try {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/eventos/'),
      headers: headers,
      body: jsonEncode(novoEvento.toJson()),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return {'sucesso': true, 'mensagem': 'Evento criado com sucesso!'};
    } else {
      final body = jsonDecode(response.body);
      final mensagemErro = body['detail'] ?? 'Erro ao criar evento.';
      return {'sucesso': false, 'mensagem': mensagemErro};
    }
  } catch (e) {
    return {'sucesso': false, 'mensagem': 'Falha de conexão com o servidor.'};
  }
}