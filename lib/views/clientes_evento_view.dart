import '../widgets/evently_scaffold.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../providers/auth_provider.dart';
import '../providers/evento_provider.dart' show baseUrl;

final clientesEventoProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, int>((ref, eventoId) async {
      final auth = ref.watch(authProvider);
      if (!auth.isAuthenticated || !auth.isOrganizador) {
        throw Exception('Acesso exclusivo do organizador.');
      }
      final response = await http.get(
        Uri.parse('$baseUrl/eventos/$eventoId/clientes'),
        headers: {'Authorization': 'Bearer ${auth.token}'},
      );
      if (response.statusCode != 200) {
        throw Exception(
          'Não foi possível consultar os clientes (${response.statusCode}).',
        );
      }
      return (jsonDecode(utf8.decode(response.bodyBytes)) as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    });

class ClientesEventoView extends ConsumerStatefulWidget {
  final int eventoId;
  final String nomeEvento;
  const ClientesEventoView({
    super.key,
    required this.eventoId,
    required this.nomeEvento,
  });

  @override
  ConsumerState<ClientesEventoView> createState() => _ClientesEventoViewState();
}

class _ClientesEventoViewState extends ConsumerState<ClientesEventoView> {
  String _busca = '';

  @override
  Widget build(BuildContext context) {
    final clientes = ref.watch(clientesEventoProvider(widget.eventoId));
    return EventlyScaffold(
      maxWidth: 760,
      appBar: AppBar(
        title: Text('Clientes - ${widget.nomeEvento}'),
        actions: [
          IconButton(
            tooltip: 'Atualizar clientes',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.invalidate(clientesEventoProvider(widget.eventoId)),
          ),
        ],
      ),
      body: clientes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (erro, _) => Center(child: Text('$erro')),
        data: (lista) {
          final filtrados = lista
              .where(
                (c) =>
                    c['nome'].toString().toLowerCase().contains(_busca) ||
                    c['email'].toString().toLowerCase().contains(_busca),
              )
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${lista.length} clientes vinculados ao evento',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Participantes com carteira neste evento, mesmo sem compras.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nome ou e-mail',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (valor) =>
                          setState(() => _busca = valor.trim().toLowerCase()),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(clientesEventoProvider(widget.eventoId));
                    await ref.read(
                      clientesEventoProvider(widget.eventoId).future,
                    );
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtrados.isEmpty ? 1 : filtrados.length,
                    itemBuilder: (context, index) {
                      if (filtrados.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            lista.isEmpty
                                ? 'Nenhum cliente neste evento ainda.'
                                : 'Nenhum cliente encontrado.',
                          ),
                        );
                      }
                      final cliente = filtrados[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(cliente['nome']),
                          subtitle: Text(
                            '${cliente['email']}\nCliente #${cliente['cliente_id']} · Saldo: R\$ ${(cliente['saldo'] as num).toStringAsFixed(2)}',
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
