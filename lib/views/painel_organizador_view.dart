import 'package:flutter/material.dart';
import '../controllers/evento_controller.dart';
import '../models/evento_model.dart';
import 'criar_evento_view.dart';
import 'detalhes_evento_view.dart';

class PainelOrganizadorView extends StatefulWidget {
  @override
  _PainelOrganizadorViewState createState() => _PainelOrganizadorViewState();
}

class _PainelOrganizadorViewState extends State<PainelOrganizadorView> {
  final EventoController _controller = EventoController();
  late Future<List<Evento>> _futuroEventos;

  @override
  void initState() {
    super.initState();
    _futuroEventos = _controller.buscarEventos();
  }

  void _atualizarLista() {
    setState(() {
      _futuroEventos = _controller.buscarEventos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Meus Eventos')),
      body: FutureBuilder<List<Evento>>(
        future: _futuroEventos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar eventos.'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Nenhum evento encontrado.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final evento = snapshot.data![index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(
                    evento.nome, 
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${evento.dataInicio} até ${evento.dataFim}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetalhesEventoView(evento: evento),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // O 'await' espera o usuário voltar da tela de criação
          final resultado = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CriarEventoView()),
          );

          // Se o resultado for 'true' (evento criado), atualiza a lista
          if (resultado == true) {
            _atualizarLista();
          }
        },
        child: Icon(Icons.add),
      ),
    );
  }
}