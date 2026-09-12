import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/evento_model.dart';
import '../providers/auth_provider.dart';
import '../providers/administrador_provider.dart';
import 'detalhes_evento_view.dart';
import 'recarga_view.dart';
import '../screens/login_screen.dart';

class PainelAdministradorView extends ConsumerWidget {
  const PainelAdministradorView({super.key});

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

  // --- MENU AO SEGURAR O CARD DO EVENTO ---
  void _exibirOpcoesEvento(BuildContext context, WidgetRef ref, Evento evento) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
              ListTile(
                leading: const Icon(Icons.qr_code_scanner, color: Colors.teal),
                title: const Text('Recarregar Saldo de Cliente'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecargaView(
                        eventoId: evento.id,
                        nomeEvento: evento.nome,
                      ),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                title: const Text('Editar Evento'),
                onTap: () {
                  Navigator.pop(ctx);
                  _abrirModalEditarEvento(context, ref, evento);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- MODAL: EDITAR EVENTO (sem opção de excluir - só o organizador exclui) ---
  void _abrirModalEditarEvento(BuildContext context, WidgetRef ref, Evento evento) {
    final nomeController = TextEditingController(text: evento.nome);
    final localController = TextEditingController(text: evento.local);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Editar Evento',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome do Evento',
                prefixIcon: Icon(Icons.event_note),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: localController,
              decoration: const InputDecoration(
                labelText: 'Local do Evento',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (nomeController.text.trim().isEmpty) return;

                  final eventoAtualizado = Evento(
                    id: evento.id,
                    nome: nomeController.text.trim(),
                    local: localController.text.trim(),
                    dataInicio: evento.dataInicio,
                    dataFim: evento.dataFim,
                    administradorIds: evento.administradores.map((a) => a.id).toList(),
                  );

                  final resultado = await ref
                      .read(administradorServiceProvider)
                      .editarEvento(eventoAtualizado);

                  if (context.mounted) {
                    Navigator.pop(modalContext);
                    final bool sucesso = resultado['sucesso'] ?? false;
                    final String mensagem =
                        resultado['mensagem'] ?? 'Erro ao atualizar o evento.';

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(mensagem),
                        backgroundColor: sucesso ? Colors.green : Colors.red,
                      ),
                    );

                    if (sucesso) {
                      ref.invalidate(meusEventosAdministradorProvider);
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final eventosAsync = ref.watch(meusEventosAdministradorProvider);

    final nomeUsuario = authState.nomeUsuario ?? 'Administrador';
    final emailUsuario = authState.emailUsuario ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Eventos que Administro'),
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
                child: Icon(Icons.admin_panel_settings, size: 35, color: Colors.deepPurple),
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
              'Toque em um evento para gerenciar barracas e produtos, ou segure para ver o dashboard, recarregar saldo ou editar.',
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
                    onRefresh: () async => ref.invalidate(meusEventosAdministradorProvider),
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
                            subtitle: Text(
                              '${_converterParaBR(evento.dataInicio)} até ${_converterParaBR(evento.dataFim)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DetalhesEventoView(evento: evento),
                                ),
                              );
                            },
                            onLongPress: () {
                              _exibirOpcoesEvento(context, ref, evento);
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