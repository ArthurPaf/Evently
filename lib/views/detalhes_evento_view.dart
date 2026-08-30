import 'package:flutter/material.dart';
import '../models/evento_model.dart';
import '../controllers/barraca_controller.dart';

class DetalhesEventoView extends StatefulWidget {
  final Evento evento;

  DetalhesEventoView({required this.evento});

  @override
  _DetalhesEventoViewState createState() => _DetalhesEventoViewState();
}

class _DetalhesEventoViewState extends State<DetalhesEventoView> {
  final BarracaController _barracaController = BarracaController();
  List<dynamic> barracas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarBarracas();
  }

  Future<void> _carregarBarracas() async {
    setState(() => _isLoading = true);
    final lista = await _barracaController.listarBarracas(widget.evento.id);
    
    if (mounted) {
      setState(() {
        barracas = lista;
        _isLoading = false;
      });
    }
  }

  void _abrirModalNovaBarraca() {
    final _nomeController = TextEditingController();
    final _tipoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
          top: 16, left: 16, right: 16
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nova Barraca', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(
              controller: _nomeController, 
              decoration: InputDecoration(labelText: 'Nome da Barraca'),
            ),
            TextField(
              controller: _tipoController, 
              decoration: InputDecoration(labelText: 'Tipo (ex: Comida, Bebida)'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_nomeController.text.trim().isNotEmpty) {
                  // Guardamos o messenger antes do await para evitar erros de contexto
                  final messenger = ScaffoldMessenger.of(context);
                  
                  bool sucesso = await _barracaController.criarBarraca(
                    widget.evento.id,
                    _nomeController.text.trim(),
                    _tipoController.text.trim(),
                  );

                  if (sucesso) {
                    Navigator.pop(modalContext); // Fecha o modal
                    await _carregarBarracas();   // Atualiza a lista da tela
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Erro ao salvar no banco!'), 
                        backgroundColor: Colors.red
                      ),
                    );
                  }
                }
              },
              child: Text('Salvar no Banco'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.evento.nome)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Período: ${widget.evento.dataInicio} até ${widget.evento.dataFim}', 
              style: TextStyle(color: Colors.grey[700]),
            ),
            Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Barracas do Evento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _abrirModalNovaBarraca,
                  icon: Icon(Icons.add),
                  label: Text('Barraca'),
                ),
              ],
            ),
            SizedBox(height: 10),
            Expanded(
              child: _isLoading 
                ? Center(child: CircularProgressIndicator())
                : barracas.isEmpty
                  ? Center(child: Text('Nenhuma barraca cadastrada ainda.'))
                  : RefreshIndicator(
                      onRefresh: _carregarBarracas,
                      child: ListView.builder(
                        itemCount: barracas.length,
                        itemBuilder: (context, index) {
                          final item = barracas[index];

                          // Trata se o retorno for Map ou Objeto (Model)
                          final String nome = item is Map ? (item['nome'] ?? '') : (item.nome ?? '');
                          final String tipo = item is Map ? (item['tipo'] ?? '') : (item.tipo ?? '');

                          return Card(
                            child: ListTile(
                              leading: Icon(Icons.store),
                              title: Text(nome.isEmpty ? 'Sem Nome' : nome),
                              subtitle: Text(tipo.isEmpty ? 'Sem Tipo' : tipo),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}