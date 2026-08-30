import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BarracaController {
  final String baseUrl = 'http://127.0.0.1:8000';

  Future<bool> criarBarraca(int eventoId, String nome, String tipo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.post(
      Uri.parse('$baseUrl/eventos/$eventoId/barracas/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'nome': nome,
        'tipo': tipo,
      }),
    );

    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<List<dynamic>> listarBarracas(int eventoId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.get(
      Uri.parse('$baseUrl/eventos/$eventoId/barracas/'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }
}