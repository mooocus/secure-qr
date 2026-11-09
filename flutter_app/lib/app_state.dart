
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'core/pass_token.dart';
import 'models/user_profile.dart';
import 'services/backend_api.dart';
import 'services/biometric_service.dart';
import 'services/device_key_service.dart';

// ==================================================
// APPLICATION STAGES
// ==================================================

enum AppStage {
  loading,
  signedOut,
  verify,
  verifyFailed,
  accountLocked,
  backendUnreachable,
  pass,
}

// ==================================================
// APPLICATION STATE
// ==================================================

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
  final DeviceKeyService keys;
  final FlutterSecureStorage _storage;

  // ==================================================
  // SECURITY CONFIGURATION
  // ==================================================

  static const int maxAttempts = 3;

  static const Duration lockDuration =
      Duration(minutes: 15);

  static const Duration unlockDuration =
      Duration(minutes: 2);

  static const Duration requestTimeout =
      Duration(seconds: 10);

  // ==================================================
  // SECURE STORAGE KEYS
  // ==================================================

  static const String _userKey =
      'session.user';

  static const String _failsKey =
      'security.failedAttempts';

  static const String _lockKey =
      'security.lockedUntil';

  // ==================================================
  // FASTAPI BACKEND CONFIGURATION
  // ==================================================

  /// For Microsoft Edge development:
  ///
  /// http://127.0.0.1:8000
  ///
  /// For Android emulator development:
  ///
  /// http://10.0.2.2:8000
  ///
  /// For production:
  ///
  /// https://your-secure-backend-domain
  ///
  /// Set using:
  /// --dart-define=QR_API_URL=...

  static const String qrApiUrl =
      String.fromEnvironment(
    'QR_API_URL',
    defaultValue: 'https://invalid.example',
  );

  // ==================================================
  // DEVELOPMENT-ONLY BIOMETRIC BYPASS
  // ==================================================

  static const bool allowDemoBypass =
      kDebugMode &&
      bool.fromEnvironment(
        'ENABLE_BIOMETRIC_TEST_BYPASS',
        defaultValue: false,
      );

  // ==================================================
  // APPLICATION STATE VARIABLES
  // ==================================================

  AppStage stage = AppStage.loading;

  UserProfile? user;

  int failedAttempts = 0;

  DateTime? lockedUntil;

  DateTime? unlockedUntil;

  String errorDetail = '';

  int _passSession = 0;

  // ==================================================
  // STATE GETTERS
  // ==================================================

  int get triesLeft =>
      (maxAttempts - failedAttempts).clamp(
        0,
        maxAttempts,
      );

  bool get isLocked =>
      lockedUntil != null &&
      DateTime.now().isBefore(lockedUntil!);

  bool get isUnlocked =>
      unlockedUntil != null &&
      DateTime.now().isBefore(unlockedUntil!);

  // ==================================================
  // NAVIGATION
  // ==================================================

  void _go(AppStage next) {
    stage = next;
    notifyListeners();
  }

  // ==================================================
  // INITIALIZE APPLICATION
  // ==================================================

  Future<void> init() async {
    final rawUser = await _storage.read(
      key: _userKey,
    );

    final firebaseUser =
        FirebaseAuth.instance.currentUser;

    user = null;

    if (rawUser != null && firebaseUser != null) {
      try {
        final profile = UserProfile.fromJson(
          jsonDecode(rawUser)
              as Map<String, dynamic>,
        );

        // A cached profile must belong to the
        // currently authenticated Firebase user.
        if (profile.id == firebaseUser.uid) {
          user = profile;
        }
      } catch (e) {
        debugPrint(
          'Unable to restore cached profile: $e',
        );
      }
    }

    // Clear stale local profile information.
    if (user == null) {
      await _storage.delete(
        key: _userKey,
      );
    }

    failedAttempts = int.tryParse(
          await _storage.read(
                key: _failsKey,
              ) ??
              '',
        ) ??
        0;

    final lock = int.tryParse(
      await _storage.read(
            key: _lockKey,
          ) ??
          '',
    );

    lockedUntil = lock == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            lock,
          );

    unlockedUntil = null;

    ++_passSession;

    // A cached profile is not proof of current
    // server-side approval. FastAPI must check
    // account status before issuing a QR.
    _go(
      user == null
          ? AppStage.signedOut
          : isLocked
              ? AppStage.accountLocked
              : AppStage.verify,
    );
  }

  // ==================================================
  // USER REGISTRATION
  // ==================================================

  Future<EnrolmentResult> enrol({
    required String name,
    required String email,
    required String campusId,
    required String password,
    required UserRole role,
  }) {
    return api.enrol(
      name: name,
      email: email,
      campusId: campusId,
      password: password,
      role: role,
    );
  }

  // ==================================================
  // USER LOGIN
  // ==================================================

  Future<void> login(
    String identifier,
    String password,
  ) async {
    // FirebaseBackendApi.login() authenticates
    // the user and checks their approval status.
    final profile = await api.login(
      identifier: identifier,
      password: password,
    );

    final firebaseUser =
        FirebaseAuth.instance.currentUser;

    if (firebaseUser == null ||
        firebaseUser.uid != profile.id) {
      throw BackendException(
        'Firebase session or user identity mismatch.',
      );
    }

    ++_passSession;

    unlockedUntil = null;

    user = profile;

    errorDetail = '';

    await _storage.write(
      key: _userKey,
      value: jsonEncode(
        profile.toJson(),
      ),
    );

    _go(
      isLocked
          ? AppStage.accountLocked
          : AppStage.verify,
    );
  }

  // ==================================================
  // USER LOGOUT
  // ==================================================

  Future<void> logout() async {
    ++_passSession;

    await FirebaseAuth.instance.signOut();

    await _storage.delete(
      key: _userKey,
    );

    // Remove legacy credential from the
    // previous device-signed QR implementation.
    await _storage.delete(
      key: 'session.credential',
    );

    user = null;

    unlockedUntil = null;

    errorDetail = '';

    _go(AppStage.signedOut);
  }

  // ==================================================
  // BIOMETRIC VERIFICATION
  // ==================================================

  Future<String?> verify() async {
    if (isLocked) {
      _go(AppStage.accountLocked);
      return null;
    }

    if (!biometrics.simulateFailureOnce &&
        !await biometrics.isAvailable()) {
      return 'No Face ID or fingerprint is set up '
          'on this device. Add one in Settings first.';
    }

    final ok = await biometrics.authenticate(
      "Verify it's you to show your access pass",
    );

    if (!ok) {
      await registerFailedAttempt();
      return null;
    }

    await _setFailedAttempts(0);

    final firebaseUser =
        FirebaseAuth.instance.currentUser;

    if (firebaseUser == null ||
        user == null ||
        firebaseUser.uid != user!.id) {
      ++_passSession;
      unlockedUntil = null;
      _go(AppStage.signedOut);

      return 'Please sign in again.';
    }

    ++_passSession;

    unlockedUntil = DateTime.now().add(
      unlockDuration,
    );

    _go(AppStage.pass);

    return null;
  }

  // ==================================================
  // DEVELOPMENT-ONLY BIOMETRIC BYPASS
  // ==================================================

  Future<void> bypassBiometricsForTesting() async {
    if (!allowDemoBypass) {
      throw StateError(
        'Biometric bypass is disabled.',
      );
    }

    if (stage != AppStage.verify) {
      throw StateError(
        'Biometric bypass is unavailable here.',
      );
    }

    if (user == null || isLocked) {
      throw StateError(
        'A valid unlocked user session is required.',
      );
    }

    // The Firebase identity must match the
    // locally loaded user profile.
    final firebaseUser =
        FirebaseAuth.instance.currentUser;

    if (firebaseUser == null ||
        firebaseUser.uid != user!.id) {
      throw BackendException(
        'Firebase authentication session is missing.',
      );
    }

    ++_passSession;

    unlockedUntil = DateTime.now().add(
      unlockDuration,
    );

    debugPrint(
      '[DEV ONLY] Biometric verification bypassed.',
    );

    _go(AppStage.pass);
  }

  // ==================================================
  // FAILED BIOMETRIC ATTEMPTS
  // ==================================================

  Future<void> registerFailedAttempt() async {
    await _setFailedAttempts(
      failedAttempts + 1,
    );

    if (failedAttempts >= maxAttempts) {
      lockedUntil = DateTime.now().add(
        lockDuration,
      );

      await _storage.write(
        key: _lockKey,
        value: lockedUntil!
            .millisecondsSinceEpoch
            .toString(),
      );

      await _setFailedAttempts(0);

      _go(AppStage.accountLocked);
    } else {
      _go(AppStage.verifyFailed);
    }
  }

  Future<void> _setFailedAttempts(
    int n,
  ) async {
    failedAttempts = n;

    await _storage.write(
      key: _failsKey,
      value: '$n',
    );
  }

  // ==================================================
  // ACCOUNT LOCKOUT EXPIRATION
  // ==================================================

  Future<void> lockExpired() async {
    lockedUntil = null;

    await _storage.delete(
      key: _lockKey,
    );

    _go(AppStage.verify);
  }

  void backToVerify() {
    _go(AppStage.verify);
  }

  // ==================================================
  // LOCK QR PASS
  // ==================================================

  void lockPass() {
    ++_passSession;

    unlockedUntil = null;

    if (stage == AppStage.pass) {
      _go(AppStage.verify);
    }
  }

  // ==================================================
  // BACKEND URL VALIDATION
  // ==================================================

  /// HTTPS is required for production.
  ///
  /// HTTP is permitted only in debug builds
  /// and only for local development addresses.
  ///
  /// This allows:
  ///
  /// Edge:
  /// http://127.0.0.1:8000
  ///
  /// Android emulator:
  /// http://10.0.2.2:8000
  ///
  /// Production:
  /// HTTPS only.

  static bool isAllowedQrBackendUrl(
    Uri uri,
  ) {
    if (!uri.hasAuthority ||
        uri.userInfo.isNotEmpty) {
      return false;
    }

    if (uri.scheme == 'https') {
      return true;
    }

    if (!kDebugMode ||
        uri.scheme != 'http') {
      return false;
    }

    const localHosts = {
      '127.0.0.1',
      'localhost',
      '10.0.2.2',
      '[::1]',
    };

    // Restrict cleartext HTTP to the
    // expected local development port.
    return localHosts.contains(uri.host) &&
        uri.port == 8000;
  }

  // ==================================================
  // REQUEST BACKEND-SIGNED JWT/JWS
  // ==================================================

  Future<PassToken> generatePass() async {
    // ----------------------------------------------
    // STEP 1: CHECK UNLOCK SESSION
    // ----------------------------------------------

    if (!isUnlocked ||
        stage != AppStage.pass ||
        user == null) {
      throw BackendException(
        "Pass is locked. Verify it's you first.",
      );
    }

    final session = _passSession;

    debugPrint(
      '========== QR DEBUG ==========',
    );

    debugPrint(
      'Current stage: $stage',
    );

    debugPrint(
      'User profile exists: ${user != null}',
    );

    debugPrint(
      'Session unlocked: $isUnlocked',
    );

    // ----------------------------------------------
    // STEP 2: VERIFY FIREBASE SESSION
    // ----------------------------------------------

    try {
      final firebaseUser =
          FirebaseAuth.instance.currentUser;

      if (firebaseUser == null ||
          firebaseUser.uid != user!.id) {
        throw BackendException(
          'Firebase authentication session '
          'is missing or mismatched.',
        );
      }

      debugPrint(
        'Firebase session available.',
      );

      // --------------------------------------------
      // STEP 3: GET FIREBASE ID TOKEN
      // --------------------------------------------

      final idToken =
          await firebaseUser.getIdToken();

      if (idToken == null ||
          idToken.isEmpty) {
        throw BackendException(
          'Could not retrieve Firebase ID token.',
        );
      }

      debugPrint(
        'Firebase ID token retrieved.',
      );

      // Never print the actual token.

      // --------------------------------------------
      // STEP 4: VALIDATE FASTAPI URL
      // --------------------------------------------

      final baseUrl = qrApiUrl.replaceFirst(
        RegExp(r'/$'),
        '',
      );

      final uri = Uri.parse(
        '$baseUrl/qr/issue',
      );

      debugPrint(
        'QR backend destination: '
        '${uri.scheme}://${uri.authority}${uri.path}',
      );

      if (!isAllowedQrBackendUrl(uri)) {
        throw BackendException(
          'QR backend requires HTTPS. '
          'Local HTTP is permitted only '
          'for debug development.',
        );
      }

      // --------------------------------------------
      // STEP 5: REQUEST SIGNED JWT
      // --------------------------------------------

      debugPrint(
        'Sending QR issuance request to FastAPI...',
      );

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type':
                  'application/json',
              'Authorization':
                  'Bearer $idToken',
            },
            body: jsonEncode({}),
          )
          .timeout(requestTimeout);

      debugPrint(
        'FastAPI HTTP status: '
        '${response.statusCode}',
      );

      // --------------------------------------------
      // STEP 6: HANDLE RESPONSE STATUS
      // --------------------------------------------

      if (response.statusCode == 401 ||
        response.statusCode == 403) {
      debugPrint(
        '========== AUTHENTICATION ERROR ==========',
      );

      debugPrint(
        'HTTP status: ${response.statusCode}',
      );

      // Print only the error message returned by FastAPI.
      // Do not print Firebase ID tokens.
      try {
        final errorData = jsonDecode(response.body);

        if (errorData is Map<String, dynamic>) {
          debugPrint(
            'FastAPI detail: ${errorData['detail']}',
          );
        }
      } catch (_) {
        debugPrint(
          'FastAPI returned a non-JSON error response.',
        );
      }

      debugPrint(
        '==========================================',
      );

      throw BackendException(
        'QR authorization failed '
        '(${response.statusCode}).',
      );
    }

      if (response.statusCode != 200) {
        // Development logging. Never log token values
        // or Authorization headers.
        debugPrint(
          'FastAPI error status: ${response.statusCode}',
        );

        debugPrint(
          'FastAPI response: ${response.body}',
        );

        throw BackendException(
          'QR backend returned HTTP ${response.statusCode}.',
        );
      }

      // --------------------------------------------
      // STEP 7: READ SIGNED JWT RESPONSE
      // --------------------------------------------

      final data = jsonDecode(
        response.body,
      );

      if (data is! Map<String, dynamic> ||
          data['token'] is! String) {
        throw BackendException(
          'QR backend returned an invalid response.',
        );
      }

      // The JWT has already been signed by
      // FastAPI using its ES256 private key.
      //
      // Flutter does not sign the token.
      //
      // Flutter only reads its claims for
      // displaying the QR and countdown.

      final pass = PassToken.fromBackendJwt(
        data['token'] as String,
      );

      // --------------------------------------------
      // STEP 8: CHECK JWT EXPIRY
      // --------------------------------------------

      if (pass.expiresAt <= nowSeconds()) {
        throw BackendException(
          'Backend returned an expired QR token.',
        );
      }

      // --------------------------------------------
      // STEP 9: CHECK SESSION STILL ACTIVE
      // --------------------------------------------

      if (session != _passSession ||
          !isUnlocked ||
          stage != AppStage.pass) {
        throw BackendException(
          'QR request invalidated '
          'by a locked session.',
        );
      }

      // --------------------------------------------
      // STEP 10: RETURN SIGNED QR TOKEN
      // --------------------------------------------

      debugPrint(
        'Signed QR JWT received successfully.',
      );

      debugPrint(
        'JWT expiry: ${pass.expiresAt}',
      );

      debugPrint(
        '==============================',
      );

      return pass;
    }

    // ----------------------------------------------
    // HANDLE REQUEST TIMEOUTS
    // ----------------------------------------------

    on TimeoutException {
      errorDetail =
          'QR backend request timed out.';

      _go(AppStage.backendUnreachable);

      throw BackendException(
        'QR backend timed out.',
      );
    }

    // ----------------------------------------------
    // HANDLE HTTP CONNECTION ERRORS
    // ----------------------------------------------

    on http.ClientException catch (e) {
      errorDetail =
          'QR backend connection failed.';

      debugPrint(
        'HTTP connection error: $e',
      );

      _go(AppStage.backendUnreachable);

      throw BackendException(
        'QR backend connection failed.',
      );
    }
  }
}
