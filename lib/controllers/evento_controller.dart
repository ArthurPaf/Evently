import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/evento_model.dart';

class EventoController {
  static const String baseUrl = 'http://127.0.0.1:8000';

  Future<List<Evento>> buscarEventos() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse('$baseUrl/eventos/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      List jsonResponse = jsonDecode(response.body);
      return jsonResponse.map((evento) => Evento.fromJson(evento)).toList();
    } else {
      throw Exception('Falha ao carregar eventos');
    }
  }

  Future<bool> criarEvento(String nome, String dataInicio, String dataFim) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final response = await http.post(
      Uri.parse('$baseUrl/eventos/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'nome': nome,
        'data_inicio': dataInicio,
        'data_fim': dataFim
      }),
    );

    return response.statusCode == 200;
  }
}