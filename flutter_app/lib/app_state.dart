import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'core/pass_token.dart';
import 'models/user_profile.dart';
import 'services/backend_api.dart';
import 'services/biometric_service.dart';
import 'services/device_key_service.dart';

enum AppStage {
  loading,
  signedOut,
  verify,
  verifyFailed,
  accountLocked,
  backendUnreachable,
  pass,
}

class AppState extends ChangeNotifier {
  AppState({
    required this.api,
    BiometricService? biometrics,
    DeviceKeyService? keys,
    FlutterSecureStorage? storage,
  })  : biometrics = biometrics ?? BiometricService(),
        keys = keys ?? DeviceKeyService(),
        _storage = storage ?? const FlutterSecureStorage();

  final BackendApi api;
  final BiometricService biometrics;
  // Kept to preserve constructor compatibility. Phase 2 does not use device keys.
  final DeviceKeyService keys;
  final FlutterSecureStorage _storage;

  static const maxAttempts = 3;
  static const lockDuration = Duration(minutes: 15);
  static const unlockDuration = Duration(minutes: 2);

  static const _userKey = 'session.user';
  static const _failsKey = 'security.failedAttempts';
  static const _lockKey = 'security.lockedUntil';

  // Set using: flutter run --dart-define=QR_API_URL=https://your-backend.example
  // Android emulator development only. HTTPS is required for network deployment.
  static const String qrApiUrl = String.fromEnvironment(
    'QR_API_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  AppStage stage = AppStage.loading;
  UserProfile? user;
  int failedAttempts = 0;
  DateTime? lockedUntil;
  DateTime? unlockedUntil;
  String errorDetail = '';
  int _passSession = 0;

  int get triesLeft => maxAttempts - failedAttempts;
  bool get isLocked => lockedUntil != null && DateTime.now().isBefore(lockedUntil!);
  bool get isUnlocked => unlockedUntil != null && DateTime.now().isBefore(unlockedUntil!);

  void _go(AppStage next) {
    stage = next;
    notifyListeners();
  }

  Future<void> init() async {
    final rawUser = await _storage.read(key: _userKey);
    if (rawUser != null) {
      user = UserProfile.fromJson(jsonDecode(rawUser) as Map<String, dynamic>);
    }
    failedAttempts = int.tryParse(await _storage.read(key: _failsKey) ?? '') ?? 0;
    final lock = int.tryParse(await _storage.read(key: _lockKey) ?? '');
    lockedUntil = lock == null ? null : DateTime.fromMillisecondsSinceEpoch(lock);
    // Do not trust the locally cached profile as an authenticated Firebase session.
    if (FirebaseAuth.instance.currentUser == null) {
      user = null;
      await _storage.delete(key: _userKey);
    }
    _go(user == null ? AppStage.signedOut : (isLocked ? AppStage.accountLocked : AppStage.verify));
  }

  Future<EnrolmentResult> enrol({
    required String name,
    required String email,
    required String campusId,
    required String password,
    required UserRole role,
  }) => api.enrol(
        name: name,
        email: email,
        campusId: campusId,
        password: password,
        role: role,
      );

  Future<void> login(String identifier, String password) async {
    // BackendApi.login must sign into Firebase Authentication and return
    // a profile whose id is the Firebase Authentication UID.
    final profile = await api.login(identifier: identifier, password: password);
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null || firebaseUser.uid != profile.id) {
      throw BackendException('Firebase session or user identity mismatch.');
    }
    ++_passSession;
    unlockedUntil = null;
    user = profile;
    await _storage.write(key: _userKey, value: jsonEncode(profile.toJson()));
    _go(isLocked ? AppStage.accountLocked : AppStage.verify);
  }

  Future<void> logout() async {
    ++_passSession;
    await FirebaseAuth.instance.signOut();
    await _storage.delete(key: _userKey);
    // Remove old legacy credential left by the device-signed QR implementation.
    await _storage.delete(key: 'session.credential');
    user = null;
    unlockedUntil = null;
    _go(AppStage.signedOut);
  }

  Future<String?> verify() async {
    if (isLocked) {
      _go(AppStage.accountLocked);
      return null;
    }
    if (!biometrics.simulateFailureOnce && !await biometrics.isAvailable()) {
      return 'No Face ID or fingerprint is set up on this phone. Add one in Settings first.';
    }
    final ok = await biometrics.authenticate("Verify it's you to show your access pass");
    if (!ok) {
      await registerFailedAttempt();
      return null;
    }
    await _setFailedAttempts(0);
    if (FirebaseAuth.instance.currentUser == null) {
      _go(AppStage.signedOut);
      return 'Please sign in again.';
    }
    ++_passSession;
    unlockedUntil = DateTime.now().add(unlockDuration);
    _go(AppStage.pass);
    return null;
  }

  Future<void> registerFailedAttempt() async {
    await _setFailedAttempts(failedAttempts + 1);
    if (failedAttempts >= maxAttempts) {
      lockedUntil = DateTime.now().add(lockDuration);
      await _storage.write(key: _lockKey, value: lockedUntil!.millisecondsSinceEpoch.toString());
      await _setFailedAttempts(0);
      _go(AppStage.accountLocked);
    } else {
      _go(AppStage.verifyFailed);
    }
  }

  Future<void> _setFailedAttempts(int n) async {
    failedAttempts = n;
    await _storage.write(key: _failsKey, value: '$n');
  }

  Future<void> lockExpired() async {
    lockedUntil = null;
    await _storage.delete(key: _lockKey);
    _go(AppStage.verify);
  }

  void backToVerify() => _go(AppStage.verify);

  void lockPass() {
    ++_passSession;
    unlockedUntil = null;
    if (stage == AppStage.pass) _go(AppStage.verify);
  }

  Future<PassToken> generatePass({String roomId = 'LAB_A'}) async {
    if (!isUnlocked || stage != AppStage.pass || user == null) {
      throw BackendException("Pass is locked. Verify it's you first.");
    }
    final session = _passSession;
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null || firebaseUser.uid != user!.id) {
        throw BackendException('Firebase authentication session is missing or mismatched.');
      }
      final idToken = await firebaseUser.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw BackendException('Could not retrieve Firebase ID token.');
      }
      final uri = Uri.parse('${qrApiUrl.replaceAll(RegExp(r"/$"), "")}/qr/issue');
      if (uri.scheme != 'https' && !(uri.scheme == 'http' && uri.host == '10.0.2.2')) {
        throw BackendException('QR backend must use HTTPS outside Android emulator development.');
      }
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'room_id': roomId}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw BackendException('Not authorized to generate a QR pass (${response.statusCode}).');
      }
      if (response.statusCode != 200) {
        throw BackendException('QR backend returned HTTP ${response.statusCode}.');
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['token'] is! String) {
        throw BackendException('QR backend returned an invalid response.');
      }
      final pass = PassToken.fromBackendJwt(data['token'] as String);
      if (session != _passSession || !isUnlocked || stage != AppStage.pass) {
        throw BackendException('QR request invalidated by a locked session.');
      }
      return pass;
    } on SocketException catch (e) {
      errorDetail = 'Error: $e';
      _go(AppStage.backendUnreachable);
      throw BackendException('QR backend unreachable.');
    } on TimeoutException {
      errorDetail = 'QR backend request timed out.';
      _go(AppStage.backendUnreachable);
      throw BackendException('QR backend timed out.');
    } on http.ClientException catch (e) {
      errorDetail = 'Error: $e';
      _go(AppStage.backendUnreachable);
      throw BackendException('QR backend connection failed.');
    }
  }
}
