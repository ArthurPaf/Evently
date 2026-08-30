import 'package:flutter/material.dart';
import '../controllers/evento_controller.dart';

class CriarEventoView extends StatefulWidget {
  @override
  _CriarEventoViewState createState() => _CriarEventoViewState();
}

class _CriarEventoViewState extends State<CriarEventoView> {
  final _nomeController = TextEditingController();
  final _dataInicioController = TextEditingController();
  final _dataFimController = TextEditingController();
  final EventoController _controller = EventoController();
  
  bool _isLoading = false;

  void _salvarEvento() async {
    if (_nomeController.text.isEmpty || 
        _dataInicioController.text.isEmpty || 
        _dataFimController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preencha todos os campos!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      bool sucesso = await _controller.criarEvento(
        _nomeController.text,
        _dataInicioController.text, // Formato esperado pela API: AAAA-MM-DD
        _dataFimController.text,
      );

      setState(() => _isLoading = false);

      if (sucesso) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Evento criado com sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Volta para a tela anterior avisando que deu certo
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar evento: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Novo Evento')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nomeController,
              decoration: InputDecoration(labelText: 'Nome do Evento'),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _dataInicioController,
              decoration: InputDecoration(
                labelText: 'Data de Início (AAAA-MM-DD)',
                hintText: 'Ex: 2026-10-15'
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _dataFimController,
              decoration: InputDecoration(
                labelText: 'Data de Término (AAAA-MM-DD)',
                hintText: 'Ex: 2026-10-20'
              ),
            ),
            SizedBox(height: 30),
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _salvarEvento,
                    child: Text('Salvar Evento'),
                  ),
          ],
        ),
      ),
    );
  }
}