import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../screens/login_screen.dart';

const String _baseUrl = 'http://127.0.0.1:8000';

class RedefinirSenhaView extends StatefulWidget {
  final String token;

  const RedefinirSenhaView({super.key, required this.token});

  @override
  State<RedefinirSenhaView> createState() => _RedefinirSenhaViewState();
}

class _RedefinirSenhaViewState extends State<RedefinirSenhaView> {
  final _formKey = GlobalKey<FormState>();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  bool _carregando = false;
  bool _sucesso = false;
  String? _erro;

  @override
  void dispose() {
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _redefinir() async {
    if (!_formKey.currentState!.validate()) return;

    if (_senhaController.text != _confirmarSenhaController.text) {
      setState(() => _erro = 'As senhas não coincidem.');
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/redefinir-senha'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': widget.token,
          'nova_senha': _senhaController.text,
        }),
      );

      setState(() => _carregando = false);

      if (response.statusCode == 200) {
        setState(() => _sucesso = true);
      } else {
        final body = jsonDecode(response.body);
        setState(() => _erro = body['detail'] ?? 'Erro ao redefinir a senha.');
      }
    } catch (e) {
      setState(() {
        _carregando = false;
        _erro = 'Falha de conexão com o servidor.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Redefinir Senha'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _sucesso
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                      const SizedBox(height: 16),
                      const Text(
                        'Senha redefinida com sucesso!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          },
                          child: const Text('Ir para o login'),
                        ),
                      ),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.lock_outline, size: 56),
                        const SizedBox(height: 12),
                        const Text(
                          'Escolha sua nova senha.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        if (_erro != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(_erro!, style: const TextStyle(color: Colors.red)),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextFormField(
                          controller: _senhaController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Nova senha',
                            prefixIcon: Icon(Icons.lock_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.length < 6)
                              ? 'Senha deve ter ao menos 6 caracteres'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmarSenhaController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirmar nova senha',
                            prefixIcon: Icon(Icons.lock_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Confirme a senha' : null,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _carregando ? null : _redefinir,
                            child: _carregando
                                ? const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Redefinir Senha'),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}