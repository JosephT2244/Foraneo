import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_notifier/local_notifier.dart';

/// Android alarms/widgets and desktop toasts. Never calls a network service.
class NativeServices {
  static const _channel = MethodChannel('com.josepht2244.foraneo/home');
  static final Map<int, Timer> _desktopTimers = {};
  static bool _desktopReady = false;
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  static Future<bool> requestNotifications() async {
    try {
      if (isAndroid) {
        return await _channel.invokeMethod<bool>('requestNotifications') ??
            false;
      }
      if (_isDesktop) {
        await localNotifier.setup(
          appName: 'Foráneo',
          shortcutPolicy: ShortcutPolicy.requireCreate,
        );
        _desktopReady = true;
        return true;
      }
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
    return false;
  }

  static Future<void> notify({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      if (isAndroid) {
        await _channel.invokeMethod('notify', {
          'id': id,
          'title': title,
          'body': body,
        });
      } else if (_isDesktop && _desktopReady) {
        await LocalNotification(
          identifier: 'foraneo-$id',
          title: title,
          body: body,
        ).show();
      }
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  /// Android persists alarms across app close/reboot; desktop requires app open.
  static Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime date,
  }) async {
    if (!date.isAfter(DateTime.now())) return;
    try {
      if (isAndroid) {
        await _channel.invokeMethod('schedule', {
          'id': id,
          'title': title,
          'body': body,
          'at': date.millisecondsSinceEpoch,
        });
      } else if (_isDesktop) {
        _desktopTimers.remove(id)?.cancel();
        _desktopTimers[id] = Timer(date.difference(DateTime.now()), () {
          _desktopTimers.remove(id);
          unawaited(notify(id: id, title: title, body: body));
        });
      }
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> cancel(int id) async {
    _desktopTimers.remove(id)?.cancel();
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('cancel', {'id': id});
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  static Future<void> updateWidget({
    required String shopping,
    required String urgent,
    required String tasks,
    required String meal,
    Map<String, String> taskDays = const {},
    Map<String, String> mealDays = const {},
  }) async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('updateWidget', {
        'shopping': shopping,
        'urgent': urgent,
        'tasks': tasks,
        'meal': meal,
        'taskDays': taskDays,
        'mealDays': mealDays,
      });
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  static Future<bool> pinWidget({String type = 'summary'}) async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('pinWidget', {'type': type}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> openNotificationSettings() async {
    if (!isAndroid) return;
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  static Future<String?> takeLaunchSection() async {
    if (!isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('takeLaunchSection');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
