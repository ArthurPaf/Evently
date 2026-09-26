import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/transacao_model.dart';

const String _baseUrl = 'http://127.0.0.1:8000';

class TransacaoService {
  final http.Client _client;
  final FlutterSecureStorage _storage;

  TransacaoService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Recarga simulada (organizador ou administrador do evento)
  Future<Map<String, dynamic>> realizarRecarga({
    required int eventoId,
    required String codigoIdentificador,
    required double valor,
  }) async {
    final url = Uri.parse('$_baseUrl/eventos/$eventoId/recargas');
    final headers = await _headers();

    try {
      final response = await _client.post(
        url,
        headers: headers,
        body: jsonEncode({
          'codigo_identificador': codigoIdentificador,
          'valor': valor,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'sucesso': true, 'mensagem': 'Recarga realizada com sucesso!'};
      }
      final body = jsonDecode(response.body);
      return {'sucesso': false, 'mensagem': body['detail'] ?? 'Erro ao recarregar.'};
    } catch (e) {
      return {'sucesso': false, 'mensagem': 'Falha de conexão com o servidor.'};
    }
  }

  // Venda (vendedor vinculado à barraca)
  Future<Map<String, dynamic>> realizarVenda({
    required int barracaId,
    required String codigoIdentificador,
    required List<Map<String, int>> itens,
  }) async {
    final url = Uri.parse('$_baseUrl/barracas/$barracaId/vendas');
    final headers = await _headers();

    try {
      final response = await _client.post(
        url,
        headers: headers,
        body: jsonEncode({
          'codigo_identificador': codigoIdentificador,
          'itens': itens,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'sucesso': true, 'mensagem': 'Venda realizada com sucesso!'};
      }
      final body = jsonDecode(response.body);
      return {'sucesso': false, 'mensagem': body['detail'] ?? 'Erro ao vender.'};
    } catch (e) {
      return {'sucesso': false, 'mensagem': 'Falha de conexão com o servidor.'};
    }
  }

  Future<Map<String, dynamic>> buscarDashboard(int eventoId) async {
    final url = Uri.parse('$_baseUrl/eventos/$eventoId/dashboard');
    final headers = await _headers();
    final response = await _client.get(url, headers: headers);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Falha ao carregar dashboard (${response.statusCode})');
  }

  // Baixa o relatório em PDF (bytes brutos do arquivo)
  Future<Uint8List?> exportarDashboardPdf(int eventoId) async {
    final url = Uri.parse('$_baseUrl/eventos/$eventoId/dashboard/exportar');
    final headers = await _headers();
    final response = await _client.get(url, headers: headers);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return null;
  }

  // Baixa o relatório em Excel (bytes brutos do arquivo)
  Future<Uint8List?> exportarDashboardExcel(int eventoId) async {
    final url = Uri.parse('$_baseUrl/eventos/$eventoId/dashboard/exportar-excel');
    final headers = await _headers();
    final response = await _client.get(url, headers: headers);

    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    return null;
  }

  // Reembolso de saldo (total ou parcial) para um cliente
  Future<Map<String, dynamic>> realizarReembolso({
    required int eventoId,
    required String codigoIdentificador,
    double? valor, // null = reembolsa todo o saldo restante
  }) async {
    final url = Uri.parse('$_baseUrl/eventos/$eventoId/reembolsos');
    final headers = await _headers();

    try {
      final response = await _client.post(
        url,
        headers: headers,
        body: jsonEncode({
          'codigo_identificador': codigoIdentificador,
          if (valor != null) 'valor': valor,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'sucesso': true, 'mensagem': 'Reembolso realizado com sucesso!'};
      }
      final body = jsonDecode(response.body);
      return {'sucesso': false, 'mensagem': body['detail'] ?? 'Erro ao reembolsar.'};
    } catch (e) {
      return {'sucesso': false, 'mensagem': 'Falha de conexão com o servidor.'};
    }
  }

  // Estorna uma venda específica
  Future<Map<String, dynamic>> estornarVenda(int transacaoId) async {
    final url = Uri.parse('$_baseUrl/transacoes/$transacaoId/estornar');
    final headers = await _headers();

    try {
      final response = await _client.post(url, headers: headers);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'sucesso': true, 'mensagem': 'Venda estornada com sucesso!'};
      }
      final body = jsonDecode(response.body);
      return {'sucesso': false, 'mensagem': body['detail'] ?? 'Erro ao estornar.'};
    } catch (e) {
      return {'sucesso': false, 'mensagem': 'Falha de conexão com o servidor.'};
    }
  }

  // Últimas vendas de uma barraca, usado para localizar uma venda a estornar
  Future<List<Transacao>> listarVendasDaBarraca(int barracaId) async {
    final url = Uri.parse('$_baseUrl/barracas/$barracaId/vendas');
    final headers = await _headers();
    final response = await _client.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.map((json) => Transacao.fromJson(json)).toList();
    }
    throw Exception('Falha ao carregar vendas (${response.statusCode})');
  }
}

final transacaoServiceProvider = Provider<TransacaoService>((ref) {
  return TransacaoService();
});

final dashboardProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, int>((ref, eventoId) async {
  final service = ref.watch(transacaoServiceProvider);
  return await service.buscarDashboard(eventoId);
});

final vendasDaBarracaProvider =
    FutureProvider.autoDispose.family<List<Transacao>, int>((ref, barracaId) async {
  final service = ref.watch(transacaoServiceProvider);
  return await service.listarVendasDaBarraca(barracaId);
});