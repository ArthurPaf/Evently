import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application/services/barraca_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/evento_model.dart';
import '../models/barraca_model.dart';
import '../providers/barraca_provider.dart';
import '../providers/vendedor_provider.dart';
import '../models/vendedor_model.dart';
import '../providers/auth_provider.dart';
import '../providers/evento_provider.dart';
import 'detalhes_barraca_view.dart'; // Tela para cadastro/visualização de produtos

class DetalhesEventoView extends ConsumerWidget {
  final Evento evento;
  final GlobalKey _qrKey = GlobalKey();

  DetalhesEventoView({super.key, required this.evento});

  // --- FORMATAÇÃO DE DATA BR COM DateTime.tryParse ---
  String _converterParaBR(String dataISO) {
    if (dataISO.isEmpty) return '';
    try {
      final data = DateTime.tryParse(dataISO);
      if (data == null) return dataISO;

      final dia = data.day.toString().padLeft(2, '0');
      final mes = data.month.toString().padLeft(2, '0');
      return '$dia/$mes/${data.year}';
    } catch (_) {
      return dataISO;
    }
  }

  // Monta o link público que o cliente usa para se cadastrar/entrar no evento.
  // Uri.base pega a origem atual (ex: http://localhost:5000) automaticamente,
  // então funciona tanto em desenvolvimento quanto depois de publicado.
  String _linkDoEvento() {
    return '${Uri.base.origin}/evento/${evento.id}';
  }

