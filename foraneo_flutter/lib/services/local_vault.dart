import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-device profile only. No server, account API or password recovery service.
class LocalVault {
  static const profileKey = 'foraneo_profile_v2';
  static const stateKey = 'foraneo_data_v2';
  static const legacyKey = 'foraneo_flutter_state_v1';
  final SharedPreferences preferences;
  SecretKey? _key;
  LocalVault(this.preferences);
  bool get hasProfile => preferences.containsKey(profileKey);
  bool get unlocked => !hasProfile || _key != null;
  String get username {
    try {
      return '${jsonDecode(preferences.getString(profileKey) ?? '{}')['username'] ?? ''}';
    } catch (_) {
      return '';
    }
  }

  Future<SecretKey> _derive(String password, List<int> salt) => Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 210000,
    bits: 256,
  ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  Future<void> createProfile(
    String username,
    String password,
    Map<String, dynamic> data,
  ) async {
    if (hasProfile) throw StateError('Ya existe un perfil local.');
    if (username.trim().length < 3 ||
        username.trim().length > 80 ||
        password.length < 10) {
      throw ArgumentError(
        'Usuario: 3 a 80 caracteres. Contraseña: al menos 10.',
      );
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    _key = await _derive(password, salt);
    final check = await _encrypt(utf8.encode('Foráneo:perfil:v2'));
    final encryptedData = await _encrypt(utf8.encode(jsonEncode(data)));
    // Persist the complete profile envelope first; its data is a recovery copy
    // if the next preference write is interrupted.
    final ok = await preferences.setString(
      profileKey,
      jsonEncode({
        'username': username.trim(),
        'salt': base64Encode(salt),
        'check': check,
        'recovery': encryptedData,
      }),
    );
    if (!ok) {
      _key = null;
      throw StateError('No se pudo guardar el perfil.');
    }
    if (!await preferences.setString(
      stateKey,
      jsonEncode({'encrypted': encryptedData}),
    )) {
      // The encrypted recovery envelope remains authoritative. Remove the old
      // guest data instead of leaving an unencrypted duplicate behind.
      await preferences.remove(stateKey);
      throw StateError(
        'Perfil creado. No se completó el guardado. Inicia sesión para recuperarlo.',
      );
    }
    if (!await preferences.remove(legacyKey)) {
      throw StateError('No se pudo limpiar el almacenamiento anterior.');
    }
    await preferences.remove('foraneo_guest_v2');
  }

  Future<bool> unlock(String username, String password) async {
    try {
      final profile = jsonDecode(preferences.getString(profileKey)!);
      if (username.trim().toLowerCase() !=
          '${profile['username']}'.toLowerCase()) {
        return false;
      }
      _key = await _derive(password, base64Decode(profile['salt']));
      final checked = utf8.decode(
        await _decrypt(Map<String, dynamic>.from(profile['check'])),
      );
      if (checked != 'Foráneo:perfil:v2') {
        _key = null;
        return false;
      }
      return true;
    } catch (_) {
      _key = null;
      return false;
    }
  }

  void lock() {
    _key = null;
  }

  Future<Map<String, dynamic>?> read() async {
    if (!unlocked) {
      throw StateError('Desbloquea el perfil para abrir los datos.');
    }
    final value = preferences.getString(stateKey);
    if (value == null) {
      if (hasProfile) {
        final profile = jsonDecode(preferences.getString(profileKey)!);
        return Map<String, dynamic>.from(
          jsonDecode(
            utf8.decode(
              await _decrypt(Map<String, dynamic>.from(profile['recovery'])),
            ),
          ),
        );
      }
      final legacy = preferences.getString(legacyKey);
      return legacy == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(legacy));
    }
    final decoded = Map<String, dynamic>.from(jsonDecode(value));
    if (hasProfile) {
      if (decoded['encrypted'] == null) {
        final profile = jsonDecode(preferences.getString(profileKey)!);
        return Map<String, dynamic>.from(
          jsonDecode(
            utf8.decode(
              await _decrypt(Map<String, dynamic>.from(profile['recovery'])),
            ),
          ),
        );
      }
      return Map<String, dynamic>.from(
        jsonDecode(
          utf8.decode(
            await _decrypt(Map<String, dynamic>.from(decoded['encrypted'])),
          ),
        ),
      );
    }
    return Map<String, dynamic>.from(decoded['data'] ?? decoded);
  }

  Future<void> save(Map<String, dynamic> data) async {
    if (!unlocked) throw StateError('Desbloquea el perfil para guardar.');
    final envelope = hasProfile
        ? {'encrypted': await _encrypt(utf8.encode(jsonEncode(data)))}
        : {'data': data};
    if (!await preferences.setString(stateKey, jsonEncode(envelope))) {
      throw StateError('No hay espacio para guardar tus cambios.');
    }
  }

  Future<Map<String, dynamic>> _encrypt(List<int> bytes) async {
    final box = await AesGcm.with256bits().encrypt(bytes, secretKey: _key!);
    return {
      'nonce': base64Encode(box.nonce),
      'cipher': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
  }

  Future<List<int>> _decrypt(Map<String, dynamic> map) =>
      AesGcm.with256bits().decrypt(
        SecretBox(
          base64Decode(map['cipher']),
          nonce: base64Decode(map['nonce']),
          mac: Mac(base64Decode(map['mac'])),
        ),
        secretKey: _key!,
      );
}
