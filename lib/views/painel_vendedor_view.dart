import 'package:flutter/material.dart';
import 'package:flutter_application/providers/barraca_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/evento_model.dart';
import '../models/barraca_model.dart';
import '../providers/auth_provider.dart';
import '../providers/vendedor_barraca_provider.dart';
import '../providers/produto_provider.dart';
import '../screens/login_screen.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/transacao_provider.dart';


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
class ProdutosDaBarracaVendedorView extends ConsumerStatefulWidget {
  final Barraca barraca;
 
  const ProdutosDaBarracaVendedorView({super.key, required this.barraca});
 
  @override
  ConsumerState<ProdutosDaBarracaVendedorView> createState() =>
      _ProdutosDaBarracaVendedorViewState();
}
 
class _ProdutosDaBarracaVendedorViewState
    extends ConsumerState<ProdutosDaBarracaVendedorView> {
  // produtoId -> quantidade selecionada
  final Map<int, int> _carrinho = {};
 
  double _calcularTotal(List produtos) {
    double total = 0.0;
    for (final produto in produtos) {
      final qtd = _carrinho[produto.id] ?? 0;
      total += qtd * produto.preco;
    }
    return total;
  }
 
  void _abrirCheckout(double total) {
    final codigoController = TextEditingController();
    bool mostrarScanner = false;
    bool carregando = false;
 
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> confirmar() async {
              final codigo = codigoController.text.trim();
              if (codigo.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Escaneie ou digite o código do cliente.')),
                );
                return;
              }
 
              setModalState(() => carregando = true);
 
              final itens = _carrinho.entries
                  .where((e) => e.value > 0)
                  .map((e) => {'produto_id': e.key, 'quantidade': e.value})
                  .toList();
 
              final resultado = await ref.read(transacaoServiceProvider).realizarVenda(
                    barracaId: widget.barraca.id!,
                    codigoIdentificador: codigo,
                    itens: itens,
                  );
 
              setModalState(() => carregando = false);
 
              final bool sucesso = resultado['sucesso'] ?? false;
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(resultado['mensagem'] ?? 'Erro desconhecido.'),
                    backgroundColor: sucesso ? Colors.green : Colors.red,
                  ),
                );
              }
 
              if (sucesso) {
                Navigator.pop(modalContext);
                setState(() => _carrinho.clear());
              }
            }
 
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
                top: 16, left: 16, right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Total: R\$ ${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (mostrarScanner)
                    Center(
                      child: SizedBox(
                        width: 250,
                        height: 250,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: MobileScanner(
                            fit: BoxFit.cover,
                            onDetect: (capture) {
                              if (capture.barcodes.isEmpty) return;
                              final valor = capture.barcodes.first.rawValue;
                              if (valor != null) {
                                setModalState(() {
                                  codigoController.text = valor;
                                  mostrarScanner = false;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => setModalState(() => mostrarScanner = true),
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Escanear QR Code do cliente'),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codigoController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Código do cliente',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: carregando ? null : confirmar,
                      child: carregando
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Confirmar Venda'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final produtosAsync = ref.watch(produtosProvider(widget.barraca.id!));
 
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: Text(widget.barraca.nome),
      ),
      body: produtosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Erro: $err')),
        data: (produtos) {
          if (produtos.isEmpty) {
            return const Center(child: Text('Nenhum produto cadastrado para esta barraca.'));
          }
 
          final total = _calcularTotal(produtos);
 
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: produtos.length,
                  itemBuilder: (context, index) {
                    final produto = produtos[index];
                    final qtd = _carrinho[produto.id] ?? 0;
 
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(produto.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('R\$ ${produto.preco.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: qtd > 0
                                  ? () => setState(() => _carrinho[produto.id!] = qtd - 1)
                                  : null,
                            ),
                            Text('$qtd', style: const TextStyle(fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => setState(() => _carrinho[produto.id!] = qtd + 1),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (total > 0)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => _abrirCheckout(total),
                      child: Text('Finalizar Venda - R\$ ${total.toStringAsFixed(2)}'),
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