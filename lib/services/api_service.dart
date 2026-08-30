import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Se estiver rodando em emulador Android, use 10.0.2.2. Se for Flutter Web, use 127.0.0.1
  static const String baseUrl = 'http://127.0.0.1:8000';

  Future<bool> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      // O FastAPI espera form-data para login padrão OAuth2
      body: {
        'username': email,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      // Salva o token no navegador/celular
      await prefs.setString('token', data['access_token']);
      return true;
    } else {
      return false;
    }
  }
}