import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/evento_model.dart';
import '../providers/auth_provider.dart';
import 'painel_cliente_view.dart'; // reaproveita a MinhaCarteiraView

const String _baseUrl = 'http://127.0.0.1:8000';

class ClienteEntryView extends ConsumerStatefulWidget {
  final int eventoId;

  const ClienteEntryView({super.key, required this.eventoId});

  @override
  ConsumerState<ClienteEntryView> createState() => _ClienteEntryViewState();
}

class _ClienteEntryViewState extends ConsumerState<ClienteEntryView> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  bool _modoCadastro = false;
  bool _carregando = false;
  bool _carregandoEvento = true;
  String? _nomeEvento;
  String? _localEvento;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _buscarEvento();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _buscarEvento() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/eventos/${widget.eventoId}/basico'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _nomeEvento = data['nome'];
          _localEvento = data['local'];
          _carregandoEvento = false;
        });
      } else {
        setState(() {
          _erro = 'Evento não encontrado.';
          _carregandoEvento = false;
        });
      }
    } catch (e) {
      setState(() {
        _erro = 'Não foi possível conectar ao servidor.';
        _carregandoEvento = false;
      });
    }
  }

  Future<void> _entrarNaCarteira() async {
    // Depois de logado, cria/recupera a carteira e vai direto pra ela.
    final headers = {'Content-Type': 'application/json'};
    // (o token já foi salvo pelo AuthNotifier.login; MinhaCarteiraView usa o
    // provider que lê o token do SecureStorage sozinho)

    if (!mounted) return;

    final evento = Evento(
      id: widget.eventoId,
      nome: _nomeEvento ?? 'Evento',
      local: _localEvento ?? '',
      dataInicio: '',
      dataFim: '',
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MinhaCarteiraView(evento: evento)),
    );
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      if (_modoCadastro) {
        // 1. Cria a conta (perfil CLIENTE é forçado pelo backend)
        final response = await http.post(
          Uri.parse('$_baseUrl/auth/registrar'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'nome': _nomeController.text.trim(),
            'email': _emailController.text.trim(),
            'senha': _senhaController.text,
          }),
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          final body = jsonDecode(response.body);
          setState(() {
            _erro = body['detail'] ?? 'Erro ao criar conta.';
            _carregando = false;
          });
          return;
        }
      }

      // 2. Faz login (tanto no fluxo de cadastro quanto no de login)
      final sucesso = await ref.read(authProvider.notifier).login(
            _emailController.text.trim(),
            _senhaController.text,
          );

      setState(() => _carregando = false);

      if (!sucesso) {
        setState(() => _erro = 'E-mail ou senha incorretos.');
        return;
      }

      await _entrarNaCarteira();
    } catch (e) {
      setState(() {
        _carregando = false;
        _erro = 'Falha de conexão com o servidor.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregandoEvento) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_nomeEvento == null) {
      return Scaffold(
        body: Center(child: Text(_erro ?? 'Evento não encontrado.')),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    Icon(Icons.qr_code_2,
                        size: 64, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      _nomeEvento!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (_localEvento != null && _localEvento!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _localEvento!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    const SizedBox(height: 32),

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

                    if (_modoCadastro) ...[
                      TextFormField(
                        controller: _nomeController,
                        decoration: const InputDecoration(
                          labelText: 'Nome completo',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe o email';
                        if (!v.contains('@')) return 'Email inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _senhaController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Senha deve ter ao menos 6 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _carregando ? null : _submeter,
                        child: _carregando
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_modoCadastro ? 'Criar conta e entrar' : 'Entrar'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _carregando
                          ? null
                          : () => setState(() {
                                _modoCadastro = !_modoCadastro;
                                _erro = null;
                              }),
                      child: Text(
                        _modoCadastro
                            ? 'Já tenho conta — Entrar'
                            : 'Ainda não tenho conta — Cadastrar',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}