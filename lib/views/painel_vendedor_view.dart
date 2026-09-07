import 'package:flutter/material.dart';
import 'package:flutter_application/providers/barraca_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/evento_model.dart';
import '../models/barraca_model.dart';
import '../providers/auth_provider.dart';
import '../providers/vendedor_barraca_provider.dart';
import '../providers/produto_provider.dart';
import '../screens/login_screen.dart';

// --- TELA 1: EVENTOS DO VENDEDOR ---
class PainelVendedorView extends ConsumerWidget {
  const PainelVendedorView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final eventosAsync = ref.watch(meusEventosVendedorProvider);

    final nomeUsuario = authState.nomeUsuario ?? 'Vendedor';
    final emailUsuario = authState.emailUsuario ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Meus Eventos'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Abrir menu',
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
                child: Icon(Icons.storefront, size: 35, color: Colors.deepPurple),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Meus Eventos'),
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Olá, $nomeUsuario 👋',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Selecione um evento para ver suas barracas.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: eventosAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Erro ao carregar: $err')),
                data: (eventos) {
                  if (eventos.isEmpty) {
                    return const Center(
                      child: Text('Você ainda não foi vinculado a nenhum evento.'),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(meusEventosVendedorProvider),
                    child: ListView.builder(
                      itemCount: eventos.length,
                      itemBuilder: (context, index) {
                        final evento = eventos[index];
                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1),
                              child: Icon(
                                Icons.event,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              evento.nome,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(evento.local.isEmpty ? 'Sem local definido' : evento.local),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BarracasDoVendedorView(evento: evento),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TELA 2: BARRACAS DO VENDEDOR DENTRO DO EVENTO SELECIONADO ---
class BarracasDoVendedorView extends ConsumerWidget {
  final Evento evento;

  const BarracasDoVendedorView({super.key, required this.evento});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barracasAsync = ref.watch(barracasDoEventoVendedorProvider(evento.id!));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: Text(evento.nome),
      ),
      body: barracasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro ao carregar: $err')),
        data: (barracas) {
          if (barracas.isEmpty) {
            return const Center(
              child: Text('Você não tem barracas neste evento.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: barracas.length,
            itemBuilder: (context, index) {
              final barraca = barracas[index];
              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.1),
                    child: Icon(
                      Icons.store,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    barraca.nome,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(barraca.tipo.isEmpty ? 'Sem categoria' : barraca.tipo),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProdutosDaBarracaVendedorView(barraca: barraca),
                      ),
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

// --- TELA 3: PRODUTOS DA BARRACA (somente leitura) ---
class ProdutosDaBarracaVendedorView extends ConsumerWidget {
  final Barraca barraca;

  const ProdutosDaBarracaVendedorView({super.key, required this.barraca});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final produtosAsync = ref.watch(produtosProvider(barraca.id!));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: Text(barraca.nome),
      ),
      body: produtosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
        data: (produtos) {
          if (produtos.isEmpty) {
            return const Center(
              child: Text('Nenhum produto cadastrado para esta barraca.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: produtos.length,
            itemBuilder: (context, index) {
              final produto = produtos[index];
              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.1),
                    child: Icon(
                      Icons.sell_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    produto.nome,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'R\$ ${produto.preco.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                  // Sem onLongPress/editar/excluir: vendedor só visualiza.
                ),
              );
            },
          );
        },
      ),
    );
  }
}