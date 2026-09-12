import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/transacao_provider.dart';

class DashboardView extends ConsumerWidget {
  final int eventoId;
  final String nomeEvento;

  const DashboardView({super.key, required this.eventoId, required this.nomeEvento});

  Future<void> _exportarRelatorio(BuildContext context, WidgetRef ref) async {
    final bytes = await ref.read(transacaoServiceProvider).exportarDashboardPdf(eventoId);

    if (bytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao gerar o relatório.'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Dispara o download no navegador (Flutter Web)
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'relatorio_$nomeEvento.pdf')
      ..click();
    html.Url.revokeObjectUrl(url);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Relatório exportado!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider(eventoId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard - $nomeEvento'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Exportar Relatório (PDF)',
            onPressed: () => _exportarRelatorio(context, ref),
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro ao carregar dashboard: $err')),
        data: (dados) {
          final totalVendido = (dados['total_vendido'] as num).toDouble();
          final numeroTransacoes = dados['numero_transacoes'] as int;
          final produtosMaisVendidos = dados['produtos_mais_vendidos'] as List;
          // Já vem ordenado do backend, da barraca que mais vendeu para a que menos vendeu.
          final vendasPorBarraca = dados['vendas_por_barraca'] as List;
          final vendasPorPeriodo = dados['vendas_por_periodo'] as List;

          final periodos = vendasPorPeriodo.map((v) => v['periodo'] as String).toList();
          final valores = vendasPorPeriodo.map((v) => (v['valor_total'] as num).toDouble()).toList();
          final maiorValor = valores.isEmpty ? 1.0 : valores.reduce((a, b) => a > b ? a : b);

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

                Text('Vendas por Período',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Agrupado por dia e hora — cobre eventos de vários dias.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (vendasPorPeriodo.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('Sem vendas registradas ainda.'),
                  )
                else
                  SizedBox(
                    height: 240,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maiorValor * 1.25,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: maiorValor / 4 == 0 ? 1 : maiorValor / 4,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.withOpacity(0.2),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 44,
                              getTitlesWidget: (value, meta) => Text(
                                value.toStringAsFixed(0),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 48,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= periodos.length) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Transform.rotate(
                                    angle: -0.6,
                                    child: Text(
                                      periodos[i],
                                      style: const TextStyle(fontSize: 9),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                              'R\$ ${rod.toY.toStringAsFixed(2)}',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        barGroups: List.generate(periodos.length, (i) {
                          return BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: valores[i],
                                width: 16,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Theme.of(context).colorScheme.primary,
                                    Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                const SizedBox(height: 28),

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
                const SizedBox(height: 4),
                Text(
                  'Ordenado da barraca que mais vendeu para a que menos vendeu.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 8),
                if (vendasPorBarraca.isEmpty)
                  const Text('Sem vendas registradas ainda.')
                else
                  ...List.generate(vendasPorBarraca.length, (i) {
                    final b = vendasPorBarraca[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: i == 0
                              ? Colors.amber.withOpacity(0.2)
                              : Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          child: i == 0
                              ? const Icon(Icons.emoji_events, color: Colors.amber)
                              : Icon(Icons.store, color: Theme.of(context).colorScheme.primary),
                        ),
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