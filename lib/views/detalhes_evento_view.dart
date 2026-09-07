import 'package:flutter/material.dart';
import 'package:flutter_application/services/barraca_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/evento_model.dart';
import '../models/barraca_model.dart';
import '../providers/barraca_provider.dart';
import 'detalhes_barraca_view.dart';
import '../providers/vendedor_provider.dart';
import '../models/vendedor_model.dart'; 

class DetalhesEventoView extends ConsumerWidget {
  final Evento evento;

  const DetalhesEventoView({super.key, required this.evento});

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
                // Lista de vendedores com checkbox (multi-select)
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

  // --- MODAL: MENU DE OPÇÕES DA BARRACA (EDITAR / EXCLUIR) ---
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
  // Pré-marca os vendedores que já estão vinculados a essa barraca
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
                                  builder: (context) => DetalhesBarracaView(barraca: item),
                                ),
                              );
                            },
                            onLongPress: () {
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