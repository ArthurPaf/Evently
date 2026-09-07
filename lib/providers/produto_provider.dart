import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/produto_model.dart';

const String _baseUrl = 'http://127.0.0.1:8000';

class ProdutoService {
  final http.Client _client;
  final FlutterSecureStorage _storage;

  ProdutoService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Buscar produtos por ID da barraca
  Future<List<Produto>> buscarProdutos(int barracaId) async {
    final url = Uri.parse('$_baseUrl/barracas/$barracaId/produtos/');
    final headers = await _headers();

    try {
      final response = await _client.get(url, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> listJson = jsonDecode(response.body);
        return listJson.map((json) => Produto.fromJson(json)).toList();
      } else {
        throw Exception('Falha ao carregar produtos da barraca (${response.statusCode}).');
      }
    } catch (e) {
      throw Exception('Erro de conexão com o servidor: $e');
    }
  }

  // Criar produto (rota correta: /barracas/{barraca_id}/produtos/)
  Future<bool> criarProduto(Produto produto) async {
    if (produto.barracaId == null) return false;

    final url = Uri.parse('$_baseUrl/barracas/${produto.barracaId}/produtos/');
    final headers = await _headers();

    try {
      final response = await _client.post(
        url,
        headers: headers,
        body: jsonEncode(produto.toJson()),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // Editar produto (rota direta: /produtos/{id}/)
  Future<bool> editarProduto(Produto produto) async {
    if (produto.id == null) return false;

    final url = Uri.parse('$_baseUrl/produtos/${produto.id}/');
    final headers = await _headers();

    try {
      final response = await _client.put(
        url,
        headers: headers,
        body: jsonEncode(produto.toJson()),
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  // Excluir produto
  Future<bool> excluirProduto(int id) async {
    final url = Uri.parse('$_baseUrl/produtos/$id/');
    final headers = await _headers();

    try {
      final response = await _client.delete(url, headers: headers);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }
}

// Provider da classe de serviço
final produtoServiceProvider = Provider<ProdutoService>((ref) {
  return ProdutoService();
});

// FutureProvider para carregar a lista de produtos de uma barraca específica
final produtosProvider = FutureProvider.family<List<Produto>, int>((ref, barracaId) async {
  final service = ref.watch(produtoServiceProvider);
  return await service.buscarProdutos(barracaId);
});