@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application/theme/evently_theme.dart';
import 'package:flutter_application/screens/login_screen.dart';
import 'package:flutter_application/views/painel_organizador_view.dart';
import 'package:flutter_application/views/detalhes_evento_view.dart';
import 'package:flutter_application/views/dashboard_view.dart';
import 'package:flutter_application/providers/auth_provider.dart';
import 'package:flutter_application/providers/evento_provider.dart';
import 'package:flutter_application/providers/transacao_provider.dart';
import 'package:flutter_application/services/barraca_service.dart';
import 'package:flutter_application/models/evento_model.dart';

final evento = Evento(
  id: 1,
  nome: 'Festival de Cultura e Gastronomia',
  local: 'Parque da cidade',
  dataInicio: '2026-09-25',
  dataFim: '2026-09-27',
);

class TestAuth extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    isAuthenticated: true,
    perfil: 'organizador',
    nomeUsuario: 'Maria',
    token: 'test',
  );
}

class TestEventos extends EventosNotifier {
  @override
  Future<List<Evento>> build() async => [evento, evento, evento];
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1280, 800),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('Telas responsivas ${size.width} ${brightness.name}', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final pages = <Widget>[
          const LoginScreen(),
          const PainelOrganizadorView(),
          DetalhesEventoView(evento: evento),
          DashboardView(eventoId: 1, nomeEvento: evento.nome),
        ];
        for (final page in pages) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authProvider.overrideWith(TestAuth.new),
                eventosProvider.overrideWith(TestEventos.new),
                barracasProvider(1).overrideWith((ref) async => []),
                dashboardProvider(1).overrideWith(
                  (ref) async => {
                    'total_vendido': 12345.67,
                    'numero_transacoes': 320,
                    'produtos_mais_vendidos': [],
                    'vendas_por_barraca': [],
                    'vendas_por_periodo': [],
                    'vendas_por_vendedor': [],
                  },
                ),
              ],
              child: MaterialApp(
                theme: EventlyTheme.build(brightness),
                home: page,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${page.runtimeType} em $size',
          );
          if (page is DetalhesEventoView) {
            await tester.drag(
              find.byType(NestedScrollView),
              const Offset(0, -500),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
        }
      });
    }
  }
}