  void _copiarLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _linkDoEvento()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copiado!'), backgroundColor: Colors.green),
    );
  }

  // Captura o QR Code renderizado na tela e baixa como arquivo .png de
  // verdade, pronto pra imprimir ou compartilhar fora do app.
  Future<void> _baixarQrCode(BuildContext context) async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // pixelRatio alto garante boa resolução para impressão
      final image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();

      final blob = html.Blob([bytes], 'image/png');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'qrcode_${evento.nome}.png'.replaceAll(' ', '_'))
        ..click();
      html.Url.revokeObjectUrl(url);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR Code baixado!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao baixar QR Code: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- CARD: LINK DE ACESSO PARA CLIENTES (organizador e administrador) ---
  Widget _buildCardLinkCliente(BuildContext context) {
    final link = _linkDoEvento();

    return Card(
      elevation: 0,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Link de acesso para clientes',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Compartilhe este link (ou o QR Code) para que os clientes se cadastrem e acessem o saldo digital deste evento.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      link,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _copiarLink(context),
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copiar link',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: RepaintBoundary(
                key: _qrKey,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(
                    data: link,
                    version: QrVersions.auto,
                    size: 150,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => _baixarQrCode(context),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Baixar QR Code (PNG)'),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Salve a imagem para imprimir em cartazes ou compartilhar',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DIÁLOGO: CONFIRMAR ENCERRAMENTO DO EVENTO ---
  void _confirmarEncerramento(BuildContext context, WidgetRef ref) {
    final dataFim = DateTime.tryParse(evento.dataFim);
    final antesDoFim = dataFim != null && DateTime.now().isBefore(dataFim);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar Evento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tem certeza que deseja encerrar o evento "${evento.nome}"? '
              'Essa ação não pode ser desfeita e vai bloquear novas recargas e vendas.',
            ),
            if (antesDoFim) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'O período do evento ainda não terminou (vai até ${_converterParaBR(evento.dataFim)}). '
                        'Tem certeza que deseja encerrar mesmo sem ter cumprido o período todo?',
                        style: const TextStyle(color: Colors.deepOrange, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
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

              final resultado = await ref.read(eventosProvider.notifier).encerrarEvento(evento.id);

              if (context.mounted) {
                final bool sucesso = resultado['sucesso'] ?? false;
                final String mensagem = resultado['mensagem'] ?? 'Erro ao encerrar o evento.';

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(mensagem),
                    backgroundColor: sucesso ? Colors.green : Colors.red,
                  ),
                );

                if (sucesso) {
                  Navigator.pop(context); // volta pra lista de eventos
                }
              }
            },
            child: const Text('Encerrar Evento'),
          ),
        ],
      ),
    );
  }

  // --- MODAL: CRIAR BARRACA ---
  void _abrirModalNovaBarraca(BuildContext context, WidgetRef ref) {
    final nomeController = TextEditingController();
    final tipoController = TextEditingController();
    final List<int> vendedoresSelecionados = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
              top: 16,
              left: 16,
              right: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    'Nova Barraca',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome da Barraca',
                      prefixIcon: Icon(Icons.storefront_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tipoController,
                    decoration: const InputDecoration(
                      labelText: 'Tipo (ex: Comida, Bebida)',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Vendedores responsáveis',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final vendedoresAsync = ref.watch(vendedoresProvider);

                      return vendedoresAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (err, _) => Text('Erro ao carregar vendedores: $err'),
                        data: (vendedores) {
                          if (vendedores.isEmpty) {
                            return const Text(
                              'Nenhum vendedor cadastrado ainda.',
                              style: TextStyle(color: Colors.grey),
                            );
                          }

                          return Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView(
                              shrinkWrap: true,
                              children: vendedores.map((Vendedor v) {
                                final selecionado = vendedoresSelecionados.contains(v.id);
                                return CheckboxListTile(
                                  dense: true,
                                  title: Text(v.nome),
                                  subtitle: Text(v.email),
                                  value: selecionado,
                                  onChanged: (marcado) {
                                    setModalState(() {
                                      if (marcado == true) {
                                        vendedoresSelecionados.add(v.id);
                                      } else {
                                        vendedoresSelecionados.remove(v.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nomeController.text.trim().isNotEmpty && evento.id != null) {
                          final novaBarraca = Barraca(
                            nome: nomeController.text.trim(),
                            tipo: tipoController.text.trim(),
                            eventoId: evento.id,
                            vendedorIds: vendedoresSelecionados,
                          );

                          final sucesso = await ref
                              .read(barracaServiceProvider)
                              .criarBarraca(novaBarraca);

                          if (sucesso && context.mounted) {
                            ref.invalidate(barracasProvider(evento.id!));
                            Navigator.pop(modalContext);
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Erro ao salvar no banco!'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text(
                        'Salvar Barraca',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- MENU INFERIOR AO SEGURAR O CARD ---
  void _exibirOpcoesBarraca(BuildContext context, WidgetRef ref, Barraca barraca) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                barraca.nome,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                title: const Text('Editar Barraca'),
                onTap: () {
                  Navigator.pop(modalContext);
                  _abrirModalEditarBarraca(context, ref, barraca);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Excluir Barraca'),
                onTap: () {
                  Navigator.pop(modalContext);
                  _confirmarExclusaoBarraca(context, ref, barraca);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- MODAL: EDITAR BARRACA ---
  void _abrirModalEditarBarraca(BuildContext context, WidgetRef ref, Barraca barraca) {
    final nomeController = TextEditingController(text: barraca.nome);
    final tipoController = TextEditingController(text: barraca.tipo);
    final List<int> vendedoresSelecionados =
        barraca.vendedores.map((v) => v.id).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
              top: 16,
              left: 16,
              right: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    'Editar Barraca',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome da Barraca',
                      prefixIcon: Icon(Icons.storefront_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tipoController,
                    decoration: const InputDecoration(
                      labelText: 'Tipo (ex: Comida, Bebida)',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Vendedores responsáveis',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final vendedoresAsync = ref.watch(vendedoresProvider);

                      return vendedoresAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (err, _) => Text('Erro ao carregar vendedores: $err'),
                        data: (vendedores) {
                          if (vendedores.isEmpty) {
                            return const Text(
                              'Nenhum vendedor cadastrado ainda.',
                              style: TextStyle(color: Colors.grey),
                            );
                          }

                          return Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView(
                              shrinkWrap: true,
                              children: vendedores.map((Vendedor v) {
                                final selecionado = vendedoresSelecionados.contains(v.id);
                                return CheckboxListTile(
                                  dense: true,
                                  title: Text(v.nome),
                                  subtitle: Text(v.email),
                                  value: selecionado,
                                  onChanged: (marcado) {
                                    setModalState(() {
                                      if (marcado == true) {
                                        vendedoresSelecionados.add(v.id);
                                      } else {
                                        vendedoresSelecionados.remove(v.id);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (nomeController.text.trim().isNotEmpty) {
                          final barracaAtualizada = Barraca(
                            id: barraca.id,
                            nome: nomeController.text.trim(),
                            tipo: tipoController.text.trim(),
                            eventoId: evento.id,
                            vendedorIds: vendedoresSelecionados,
                          );

                          final sucesso = await ref
                              .read(barracaServiceProvider)
                              .editarBarraca(barracaAtualizada);

                          if (sucesso && context.mounted) {
                            ref.invalidate(barracasProvider(evento.id!));
                            Navigator.pop(modalContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Barraca atualizada com sucesso!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Erro ao atualizar a barraca!'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text(
                        'Salvar Alterações',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- DIÁLOGO: CONFIRMAR EXCLUSÃO ---
  void _confirmarExclusaoBarraca(BuildContext context, WidgetRef ref, Barraca barraca) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir Barraca'),
        content: Text('Deseja realmente excluir a barraca "${barraca.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (barraca.id == null) return;

              final sucesso = await ref
                  .read(barracaServiceProvider)
                  .excluirBarraca(barraca.id!);

              if (context.mounted) {
                Navigator.pop(dialogContext);
                if (sucesso) {
                  ref.invalidate(barracasProvider(evento.id!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Barraca excluída com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Erro ao excluir a barraca!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barracasAsync = ref.watch(barracasProvider(evento.id!));
    final authState = ref.watch(authProvider);
    final isOrganizador = authState.perfil == 'organizador';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          evento.nome,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informações do Evento
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_month_outlined,
                            size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Período: ${_converterParaBR(evento.dataInicio)} até ${_converterParaBR(evento.dataFim)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (evento.local.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 20, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Local: ${evento.local}',
                              style: TextStyle(
                                color: Colors.grey[800],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // --- LINK DE ACESSO PARA CLIENTES (só enquanto o evento está ativo) ---
            if (!evento.encerrado) ...[
              _buildCardLinkCliente(context),
              const SizedBox(height: 12),
            ],

            // --- BOTÃO / SELO DE ENCERRAMENTO (só organizador) ---
            if (isOrganizador)
              evento.encerrado
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'EVENTO ENCERRADO',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54),
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: () => _confirmarEncerramento(context, ref),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Encerrar Evento'),
                      ),
                    ),
            const SizedBox(height: 20),

            // Cabeçalho da Lista
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Barracas do Evento',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (!evento.encerrado)
                  ElevatedButton.icon(
                    onPressed: () => _abrirModalNovaBarraca(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Barraca'),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Lista de Barracas
            Expanded(
              child: barracasAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Erro: $error')),
                data: (barracas) {
                  if (barracas.isEmpty) {
                    return Center(
                      child: Text(
                        'Nenhuma barraca cadastrada ainda.',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(barracasProvider(evento.id!));
                    },
                    child: ListView.builder(
                      itemCount: barracas.length,
                      itemBuilder: (context, index) {
                        final item = barracas[index];

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
                              item.nome,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              item.tipo.isEmpty ? 'Sem categoria' : item.tipo,
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DetalhesBarracaView(
                                    barraca: item,
                                    somenteLeitura: evento.encerrado,
                                  ),
                                ),
                              );
                            },
                            onLongPress: evento.encerrado
                                ? null
                                : () {
                                    _exibirOpcoesBarraca(context, ref, item);
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