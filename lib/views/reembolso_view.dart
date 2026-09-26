import '../widgets/evently_scaffold.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../providers/transacao_provider.dart';
import '../providers/cliente_provider.dart';

class ReembolsoView extends ConsumerStatefulWidget {
  final int eventoId;
  final String nomeEvento;
  final bool proprioCliente;

  const ReembolsoView({
    super.key,
    required this.eventoId,
    required this.nomeEvento,
    this.proprioCliente = false,
  });

  @override
  ConsumerState<ReembolsoView> createState() => _ReembolsoViewState();
}

class _ReembolsoViewState extends ConsumerState<ReembolsoView> {
  final _codigoController = TextEditingController();
  final _valorController = TextEditingController();
  bool _carregando = false;
  bool _mostrarScanner = false;
  bool _reembolsarTudo = true;

  @override
  void dispose() {
    _codigoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _confirmarReembolso() async {
    final codigo = _codigoController.text.trim();

    if (!widget.proprioCliente && codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o código do cliente.')),
      );
      return;
    }

    double? valor;
    if (!_reembolsarTudo) {
      final valorText = _valorController.text.replaceAll(',', '.').trim();
      valor = double.tryParse(valorText);
      if (valor == null || !valor.isFinite || valor <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informe um valor válido para reembolsar.'),
          ),
        );
        return;
      }
    }

    setState(() => _carregando = true);

    final resultado = widget.proprioCliente
        ? await ref
              .read(clienteServiceProvider)
              .reembolsarPropriaCarteira(
                eventoId: widget.eventoId,
                valor: valor,
              )
        : await ref
              .read(transacaoServiceProvider)
              .realizarReembolso(
                eventoId: widget.eventoId,
                codigoIdentificador: codigo,
                valor: valor,
              );

    if (!mounted) return;
    setState(() => _carregando = false);

    final bool sucesso = resultado['sucesso'] ?? false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resultado['mensagem'] ?? 'Erro desconhecido.'),
        backgroundColor: sucesso ? Colors.green : Colors.red,
      ),
    );

    if (sucesso) {
      if (widget.proprioCliente) {
        Navigator.pop(context, true);
        return;
      }
      _codigoController.clear();
      _valorController.clear();
    }
  }

  Widget _buildScanner() {
    return Center(
      child: SizedBox(
        width: 300,
        height: 300,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: MobileScanner(
                fit: BoxFit.cover,
                onDetect: (capture) {
                  if (capture.barcodes.isEmpty) return;
                  final valor = capture.barcodes.first.rawValue;
                  if (valor != null) {
                    setState(() {
                      _codigoController.text = valor;
                      _mostrarScanner = false;
                    });
                  }
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() => _mostrarScanner = false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EventlyScaffold(
      maxWidth: 760,
      appBar: AppBar(title: Text('Reembolso - ${widget.nomeEvento}')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.proprioCliente)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Reembolso simulado: o valor será descontado da sua carteira e registrado no extrato. Nenhum dinheiro será transferido.',
                    ),
                  ),
                if (!widget.proprioCliente) ...[
                  if (_mostrarScanner)
                    _buildScanner()
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _mostrarScanner = true),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Escanear QR Code do cliente'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codigoController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Código do cliente',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reembolsar todo o saldo restante'),
                  value: _reembolsarTudo,
                  onChanged: _carregando
                      ? null
                      : (v) => setState(() => _reembolsarTudo = v),
                ),
                if (!_reembolsarTudo) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _valorController,
                    enabled: !_carregando,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Valor a reembolsar (R\$)',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                    ),
                    onPressed: _carregando ? null : _confirmarReembolso,
                    child: _carregando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Confirmar Reembolso'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
