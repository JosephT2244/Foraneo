import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Run on the dedicated Foraneo_QA emulator, never against personal app data.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.josepht2244.foraneo/home');
  testWidgets('Android native reminders and home widgets are registered', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Foráneo · verificación nativa')),
      ),
    );
    final initial = await channel.invokeMapMethod<String, dynamic>('getStatus');
    expect(initial?['widgetProviders'], 4);
    expect(initial?['notificationsEnabled'], isA<bool>());
    expect(initial?['widgetInstances'], isA<int>());
    const testId = 2147480000;
    try {
      await channel.invokeMethod('schedule', {
        'id': testId,
        'title': 'Prueba de Foráneo',
        'body': 'Recordatorio local de prueba',
        'at': DateTime.now()
            .add(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
      });
      final scheduled = await channel.invokeMapMethod<String, dynamic>(
        'getStatus',
      );
      expect(
        scheduled?['pendingReminders'],
        (initial?['pendingReminders'] as int) + 1,
      );
      final today = DateTime.now().toIso8601String().split('T').first;
      await channel.invokeMethod('updateWidget', {
        'shopping': 'Pasta · prueba',
        'urgent': 'Leche · prueba',
        'tasks': 'Verificar recordatorios',
        'meal': 'Pasta con tomate',
        'taskDays': {today: 'Verificar recordatorios'},
        'mealDays': {today: 'Pasta con tomate'},
      });
      // A denied notification permission is valid and must not crash.
      await channel.invokeMethod('notify', {
        'id': testId,
        'title': 'Foráneo',
        'body': 'Comprobación de notificación local',
      });
      // Opt-in only on the disposable QA emulator. The launcher confirmation
      // still needs acceptance; this never silently changes a personal home.
      const pinWidget = bool.fromEnvironment('FORANEO_NATIVE_QA_PIN_WIDGET');
      if (pinWidget) {
        expect(
          await channel.invokeMethod<bool>('pinWidget', {'type': 'summary'}),
          isTrue,
        );
      }
      // Optional pause for host-side `adb shell dumpsys notification` evidence.
      // Normal automated runs stay fast and do not depend on alarm batching.
      const holdSeconds = int.fromEnvironment('FORANEO_NATIVE_QA_HOLD_SECONDS');
      if (holdSeconds > 0) {
        await Future<void>.delayed(Duration(seconds: holdSeconds));
      }
    } finally {
      await channel.invokeMethod('cancel', {'id': testId});
      final cancelled = await channel.invokeMapMethod<String, dynamic>(
        'getStatus',
      );
      expect(cancelled?['pendingReminders'], initial?['pendingReminders']);
      await channel.invokeMethod('updateWidget', {
        'shopping': '',
        'urgent': '',
        'tasks': '',
        'meal': '',
        'taskDays': <String, String>{},
        'mealDays': <String, String>{},
      });
    }
  });
}
