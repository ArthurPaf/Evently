import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../views/painel_organizador_view.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  void _fazerLogin() async {
    setState(() => _isLoading = true);
    
    try {
      bool sucesso = await _apiService.login(
        _emailController.text, 
        _passwordController.text
      );

      setState(() => _isLoading = false);

      if (sucesso) {
        // Agora navegando para a tela correta com MVC!
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => PainelOrganizadorView())
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email ou senha inválidos.'), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      // Se der erro de rede, de CORS ou servidor fora do ar, cai aqui!
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão com o servidor: $e'), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 400, // Limita a largura para ficar bonito na Web
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Evently', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Senha', border: OutlineInputBorder()),
              ),
              SizedBox(height: 24),
              _isLoading 
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _fazerLogin,
                    style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                    child: Text('ENTRAR'),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}