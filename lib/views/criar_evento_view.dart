import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/evento_model.dart';
import '../models/administrador_model.dart';
import '../providers/evento_provider.dart';
import '../providers/administrador_provider.dart';

class CriarEventoView extends ConsumerStatefulWidget {
  const CriarEventoView({super.key});

  @override
  ConsumerState<CriarEventoView> createState() => _CriarEventoViewState();
}

class _CriarEventoViewState extends ConsumerState<CriarEventoView> {
  final _nomeController = TextEditingController();
  final _localController = TextEditingController();

  String _dataInicio = '';
  String _dataFim = '';
  final List<int> _administradoresSelecionados = [];

  // Converte DD/MM/AAAA para AAAA-MM-DD para envio à API
  String _converterParaISO(String dataBR) {
    final partes = dataBR.split('/');
    return '${partes[2]}-${partes[1]}-${partes[0]}';
  }

  // Converte DD/MM/AAAA para DateTime para validação de datas
  DateTime _parseDataBR(String dataBR) {
    final partes = dataBR.split('/');
    return DateTime(
      int.parse(partes[2]),
      int.parse(partes[1]),
      int.parse(partes[0]),
    );
  }

  Future<void> _selecionarData(BuildContext context, bool isDataInicio) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final DateTime agora = DateTime.now();

    final DateTime? dataSelecionada = await showDatePicker(
      context: context,
      initialDate: agora,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (dataSelecionada != null) {
      final ano = dataSelecionada.year;
      final mes = dataSelecionada.month.toString().padLeft(2, '0');
      final dia = dataSelecionada.day.toString().padLeft(2, '0');

      final dataFormatadaBR = '$dia/$mes/$ano';

      setState(() {
        if (isDataInicio) {
          _dataInicio = dataFormatadaBR;
        } else {
          _dataFim = dataFormatadaBR;
        }
      });
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _localController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final administradoresAsync = ref.watch(administradoresProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        title: const Text('Novo Evento'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome do Evento',
                prefixIcon: Icon(Icons.event_note),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _localController,
              decoration: const InputDecoration(
                labelText: 'Local do Evento',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Campo Data de Início
            InkWell(
              onTap: () => _selecionarData(context, true),
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data de Início',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _dataInicio.isEmpty ? 'Selecione a data de início' : _dataInicio,
                  style: TextStyle(
                    fontSize: 16,
                    color: _dataInicio.isEmpty ? Colors.grey[600] : Colors.black87,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Campo Data de Término
            InkWell(
              onTap: () => _selecionarData(context, false),
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data de Término',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _dataFim.isEmpty ? 'Selecione a data de término' : _dataFim,
                  style: TextStyle(
                    fontSize: 16,
                    color: _dataFim.isEmpty ? Colors.grey[600] : Colors.black87,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // --- SELEÇÃO DE ADMINISTRADORES (opcional) ---
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Administradores (opcional)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Selecione quem, além de você, pode editar este evento e gerenciar suas barracas.',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            administradoresAsync.when(
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
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: administradores.map((Administrador a) {
                      final selecionado = _administradoresSelecionados.contains(a.id);
                      return CheckboxListTile(
                        dense: true,
                        title: Text(a.nome),
                        subtitle: Text(a.email),
                        value: selecionado,
                        onChanged: (marcado) {
                          setState(() {
                            if (marcado == true) {
                              _administradoresSelecionados.add(a.id);
                            } else {
                              _administradoresSelecionados.remove(a.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (_nomeController.text.isEmpty ||
                      _localController.text.isEmpty ||
                      _dataInicio.isEmpty ||
                      _dataFim.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Por favor, preencha todos os campos!'),
                      ),
                    );
                    return;
                  }

                  // Validação da sequência das datas no Frontend
                  final dtInicio = _parseDataBR(_dataInicio);
                  final dtFim = _parseDataBR(_dataFim);

                  if (dtFim.isBefore(dtInicio)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('A data de término não pode ser anterior à data de início!'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  final novoEvento = Evento(
                    id: 0,
                    nome: _nomeController.text.trim(),
                    local: _localController.text.trim(),
                    dataInicio: _converterParaISO(_dataInicio),
                    dataFim: _converterParaISO(_dataFim),
                    administradorIds: _administradoresSelecionados,
                  );

                  // Consome o provider atualizado que retorna o Map com sucesso e mensagem
                  final resultado = await ref
                      .read(eventosProvider.notifier)
                      .criarEvento(novoEvento);

                  if (context.mounted) {
                    final bool sucesso = resultado['sucesso'] ?? false;
                    final String mensagem = resultado['mensagem'] ?? 'Ocorreu um erro.';

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(mensagem),
                        backgroundColor: sucesso ? Colors.green : Colors.red,
                      ),
                    );

                    if (sucesso) {
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Text(
                  'Salvar Evento',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}