import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foraneo/main.dart';
import 'package:foraneo/editors.dart';
import 'package:foraneo/services/local_vault.dart';
import 'package:foraneo/services/offline_recipes.dart';

Map<String, dynamic> emptyState() => {
  'version': 2,
  'products': [],
  'todos': [],
  'recipes': [],
  'meals': <String, String>{},
  'favorites': [],
  'settings': {
    'theme': 'system',
    'notifications': false,
    'widgetSharing': false,
  },
};

Future<void> openApp(
  WidgetTester tester, {
  Map<String, dynamic>? state,
  bool guest = true,
}) async {
  SharedPreferences.setMockInitialValues({
    if (guest) 'foraneo_guest_v2': true,
    if (state != null) LocalVault.stateKey: jsonEncode({'data': state}),
  });
  await tester.runAsync(() => OfflineRecipes.load());
  await tester.pumpWidget(const ForaneoApp());
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 120)),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.josepht2244.foraneo/home'),
          (_) async => null,
        );
  });
  testWidgets(
    'First launch offers real local profile or guest, without network',
    (tester) async {
      await openApp(tester, guest: false);
      expect(find.text('Crear perfil local'), findsOneWidget);
      expect(find.text('Continuar sin cuenta'), findsOneWidget);
      await tester.ensureVisible(find.text('Continuar sin cuenta'));
      await tester.tap(find.text('Continuar sin cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('Hola, foráneo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Empty saved collections remain empty; all phone pages and dark settings fit',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await openApp(tester, state: emptyState());
      expect(find.text('Hola, foráneo'), findsOneWidget);
      expect(find.text('Pasta'), findsNothing);
      for (final destination in ['Despensa', 'Compras', 'Cocina', 'Agenda']) {
        await tester.tap(
          find.widgetWithText(NavigationDestination, destination),
        );
        if (destination == 'Cocina') {
          await tester.pump(const Duration(seconds: 1));
          await tester.pump();
        } else {
          await tester.pumpAndSettle();
        }
        expect(
          tester.takeException(),
          isNull,
          reason: '$destination must fit on 360 px',
        );
      }
      await tester.tap(find.byTooltip('Ajustes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oscuro'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Ajustes de tu hogar.'))).brightness,
        Brightness.dark,
      );
      await tester.ensureVisible(find.text('by Joseph Ubaldo Trejo Hernandez'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Phone product CRUD saves decimal-comma stock and deletion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openApp(tester, state: emptyState());
    await tester.tap(find.widgetWithText(NavigationDestination, 'Despensa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir producto'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Mi pasta');
    await tester.enterText(fields.at(3), '20,50');
    await tester.enterText(fields.at(4), '2,0');
    await tester.enterText(fields.at(5), '1,0');
    await tester.tap(find.text('Guardar producto'));
    await tester.pumpAndSettle();
    expect(find.text('Mi pasta'), findsOneWidget);
    expect(find.text('2 paquetes en casa'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byTooltip('Opciones de Mi pasta'));
    await tester.tap(find.byTooltip('Opciones de Mi pasta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(find.text('Mi pasta'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    final saved = jsonDecode(prefs.getString(LocalVault.stateKey)!)['data'];
    expect(saved['products'], isEmpty);
  });
  testWidgets(
    'Detailed recipe displays ingredients, tools and numbered preparation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await openApp(tester, state: emptyState());
      await tester.tap(find.widgetWithText(NavigationDestination, 'Cocina'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.ensureVisible(find.text('Ver paso a paso').first);
      await tester.tap(find.text('Ver paso a paso').first);
      await tester.pumpAndSettle();
      expect(find.text('Todos los ingredientes'), findsOneWidget);
      expect(find.text('Preparación detallada'), findsOneWidget);
      expect(find.text('PASO 1'), findsOneWidget);
      expect(find.textContaining('Utensilios:'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Cerrar receta'));
      await tester.pumpAndSettle();
    },
  );
  test('price margins and package normalization use exact band boundaries', () {
    for (final band in [
      (40.0, .10),
      (100.0, .08),
      (200.0, .04),
      (500.0, .03),
      (1000.0, .02),
      (2000.0, .01),
    ]) {
      expect(
        decidePrice(band.$1, band.$1 * (1 + band.$2)).title,
        'No lo compres',
      );
      expect(
        decidePrice(band.$1, band.$1 * (band.$1 <= 200 ? .85 : .90)).title,
        '¡Cómpralo!',
      );
    }
    expect(decidePrice(20, 21).title, 'Compra autorizada');
    expect(decidePrice(0, 10).title, 'Agrega ambos precios');
    expect(
      comparablePrice(
        referenceAmount: 250,
        referenceUnit: 'g',
        offeredAmount: .5,
        offeredUnit: 'kg',
        offeredPrice: 40,
      ),
      20,
    );
    expect(
      comparablePrice(
        referenceAmount: 250,
        referenceUnit: 'g',
        offeredAmount: 1,
        offeredUnit: 'L',
        offeredPrice: 40,
      ),
      isNull,
    );
    expect(parseWholeNumber('2,0'), 2);
    expect(positiveNumber('2,5', integer: true), isNotNull);
  });
}
