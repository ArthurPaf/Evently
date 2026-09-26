import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/theme/evently_theme.dart';
import 'package:flutter_application/widgets/evently_scaffold.dart';

void main() {
  for (final width in [320.0, 390.0, 1280.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('Layout e formulário $width ${brightness.name}', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: EventlyTheme.build(brightness),
            home: EventlyScaffold(
              body: EventlyAuthLayout(
                title: 'Seu evento.\nTudo conectado.',
                description: 'Organize sua equipe e acompanhe suas vendas.',
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const TextField(
                        decoration: InputDecoration(labelText: 'E-mail'),
                      ),
                      const SizedBox(height: 16),
                      const TextField(
                        decoration: InputDecoration(labelText: 'Senha'),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Entrar'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text('Seu evento.\nTudo conectado.'),
          width >= 850 ? findsOneWidget : findsNothing,
        );
        await tester.enterText(
          find.byType(TextField).first,
          'teste@example.com',
        );
        expect(find.text('teste@example.com'), findsOneWidget);
        expect(
          tester.getSize(find.byType(ElevatedButton)).height,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester.getSize(find.byType(EventlyAuthLayout)).width,
          lessThanOrEqualTo(1180),
        );
      });
    }
  }
}
