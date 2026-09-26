import '../widgets/evently_scaffold.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/transacao_provider.dart';
import '../models/transacao_model.dart';

class HistoricoVendasView extends ConsumerWidget {
  final int barracaId;
  final String nomeBarraca;

  const HistoricoVendasView({
    super.key,
    required this.barracaId,
    required this.nomeBarraca,
  });

  void _confirmarEstorno(BuildContext context, WidgetRef ref, Transacao venda) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Estornar Venda'),
        content: Text(
          'Cliente: ${venda.nomeCliente ?? 'Não identificado'}\n\n'
          'Tem certeza que deseja estornar esta venda de R\$ ${venda.valorTotal.toStringAsFixed(2)}? '
          'O valor será devolvido ao saldo do cliente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);

              final resultado = await ref
                  .read(transacaoServiceProvider)
                  .estornarVenda(venda.id);

              if (context.mounted) {
                final bool sucesso = resultado['sucesso'] ?? false;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      resultado['mensagem'] ?? 'Erro desconhecido.',
                    ),
                    backgroundColor: sucesso ? Colors.green : Colors.red,
                  ),
                );

                if (sucesso) {
                  ref.invalidate(vendasDaBarracaProvider(barracaId));
                }
              }
            },
            child: const Text('Estornar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendasAsync = ref.watch(vendasDaBarracaProvider(barracaId));

    return EventlyScaffold(
      maxWidth: 760,
      appBar: AppBar(title: Text('Vendas - $nomeBarraca')),
      body: vendasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (vendas) {
          if (vendas.isEmpty) {
            return const Center(child: Text('Nenhuma venda registrada ainda.'));
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(vendasDaBarracaProvider(barracaId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vendas.length,
              itemBuilder: (context, index) {
                final venda = vendas[index];

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: Icon(
                      venda.estornada
                          ? Icons.replay_circle_filled
                          : Icons.receipt_long,
                      color: venda.estornada ? Colors.grey : Colors.green,
                    ),
                    title: Text(
                      'R\$ ${venda.valorTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: venda.estornada
                            ? TextDecoration.lineThrough
                            : null,
                        color: venda.estornada ? Colors.grey : null,
                      ),
                    ),
                    subtitle: Text(
                      'Cliente: ${venda.nomeCliente ?? 'Não identificado'}\n'
                      '${venda.dataHora.day.toString().padLeft(2, '0')}/'
                      '${venda.dataHora.month.toString().padLeft(2, '0')} às '
                      '${venda.dataHora.hour.toString().padLeft(2, '0')}:${venda.dataHora.minute.toString().padLeft(2, '0')}'
                      '${venda.itens.isNotEmpty ? '\n${venda.itens.map((i) => '${i.quantidade}x ${i.nomeProduto}').join(', ')}' : ''}'
                      '${venda.estornada ? '\nESTORNADA' : ''}',
                      style: venda.estornada
                          ? const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            )
                          : null,
                    ),
                    isThreeLine: true,
                    trailing: venda.estornada
                        ? null
                        : TextButton(
                            onPressed: () =>
                                _confirmarEstorno(context, ref, venda),
                            child: const Text(
                              'Estornar',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
