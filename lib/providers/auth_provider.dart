import 'dart:convert';
import 'package:flutter_application/services/barraca_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'evento_provider.dart';
import 'barraca_provider.dart';
import 'vendedor_barraca_provider.dart';
import 'produto_provider.dart';
import 'administrador_provider.dart';
import 'cliente_provider.dart';

// --- FUNÇÃO AUXILIAR: decodifica o payload de um JWT sem pacotes externos ---
// Um JWT tem 3 partes separadas por ".": header.payload.signature
// Só precisamos do payload (parte do meio), que é um JSON em Base64Url.
Map<String, dynamic>? _decodificarPayloadJwt(String token) {
  try {
    final partes = token.split('.');
    if (partes.length != 3) return null;

    String payload = partes[1];
    // Base64Url pode vir sem padding ('='), então completamos manualmente
    payload = base64Url.normalize(payload);

    final payloadDecodificado = utf8.decode(base64Url.decode(payload));
    return jsonDecode(payloadDecodificado) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

// 1. Modelo do Estado com suporte a dados do usuário
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? token;
  final String? error;
  final String? nomeUsuario;
  final String? emailUsuario;
  final String? perfil; // 'organizador', 'vendedor', 'cliente'

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.token,
    this.error,
    this.nomeUsuario,
    this.emailUsuario,
    this.perfil,
  });

  bool get isOrganizador => perfil == 'organizador';
  bool get isVendedor => perfil == 'vendedor';

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? token,
    String? error,
    String? nomeUsuario,
    String? emailUsuario,
    String? perfil,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      error: error,
      nomeUsuario: nomeUsuario ?? this.nomeUsuario,
      emailUsuario: emailUsuario ?? this.emailUsuario,
      perfil: perfil ?? this.perfil,
    );
  }
}

// 2. Notifier
class AuthNotifier extends Notifier<AuthState> {
  final _storage = const FlutterSecureStorage();
  final String _baseUrl = 'http://127.0.0.1:8000';

  @override
  AuthState build() {
    checkToken();
    return AuthState();
  }

  // Recupera token, nome, email e perfil salvos
  Future<void> checkToken() async {
    final token = await _storage.read(key: 'jwt_token');
    final email = await _storage.read(key: 'user_email');
    final nome = await _storage.read(key: 'user_nome');

    if (token != null) {
      final payload = _decodificarPayloadJwt(token);
      final perfil = payload?['perfil'] as String?;

      state = state.copyWith(
        isAuthenticated: true,
        token: token,
        emailUsuario: email,
        nomeUsuario: nome,
        perfil: perfil,
      );
    }
  }

  // Função de Login
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': email,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];

        // Extrai o perfil direto do token (evita precisar de outra requisição)
        final payload = _decodificarPayloadJwt(token);
        final perfil = payload?['perfil'] as String?;

        // Persiste token e e-mail localmente
        await _storage.write(key: 'jwt_token', value: token);
        await _storage.write(key: 'user_email', value: email);

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          token: token,
          emailUsuario: email,
          perfil: perfil,
        );

        // Tenta buscar detalhes do perfil (nome) do backend
        await buscarPerfil(token);

        // IMPORTANTE: invalida os providers de dados do usuário anterior.
        // Sem isso, trocar de conta sem reiniciar o app reaproveita dados
        // (eventos/barracas) da sessão anterior, que ainda estavam em cache.
        ref.invalidate(eventosProvider);
        ref.invalidate(barracasProvider);
        ref.invalidate(meusEventosVendedorProvider);
        ref.invalidate(produtosProvider);
        ref.invalidate(meusEventosAdministradorProvider);
        ref.invalidate(carteiraProvider);
        ref.invalidate(extratoProvider);

        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Credenciais inválidas ou erro no servidor',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erro de conexão com o servidor: $e',
      );
      return false;
    }
  }

  // Busca dados do perfil no FastAPI
  Future<void> buscarPerfil(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final nome = data['nome'] ?? data['username'];

        if (nome != null) {
          await _storage.write(key: 'user_nome', value: nome.toString());
          state = state.copyWith(nomeUsuario: nome.toString());
        }
      }
    } catch (_) {
      // Falha silenciosa se a rota /auth/me não estiver implementada
    }
  }

  // Logout
  Future<void> logout() async {
    await _storage.deleteAll();
    state = AuthState();

    // Mesma razão do login: limpa o cache pra próxima conta não herdar dados.
    ref.invalidate(eventosProvider);
    ref.invalidate(barracasProvider);
    ref.invalidate(meusEventosVendedorProvider);
    ref.invalidate(produtosProvider);
    ref.invalidate(meusEventosAdministradorProvider);
    ref.invalidate(carteiraProvider);
    ref.invalidate(extratoProvider);
  }
}

// 3. Provider Global
final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});