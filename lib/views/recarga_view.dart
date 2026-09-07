import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../providers/transacao_provider.dart';

class RecargaView extends ConsumerStatefulWidget {
  final int eventoId;
  final String nomeEvento;

  const RecargaView({super.key, required this.eventoId, required this.nomeEvento});

  @override
  ConsumerState<RecargaView> createState() => _RecargaViewState();
}

class _RecargaViewState extends ConsumerState<RecargaView> {
  final _codigoController = TextEditingController();
  final _valorController = TextEditingController();
  bool _carregando = false;
  bool _mostrarScanner = false;

  @override
  void dispose() {
    _codigoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _confirmarRecarga() async {
    final codigo = _codigoController.text.trim();
    final valorText = _valorController.text.replaceAll(',', '.').trim();
    final valor = double.tryParse(valorText) ?? 0.0;

    if (codigo.isEmpty || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o código do cliente e um valor válido.')),
      );
      return;
    }

    setState(() => _carregando = true);

    final resultado = await ref.read(transacaoServiceProvider).realizarRecarga(
          eventoId: widget.eventoId,
          codigoIdentificador: codigo,
          valor: valor,
        );

    setState(() => _carregando = false);
    if (!mounted) return;

    final bool sucesso = resultado['sucesso'] ?? false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resultado['mensagem'] ?? 'Erro desconhecido.'),
        backgroundColor: sucesso ? Colors.green : Colors.red,
      ),
    );

    if (sucesso) {
      _codigoController.clear();
      _valorController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recarga - ${widget.nomeEvento}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_mostrarScanner)
              SizedBox(
                height: 300,
                child: Stack(
                  children: [
                    MobileScanner(
                      onDetect: (capture) {
                        final barcode = capture.barcodes.first;
                        final valor = barcode.rawValue;
                        if (valor != null) {
                          setState(() {
                            _codigoController.text = valor;
                            _mostrarScanner = false;
                          });
                        }
                      },
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
              )
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
            const SizedBox(height: 12),
            TextField(
              controller: _valorController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor da recarga (R\$)',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _carregando ? null : _confirmarRecarga,
                child: _carregando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirmar Recarga'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}