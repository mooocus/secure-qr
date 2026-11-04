import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/jws.dart';

/// Stores the device's private signing key in the OS secure storage
/// (iOS Keychain / Android Keystore-encrypted storage).
///
/// The app only reads it after a successful biometric check (see AppState).
/// Future improvement: generate the key inside the Secure Enclave / StrongBox
/// with a biometric-bound access policy so even the app cannot read it raw.
class DeviceKeyService {
  DeviceKeyService({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'device.signingKey';
  final FlutterSecureStorage _storage;

  Future<EcKeyPair> createKey() async {
    final key = EcKeyPair.generate();
    await _storage.write(key: _keyName, value: jsonEncode(key.toStorage()));
    return key;
  }

  Future<EcKeyPair?> loadKey() async {
    final raw = await _storage.read(key: _keyName);
    return raw == null ? null : EcKeyPair.fromStorage(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> deleteKey() => _storage.delete(key: _keyName);
}
