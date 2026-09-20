import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foraneo/services/native_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.josepht2244.foraneo/home');
  final calls = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'requestNotifications' ||
                  call.method == 'pinWidget'
              ? true
              : null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'Android uses persisted native alarms, cancellation and four widget types',
    () async {
      expect(await NativeServices.requestNotifications(), isTrue);
      await NativeServices.notify(
        id: 7,
        title: 'Despensa',
        body: 'Falta leche',
      );
      final at = DateTime.now().add(const Duration(hours: 2));
      await NativeServices.schedule(
        id: 8,
        title: 'Agenda',
        body: 'Pendiente',
        date: at,
      );
      await NativeServices.cancel(8);
      await NativeServices.updateWidget(
        shopping: 'Pasta',
        urgent: 'Leche',
        tasks: 'Lavar',
        meal: 'Sopa',
      );
      for (final type in ['summary', 'shopping', 'agenda', 'kitchen']) {
        expect(await NativeServices.pinWidget(type: type), isTrue);
      }
      expect(calls.first.method, 'requestNotifications');
      expect(
        calls.firstWhere((c) => c.method == 'schedule').arguments['at'],
        at.millisecondsSinceEpoch,
      );
      expect(calls.where((c) => c.method == 'pinWidget').length, 4);
      expect(
        calls.firstWhere((c) => c.method == 'updateWidget').arguments['urgent'],
        'Leche',
      );
    },
  );
  test(
    'Past reminders do not schedule and unsupported widgets report false',
    () async {
      await NativeServices.schedule(
        id: 1,
        title: 'Past',
        body: '',
        date: DateTime(2020),
      );
      expect(calls, isEmpty);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await NativeServices.pinWidget(), isFalse);
    },
  );
  test('Revoked permission does not cause an app crash', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'DENIED'),
        );
    expect(await NativeServices.requestNotifications(), isFalse);
    await NativeServices.notify(id: 1, title: 'Test', body: 'Test');
  });
}
