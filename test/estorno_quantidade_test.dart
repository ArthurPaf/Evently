import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/models/transacao_model.dart';
import 'package:flutter_application/providers/transacao_provider.dart';
import 'package:flutter_application/theme/evently_theme.dart';
import 'package:flutter_application/views/historico_vendas_view.dart';

class FakeEstornoService extends TransacaoService {
  int chamadas = 0;
  List<Map<String, int>>? itensEnviados;
  Completer<Map<String, dynamic>>? pendente;

  @override
  Future<Map<String, dynamic>> estornarVenda(
    int transacaoId, {
    List<Map<String, int>>? itens,
  }) async {
    chamadas++;
    itensEnviados = itens;
    return pendente?.future ?? {'sucesso': true};
  }
}

final venda = Transacao(
  id: 7,
  tipo: 'venda',
  valorTotal: 34,
  valorEstornado: 8,
  dataHora: DateTime(2026, 10, 10, 14),
  nomeCliente: 'Cliente de teste',
  itens: [
    ItemVenda(
      id: 11,
      produtoId: 1,
      nomeProduto: 'Pastel',
      quantidade: 3,
      quantidadeEstornada: 1,
      precoUnitario: 8,
    ),
    ItemVenda(
      id: 12,
      produtoId: 2,
      nomeProduto: 'Suco',
      quantidade: 2,
      precoUnitario: 5,
    ),
  ],
);

Future<void> abrir(
  WidgetTester tester,
  FakeEstornoService service,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transacaoServiceProvider.overrideWithValue(service),
        vendasDaBarracaProvider(1).overrideWith((ref) async => [venda]),
      ],
      child: MaterialApp(
        theme: EventlyTheme.build(Brightness.dark),
        home: const HistoricoVendasView(barracaId: 1, nomeBarraca: 'Comidas'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Estornar'));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  for (final size in [const Size(320, 640), const Size(1280, 800)]) {
    testWidgets(
      'Estorno parcial envia apenas quantidades escolhidas em $size',
      (tester) async {
        final service = FakeEstornoService();
        await abrir(tester, service, size);
        final campo = find.byType(TextFormField).first;
        await tester.ensureVisible(campo);
        await tester.enterText(campo, '1');
        await tester.ensureVisible(find.text('Estornar quantidade'));
        await tester.tap(find.text('Estornar quantidade'));
        await tester.pumpAndSettle();
        expect(service.itensEnviados, [
          {'item_id': 11, 'quantidade': 1},
        ]);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Impede zero itens e quantidade acima do restante', (
    tester,
  ) async {
    final service = FakeEstornoService();
    await abrir(tester, service, const Size(390, 844));
    await tester.tap(find.text('Estornar quantidade'));
    await tester.pumpAndSettle();
    expect(service.chamadas, 0);
    expect(
      find.text('Informe a quantidade de pelo menos um produto.'),
      findsOneWidget,
    );
    final campo = find.byType(TextFormField).first;
    await tester.ensureVisible(campo);
    await tester.enterText(
      campo,
      '3',
    ); // Foram 3 comprados, mas 1 já foi estornado.
    await tester.tap(find.text('Estornar quantidade'));
    await tester.pumpAndSettle();
    expect(find.text('Informe de 0 a 2 unidades.'), findsOneWidget);
    expect(service.chamadas, 0);
  });

  testWidgets(
    'Estornar tudo ignora seleção parcial e bloqueia envio duplicado',
    (tester) async {
      final service = FakeEstornoService();
      service.pendente = Completer<Map<String, dynamic>>();
      await abrir(tester, service, const Size(390, 844));
      await tester.tap(find.text('Estornar tudo'));
      await tester.pump();
      await tester.tap(find.text('Estornar tudo'));
      await tester.pump();
      expect(service.chamadas, 1);
      expect(service.itensEnviados, isNull);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancelar'))
            .onPressed,
        isNull,
      );
      service.pendente!.complete({'sucesso': true});
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
