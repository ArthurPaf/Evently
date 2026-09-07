import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/evento_model.dart';
import '../providers/auth_provider.dart';
import '../providers/cliente_provider.dart';
import '../screens/login_screen.dart';

// --- TELA 1: LISTA DE EVENTOS DISPONÍVEIS ---
class PainelClienteView extends ConsumerWidget {
  const PainelClienteView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final eventosAsync = ref.watch(eventosPublicosProvider);

    final nomeUsuario = authState.nomeUsuario ?? 'Cliente';
    final emailUsuario = authState.emailUsuario ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Eventos'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(nomeUsuario),
              accountEmail: Text(emailUsuario),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 35, color: Colors.deepPurple),
              ),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sair', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
      body: eventosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro ao carregar: $err')),
        data: (eventos) {
          if (eventos.isEmpty) {
            return const Center(child: Text('Nenhum evento disponível no momento.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: eventos.length,
            itemBuilder: (context, index) {
              final evento = eventos[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.event),
                  title: Text(evento.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(evento.local.isEmpty ? 'Sem local definido' : evento.local),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MinhaCarteiraView(evento: evento)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- TELA 2: CARTEIRA DIGITAL (QR Code + saldo + extrato) ---
class MinhaCarteiraView extends ConsumerWidget {
  final Evento evento;

  const MinhaCarteiraView({super.key, required this.evento});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carteiraAsync = ref.watch(carteiraProvider(evento.id));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: Text(evento.nome),
      ),
      body: carteiraAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (carteira) {
          final extratoAsync = ref.watch(extratoProvider(carteira.id));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(carteiraProvider(evento.id));
              ref.invalidate(extratoProvider(carteira.id));
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Saldo disponível',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'R\$ ${carteira.saldoDigital.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        const SizedBox(height: 24),
                        QrImageView(
                          data: carteira.codigoIdentificador,
                          version: QrVersions.auto,
                          size: 200,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Código: ${carteira.codigoIdentificador}',
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mostre este QR Code ou informe o código na barraca',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Extrato',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                extratoAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => Text('Erro ao carregar extrato: $err'),
                  data: (transacoes) {
                    if (transacoes.isEmpty) {
                      return const Text('Nenhuma movimentação ainda.');
                    }
                    return Column(
                      children: transacoes.map((t) {
                        final isRecarga = t.tipo == 'recarga';
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Icon(
                              isRecarga ? Icons.add_circle_outline : Icons.remove_circle_outline,
                              color: isRecarga ? Colors.green : Colors.red,
                            ),
                            title: Text(isRecarga ? 'Recarga' : 'Compra'),
                            subtitle: Text(
                              '${t.dataHora.day.toString().padLeft(2, '0')}/'
                              '${t.dataHora.month.toString().padLeft(2, '0')} às '
                              '${t.dataHora.hour.toString().padLeft(2, '0')}:${t.dataHora.minute.toString().padLeft(2, '0')}'
                              '${t.itens.isNotEmpty ? '\n${t.itens.map((i) => '${i.quantidade}x ${i.nomeProduto}').join(', ')}' : ''}',
                            ),
                            isThreeLine: t.itens.isNotEmpty,
                            trailing: Text(
                              '${isRecarga ? '+' : '-'} R\$ ${t.valorTotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isRecarga ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}