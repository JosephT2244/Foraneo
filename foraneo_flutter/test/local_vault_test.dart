import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:foraneo/services/local_vault.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Profile encrypts guest/legacy data, preserves empty lists, validates password',
    () async {
      final data = {
        'products': [],
        'todos': [],
        'recipes': [],
        'private': 'secreto-de-prueba',
      };
      SharedPreferences.setMockInitialValues({
        LocalVault.legacyKey: jsonEncode(data),
        LocalVault.stateKey: jsonEncode({'data': data}),
        'foraneo_guest_v2': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final vault = LocalVault(prefs);
      await vault.createProfile('Joseph', 'MiClaveSegura2026!', data);
      expect(prefs.containsKey(LocalVault.legacyKey), isFalse);
      expect(prefs.containsKey('foraneo_guest_v2'), isFalse);
      expect(
        prefs.getString(LocalVault.stateKey),
        isNot(contains('secreto-de-prueba')),
      );
      expect(
        prefs.getString(LocalVault.profileKey),
        isNot(contains('MiClaveSegura2026!')),
      );
      expect((await vault.read())!['products'], isEmpty);
      vault.lock();
      await expectLater(vault.read(), throwsStateError);
      expect(await vault.unlock('Joseph', 'contraseña-equivocada'), isFalse);
      expect(await vault.unlock('joseph', 'MiClaveSegura2026!'), isTrue);
      expect((await vault.read())!['private'], 'secreto-de-prueba');
      await vault.save({'products': [], 'todos': [], 'recipes': []});
      expect((await vault.read())!['products'], isEmpty);
    },
  );
  test(
    'Short passwords are rejected without modifying existing guest data',
    () async {
      SharedPreferences.setMockInitialValues({
        LocalVault.stateKey: jsonEncode({
          'data': {'products': []},
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final vault = LocalVault(prefs);
      await expectLater(
        vault.createProfile('Joseph', 'short', {'products': []}),
        throwsArgumentError,
      );
      expect(vault.hasProfile, isFalse);
      expect((await vault.read())!['products'], isEmpty);
    },
  );
  test('Six-digit PIN unlocks the encrypted local profile', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final vault = LocalVault(prefs);
    await vault.createProfile('Joseph', 'MiClaveSegura2026!', {
      'private': 'dato-protegido',
    });
    await vault.setPin('123456');
    expect(vault.hasPin, isTrue);
    vault.lock();
    expect(await vault.unlockWithPin('Joseph', '123455'), isFalse);
    expect(await vault.unlockWithPin('joseph', '123456'), isTrue);
    expect((await vault.read())!['private'], 'dato-protegido');
  });
}
