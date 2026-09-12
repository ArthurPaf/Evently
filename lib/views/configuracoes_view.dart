import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class ConfiguracoesView extends ConsumerWidget {
  const ConfiguracoesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isEscuro = themeMode == ThemeMode.dark;
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'APARÊNCIA',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
            ),
          ),
          SwitchListTile(
            secondary: Icon(isEscuro ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Modo escuro'),
            subtitle: const Text('Reduz o brilho da tela em ambientes escuros'),
            value: isEscuro,
            onChanged: (valor) {
              ref.read(themeProvider.notifier).alternar(valor);
            },
          ),
          const Divider(height: 32),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'CONTA',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(authState.nomeUsuario ?? '—'),
            subtitle: Text(authState.emailUsuario ?? ''),
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Perfil'),
            subtitle: Text(_formatarPerfil(authState.perfil)),
          ),
          const Divider(height: 32),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'SOBRE',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Evently'),
            subtitle: Text('Plataforma de gestão e automação de vendas internas em eventos'),
          ),
          const ListTile(
            leading: Icon(Icons.numbers_outlined),
            title: Text('Versão'),
            subtitle: Text('1.0.0'),
          ),
        ],
      ),
    );
  }

  String _formatarPerfil(String? perfil) {
    switch (perfil) {
      case 'organizador':
        return 'Organizador';
      case 'administrador':
        return 'Administrador';
      case 'vendedor':
        return 'Vendedor';
      case 'cliente':
        return 'Cliente';
      default:
        return '—';
    }
  }
}