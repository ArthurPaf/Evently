import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transacao_provider.dart';

class DashboardView extends ConsumerWidget {
  final int eventoId;
  final String nomeEvento;

  const DashboardView({super.key, required this.eventoId, required this.nomeEvento});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider(eventoId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard - $nomeEvento'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro ao carregar dashboard: $err')),
        data: (dados) {
          final totalVendido = (dados['total_vendido'] as num).toDouble();
          final numeroTransacoes = dados['numero_transacoes'] as int;
          final produtosMaisVendidos = dados['produtos_mais_vendidos'] as List;
          final vendasPorBarraca = dados['vendas_por_barraca'] as List;
          final vendasPorHora = dados['vendas_por_hora'] as List;

          final maiorValorHora = vendasPorHora.isEmpty
              ? 1.0
              : vendasPorHora
                  .map((v) => (v['valor_total'] as num).toDouble())
                  .reduce((a, b) => a > b ? a : b);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(dashboardProvider(eventoId)),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _CardMetrica(
                        titulo: 'Total Vendido',
                        valor: 'R\$ ${totalVendido.toStringAsFixed(2)}',
                        cor: Colors.green,
                        icone: Icons.attach_money,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CardMetrica(
                        titulo: 'Transações',
                        valor: '$numeroTransacoes',
                        cor: Colors.blue,
                        icone: Icons.receipt_long,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                Text('Vendas por Horário',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (vendasPorHora.isEmpty)
                  const Text('Sem vendas registradas ainda.')
                else
                  SizedBox(
                    height: 160,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: vendasPorHora.map((v) {
                        final hora = v['hora'];
                        final valor = (v['valor_total'] as num).toDouble();
                        final alturaRelativa = (valor / maiorValorHora) * 120;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  valor > 0 ? valor.toStringAsFixed(0) : '',
                                  style: const TextStyle(fontSize: 9),
                                ),
                                Container(
                                  height: alturaRelativa < 4 ? 4 : alturaRelativa,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('${hora}h', style: const TextStyle(fontSize: 10)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 24),

                Text('Produtos Mais Vendidos',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (produtosMaisVendidos.isEmpty)
                  const Text('Sem vendas registradas ainda.')
                else
                  ...produtosMaisVendidos.map((p) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.local_fire_department, color: Colors.orange),
                        title: Text(p['nome']),
                        subtitle: Text('${p['quantidade']} unidades vendidas'),
                        trailing: Text(
                          'R\$ ${(p['valor_total'] as num).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),

                Text('Vendas por Barraca',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (vendasPorBarraca.isEmpty)
                  const Text('Sem vendas registradas ainda.')
                else
                  ...vendasPorBarraca.map((b) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.store, color: Colors.deepPurple),
                        title: Text(b['barraca']),
                        trailing: Text(
                          'R\$ ${(b['valor_total'] as num).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CardMetrica extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color cor;
  final IconData icone;

  const _CardMetrica({
    required this.titulo,
    required this.valor,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: cor),
            const SizedBox(height: 8),
            Text(titulo, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            const SizedBox(height: 4),
            Text(valor, style: TextStyle(color: cor, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}