import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:flutter_application/screens/login_screen.dart';
import 'package:flutter_application/views/cliente_entry_view.dart';
import 'package:flutter_application/providers/theme_provider.dart';

void main() {
  usePathUrlStrategy(); // remove o "#" da URL no Flutter Web (ex: /evento/3 em vez de /#/evento/3)
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Evently',
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      // Sem "home": a rota inicial é lida direto da URL do navegador.
      onGenerateRoute: (settings) {
        final uri = Uri.parse(settings.name ?? '/');

        // Link público do cliente: /evento/{id}
        // Este é o único "lugar" que o público do evento deve acessar —
        // não tem acesso a nenhuma outra tela do sistema interno.
        if (uri.pathSegments.length == 2 && uri.pathSegments[0] == 'evento') {
          final eventoId = int.tryParse(uri.pathSegments[1]);
          if (eventoId != null) {
            return MaterialPageRoute(
              builder: (_) => ClienteEntryView(eventoId: eventoId),
            );
          }
        }

        // Qualquer outra rota (incluindo "/") é o sistema interno da equipe
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      },
    );
  }
}