import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/evento_model.dart';
import '../providers/auth_provider.dart';
import '../providers/cliente_provider.dart';
import '../views/cliente_entry_view.dart';

// --- CARTEIRA DIGITAL (QR Code + saldo + extrato) ---
class MinhaCarteiraView extends ConsumerStatefulWidget {
  final Evento evento;

  const MinhaCarteiraView({super.key, required this.evento});

  @override
  ConsumerState<MinhaCarteiraView> createState() => _MinhaCarteiraViewState();
}

class _MinhaCarteiraViewState extends ConsumerState<MinhaCarteiraView> {
  Timer? _timer;
  int? _carteiraId;

  @override
  void initState() {
    super.initState();
    // Atualiza saldo/extrato automaticamente a cada 3 segundos, sem precisar
    // recarregar a página — cobre recargas/vendas feitas em outro dispositivo.
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _atualizar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _atualizar() {
    if (!mounted) return;
    ref.invalidate(carteiraProvider(widget.evento.id));
    if (_carteiraId != null) {
      ref.invalidate(extratoProvider(_carteiraId!));
    }
  }

  void _sair() async {
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ClienteEntryView(eventoId: widget.evento.id)),
      );
    }
  }

  void _abrirModalAdicionarCredito() {
    final valorController = TextEditingController();
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
              final valorText = valorController.text.replaceAll(',', '.').trim();
              final valor = double.tryParse(valorText) ?? 0.0;

              if (valor <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Informe um valor válido.')),
                );
                return;
              }

              setModalState(() => carregando = true);

              final resultado = await ref.read(clienteServiceProvider).recarregarPropriaCarteira(
                    eventoId: widget.evento.id,
                    valor: valor,
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
                _atualizar(); // reflete o novo saldo na hora, sem esperar o próximo ciclo
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
                  Text('Adicionar Créditos',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Pagamento simulado — nenhum valor real será cobrado.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: valorController,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Valor (R\$)',
                      prefixIcon: Icon(Icons.attach_money),
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
                          : const Text('Confirmar Pagamento'),
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
    final carteiraAsync = ref.watch(carteiraProvider(widget.evento.id));

    // Guarda o id da carteira assim que ela chega, pra o timer conseguir
    // invalidar o extrato certo nos próximos ciclos.
    ref.listen(carteiraProvider(widget.evento.id), (previous, next) {
      next.whenData((carteira) => _carteiraId = carteira.id);
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: Text(widget.evento.nome),
        automaticallyImplyLeading: false, // sem botão de voltar: aqui é a única tela do cliente
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _sair,
          ),
        ],
      ),
      body: carteiraAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (carteira) {
          _carteiraId = carteira.id;
          final extratoAsync = ref.watch(extratoProvider(carteira.id));

          return RefreshIndicator(
            onRefresh: () async => _atualizar(),
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
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _abrirModalAdicionarCredito,
                            icon: const Icon(Icons.add_card),
                            label: const Text('Adicionar Créditos'),
                          ),
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