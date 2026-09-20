import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Keeps only the already-derived vault key in the operating system's secure
/// store. On Android its key is biometric/device-credential protected; on
/// Windows the store is scoped to the signed-in Windows user and Windows Hello
/// is requested before the key is read.
class DeviceKeyStore {
  static const _key = 'foraneo-vault-key-v2';
  static final _storage = FlutterSecureStorage(
    aOptions: AndroidOptions.biometric(
      enforceBiometrics: true,
      biometricPromptTitle: 'Desbloquear Foráneo',
      biometricPromptSubtitle: 'Usa biometría o el bloqueo del dispositivo',
    ),
  );
  static final _auth = LocalAuthentication();

  static Future<bool> canUse() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> save(List<int> rawKey) async {
    if (!await canUse()) return false;
    try {
      // Android enforces authentication on the secure-storage key itself.
      // This explicit prompt also gives Windows users a Windows Hello check.
      final accepted = await _auth.authenticate(
        localizedReason: 'Autoriza la biometría para desbloquear Foráneo',
        persistAcrossBackgrounding: true,
      );
      if (!accepted) return false;
      await _storage.write(key: _key, value: base64Encode(rawKey));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<int>?> read() async {
    try {
      final accepted = await _auth.authenticate(
        localizedReason: 'Desbloquea tu perfil de Foráneo',
        persistAcrossBackgrounding: true,
      );
      if (!accepted) return null;
      final value = await _storage.read(key: _key);
      return value == null ? null : base64Decode(value);
    } catch (_) {
      return null;
    }
  }

  static Future<void> remove() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // A removed or unavailable secure-store key needs no further action.
    }
  }
}
