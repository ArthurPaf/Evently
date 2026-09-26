import '../widgets/evently_scaffold.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String _baseUrl = 'http://127.0.0.1:8000';

class EsqueciSenhaView extends StatefulWidget {
  final int? eventoId; // presente quando aberto a partir da tela do cliente

  const EsqueciSenhaView({super.key, this.eventoId});

  @override
  State<EsqueciSenhaView> createState() => _EsqueciSenhaViewState();
}

class _EsqueciSenhaViewState extends State<EsqueciSenhaView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _carregando = false;
  bool _enviado = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _enviarSolicitacao() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      await http.post(
        Uri.parse('$_baseUrl/auth/esqueci-senha'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          if (widget.eventoId != null) 'evento_id': widget.eventoId,
        }),
      );

      // O backend sempre responde com a mesma mensagem genérica,
      // exista ou não o e-mail — então sempre mostramos sucesso aqui.
      setState(() {
        _carregando = false;
        _enviado = true;
      });
    } catch (e) {
      setState(() => _carregando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Falha de conexão com o servidor.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EventlyScaffold(
      maxWidth: 760,
      appBar: AppBar(title: const Text('Recuperar Senha')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _enviado
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.mark_email_read_outlined,
                        size: 64,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Se este e-mail estiver cadastrado, você vai receber um link de recuperação em instantes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Voltar'),
                      ),
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.lock_reset_outlined, size: 56),
                        const SizedBox(height: 12),
                        const Text(
                          'Informe o e-mail da sua conta. Vamos te enviar um link para redefinir a senha.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Informe o email';
                            }
                            if (!v.contains('@')) return 'Email inválido';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _carregando ? null : _enviarSolicitacao,
                            child: _carregando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Enviar link de recuperação'),
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
