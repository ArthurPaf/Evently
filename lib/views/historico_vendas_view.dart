import '../widgets/evently_scaffold.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Future<void> _confirmarEstorno(
    BuildContext context,
    WidgetRef ref,
    Transacao venda,
  ) async {
    final sucesso = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EstornoDialog(venda: venda),
    );
    if (!context.mounted || sucesso != true) return;
    ref.invalidate(vendasDaBarracaProvider(barracaId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Estorno realizado e saldo devolvido ao cliente.'),
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
                      '${venda.itens.isNotEmpty ? '\n${venda.itens.map((i) => '${i.quantidade}x ${i.nomeProduto ?? 'Produto'}${i.quantidadeEstornada > 0 ? ' (${i.quantidadeEstornada} estornada(s))' : ''}').join('\n')}' : ''}'
                      '${venda.estornada
                          ? '\nESTORNADA'
                          : venda.valorEstornado > 0
                          ? '\nESTORNO PARCIAL: R\$ ${venda.valorEstornado.toStringAsFixed(2)}'
                          : ''}',
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

class _EstornoDialog extends ConsumerStatefulWidget {
  final Transacao venda;

  const _EstornoDialog({required this.venda});

  @override
  ConsumerState<_EstornoDialog> createState() => _EstornoDialogState();
}

class _EstornoDialogState extends ConsumerState<_EstornoDialog> {
  final _form = GlobalKey<FormState>();
  late final List<ItemVenda> _itens;
  late final Map<int, TextEditingController> _quantidades;
  bool _enviando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _itens = widget.venda.itens
        .where((i) => i.quantidadeDisponivel > 0)
        .toList();
    _quantidades = {
      for (final item in _itens)
        item.id: TextEditingController(text: _itens.length == 1 ? '1' : '0'),
    };
  }

  @override
  void dispose() {
    for (final controller in _quantidades.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int _quantidade(ItemVenda item) =>
      int.tryParse(_quantidades[item.id]!.text) ?? 0;

  double get _valorSelecionado => _itens.fold(
    0.0,
    (total, item) => total + _quantidade(item) * item.precoUnitario,
  );

  Future<void> _estornar({required bool tudo}) async {
    if (_enviando) return;
    if (!tudo && !_form.currentState!.validate()) return;
    final selecionados = [
      for (final item in _itens)
        if (_quantidade(item) > 0)
          {'item_id': item.id, 'quantidade': _quantidade(item)},
    ];
    if (!tudo && selecionados.isEmpty) {
      setState(() => _erro = 'Informe a quantidade de pelo menos um produto.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    final resultado = await ref
        .read(transacaoServiceProvider)
        .estornarVenda(widget.venda.id, itens: tudo ? null : selecionados);
    if (!mounted) return;
    setState(() => _enviando = false);
    if (resultado['sucesso'] == true) {
      Navigator.pop(context, true);
    } else {
      setState(
        () => _erro = resultado['mensagem'] ?? 'Não foi possível estornar.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final venda = widget.venda;
    return PopScope(
      canPop: !_enviando,
      child: AlertDialog(
        title: const Text('Estornar venda'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cliente: ${venda.nomeCliente ?? 'Não identificado'}'),
                  const SizedBox(height: 12),
                  const Text(
                    'O valor das unidades estornadas será devolvido ao saldo do cliente.',
                  ),
                  if (_itens.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Digite quantas unidades deseja estornar de cada produto. Use 0 para manter o produto.',
                    ),
                  ],
                  for (final item in _itens) ...[
                    const SizedBox(height: 20),
                    Text(
                      item.nomeProduto ?? 'Produto',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.quantidadeDisponivel} unidade(s) disponível(is) · R\$ ${item.precoUnitario.toStringAsFixed(2)} cada',
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _quantidades[item.id],
                      enabled: !_enviando,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Quantidade a estornar',
                      ),
                      onChanged: (_) => setState(() => _erro = null),
                      validator: (value) {
                        final qtd = int.tryParse(value ?? '');
                        if (qtd == null ||
                            qtd < 0 ||
                            qtd > item.quantidadeDisponivel) {
                          return 'Informe de 0 a ${item.quantidadeDisponivel} unidades.';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_itens.isNotEmpty)
                    Text(
                      'Valor selecionado: R\$ ${_valorSelecionado.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  Text(
                    'Estornar tudo devolve R\$ ${(venda.valorTotal - venda.valorEstornado).toStringAsFixed(2)} (todas as unidades restantes desta venda).',
                  ),
                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _erro!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (_enviando) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _enviando ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: _enviando ? null : () => _estornar(tudo: true),
            child: const Text('Estornar tudo'),
          ),
          if (_itens.isNotEmpty)
            ElevatedButton(
              onPressed: _enviando ? null : () => _estornar(tudo: false),
              child: const Text('Estornar quantidade'),
            ),
        ],
      ),
    );
  }
}
