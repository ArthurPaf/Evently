import 'package:flutter/material.dart';
import 'package:flutter_application/views/criar_evento_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/evento_model.dart';
import '../providers/auth_provider.dart';
import '../providers/evento_provider.dart';
import 'detalhes_evento_view.dart';
import '../screens/login_screen.dart';
import 'cadastrar_vendedor_view.dart';
import '../providers/administrador_provider.dart';
import '../models/administrador_model.dart';
import 'cadastrar_administrador_view.dart';

class PainelOrganizadorView extends ConsumerWidget {
  const PainelOrganizadorView({super.key});

  // --- FUNÇÃO AUXILIAR DE FORMATAÇÃO DE DATA BR ---
  String _converterParaBR(String dataISO) {
    if (dataISO.isEmpty) return '';
    try {
      final data = DateTime.parse(dataISO);
      final dia = data.day.toString().padLeft(2, '0');
      final mes = data.month.toString().padLeft(2, '0');
      return '$dia/$mes/${data.year}';
    } catch (_) {
      return dataISO;
    }
  }

  String _converterParaISO(String dataBR) {
    if (dataBR.isEmpty) return '';
    final partes = dataBR.split('/');
    if (partes.length < 3) return dataBR;
    return '${partes[2]}-${partes[1].padLeft(2, '0')}-${partes[0].padLeft(2, '0')}';
  }

  DateTime _parseDataBR(String dataBR) {
    try {
      final partes = dataBR.split('/');
      if (partes.length == 3) {
        return DateTime(
          int.parse(partes[2]),
          int.parse(partes[1]),
          int.parse(partes[0]),
        );
      }
    } catch (_) {}
    return DateTime.now();
  }

  // --- MENU INFERIOR AO SEGURAR O CARD ---
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
                leading: const Icon(Icons.edit_outlined, color: Colors.blue),
                title: const Text('Editar Evento'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmarEdicao(context, ref, evento);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Excluir Evento', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmarExclusao(context, ref, evento);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // --- CONFIRMAÇÃO E EXCLUSÃO NA API ---
  void _confirmarExclusao(BuildContext context, WidgetRef ref, Evento evento) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Evento'),
        content: Text('Tem certeza que deseja excluir o evento "${evento.nome}"?'),
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

              final sucesso = await ref
                  .read(eventosProvider.notifier)
                  .excluirEvento(evento.id);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      sucesso
                          ? 'Evento excluído com sucesso!'
                          : 'Erro ao excluir o evento.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  // --- CONFIRMAÇÃO E EDIÇÃO NA API COM CALENDÁRIO ---
  void _confirmarEdicao(BuildContext context, WidgetRef ref, Evento evento) {
  final nomeController = TextEditingController(text: evento.nome);
  final localController = TextEditingController(text: evento.local);
 
  String dataInicioBR = _converterParaBR(evento.dataInicio);
  String dataFimBR = _converterParaBR(evento.dataFim);
 
  // Pré-marca os administradores já vinculados a esse evento
  final List<int> administradoresSelecionados =
      evento.administradores.map((a) => a.id).toList();
 
  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> selecionarData(bool isDataInicio) async {
            FocusManager.instance.primaryFocus?.unfocus();
 
            final dataAtual = _parseDataBR(isDataInicio ? dataInicioBR : dataFimBR);
 
            final DateTime? dataSelecionada = await showDatePicker(
              context: context,
              initialDate: dataAtual,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
 
            if (dataSelecionada != null) {
              final ano = dataSelecionada.year;
              final mes = dataSelecionada.month.toString().padLeft(2, '0');
              final dia = dataSelecionada.day.toString().padLeft(2, '0');
              final dataFormatadaBR = '$dia/$mes/$ano';
 
              setDialogState(() {
                if (isDataInicio) {
                  dataInicioBR = dataFormatadaBR;
                } else {
                  dataFimBR = dataFormatadaBR;
                }
              });
            }
          }
 
          return AlertDialog(
            title: const Text('Editar Evento'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => selecionarData(true),
                    borderRadius: BorderRadius.circular(4),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data de Início',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        dataInicioBR.isEmpty
                            ? 'Selecione a data de início'
                            : dataInicioBR,
                        style: TextStyle(
                          fontSize: 15,
                          color: dataInicioBR.isEmpty
                              ? Colors.grey[600]
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => selecionarData(false),
                    borderRadius: BorderRadius.circular(4),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data de Término',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        dataFimBR.isEmpty
                            ? 'Selecione a data de término'
                            : dataFimBR,
                        style: TextStyle(
                          fontSize: 15,
                          color: dataFimBR.isEmpty
                              ? Colors.grey[600]
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Administradores deste evento',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer(
                    builder: (context, ref, _) {
                      final administradoresAsync = ref.watch(administradoresProvider);
 
                      return administradoresAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (err, _) => Text('Erro ao carregar administradores: $err'),
                        data: (administradores) {
                          if (administradores.isEmpty) {
                            return const Text(
                              'Nenhum administrador cadastrado ainda.',
                              style: TextStyle(color: Colors.grey),
                            );
                          }
 
                          return Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView(
                              shrinkWrap: true,
                              children: administradores.map((Administrador a) {
                                final selecionado = administradoresSelecionados.contains(a.id);
                                return CheckboxListTile(
                                  dense: true,
                                  title: Text(a.nome),
                                  subtitle: Text(a.email),
                                  value: selecionado,
                                  onChanged: (marcado) {
                                    setDialogState(() {
                                      if (marcado == true) {
                                        administradoresSelecionados.add(a.id);
                                      } else {
                                        administradoresSelecionados.remove(a.id);
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
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nomeController.text.isEmpty ||
                      localController.text.isEmpty ||
                      dataInicioBR.isEmpty ||
                      dataFimBR.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Por favor, preencha todos os campos!'),
                      ),
                    );
                    return;
                  }
 
                  final eventoAtualizado = Evento(
                    id: evento.id,
                    nome: nomeController.text.trim(),
                    local: localController.text.trim(),
                    dataInicio: _converterParaISO(dataInicioBR),
                    dataFim: _converterParaISO(dataFimBR),
                    administradorIds: administradoresSelecionados,
                  );
 
                  Navigator.pop(ctx);
 
                  final resultado = await ref
                      .read(eventosProvider.notifier)
                      .editarEvento(eventoAtualizado);
 
                  if (context.mounted) {
                    final bool sucesso = resultado['sucesso'] ?? false;
                    final String mensagem = resultado['mensagem'] ?? 'Erro ao atualizar o evento.';
 
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(mensagem),
                        backgroundColor: sucesso ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      );
    },
  );
}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final eventosAsync = ref.watch(eventosProvider);

    final nomeUsuario = authState.nomeUsuario ?? 'Organizador';
    final emailUsuario = authState.emailUsuario ?? 'organizador@email.com';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Meus Eventos'),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Abrir menu',
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
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
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('Meus Eventos'),
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tela de Dashboard em breve!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Configurações'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tela de Configurações em breve!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: const Text('Cadastrar Vendedor'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CadastrarVendedorView()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: const Text('Cadastrar Administrador'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CadastrarAdministradorView()),
                );
              },
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
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
                  'Gerencie seus eventos.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: eventosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Erro ao carregar: $err')),
              data: (eventos) {
                if (eventos.isEmpty) {
                  return const Center(child: Text('Nenhum evento cadastrado.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: eventos.length,
                  itemBuilder: (context, index) {
                    final evento = eventos[index];
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
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
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CriarEventoView()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}