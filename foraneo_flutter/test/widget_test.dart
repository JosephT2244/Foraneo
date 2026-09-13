import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:foraneo/main.dart';

void main() {
  testWidgets('Foráneo opens its home dashboard', (tester) async {
    await tester.pumpWidget(const ForaneoApp());

    expect(find.text('Hola, foráneo'), findsOneWidget);
    expect(find.text('Urgentes'), findsOneWidget);
  });

  test('price rules protect the configured margins', () {
    expect(decidePrice(20, 18).title, 'Compra autorizada');
    expect(decidePrice(20, 22).title, 'No lo compres');
    expect(decidePrice(150, 127).title, '¡Cómpralo!');
    expect(decidePrice(800, 820).title, 'No lo compres');
    expect(decidePrice(2500, 2520).title, 'Compra autorizada');
  });

  testWidgets('Foráneo fits its key screens on a phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ForaneoApp());

    for (final destination in ['Inventario', 'Compras', 'Cocina IA', 'Agenda']) {
      await tester.tap(find.text(destination).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
