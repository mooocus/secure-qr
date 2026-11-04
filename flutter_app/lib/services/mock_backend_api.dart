
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/jws.dart';
import '../models/user_profile.dart';
import 'backend_api.dart';

/// Development-only mock backend.
///
/// This class is retained for UI testing.
/// It must NOT issue real QR credentials.
///
/// Production login and registration should use
/// FirebaseBackendApi instead.
class MockBackendApi implements BackendApi {
  MockBackendApi({
    FlutterSecureStorage? storage,
  }) : _storage =
           storage ?? const FlutterSecureStorage();

  static const _usersKey = 'mock.users';

  final FlutterSecureStorage _storage;

  bool simulateDuplicateIdOnce = false;
  bool simulateUnreachableOnce = false;

  Future<void> _latency() {
    return Future.delayed(
      const Duration(milliseconds: 400),
    );
  }

  Future<void> _maybeUnreachable() async {
    if (simulateUnreachableOnce) {
      simulateUnreachableOnce = false;

      await Future.delayed(
        const Duration(seconds: 1),
      );

      throw BackendUnreachableException();
    }
  }

  Future<Map<String, dynamic>> _users() async {
    final raw = await _storage.read(
      key: _usersKey,
    );

    if (raw == null) {
      return {};
    }

    return jsonDecode(raw) as Map<String, dynamic>;
  }

  String _hash(String salt, String password) {
    return b64url(
      sha256(
        utf8.encode('$salt:$password'),
      ),
    );
  }

  // --------------------------------------------------
  // MOCK REGISTRATION
  // --------------------------------------------------

  @override
  Future<EnrolmentResult> enrol({
    required String name,
    required String email,
    required String campusId,
    required String password,
    required UserRole role,
  }) async {
    await _latency();
    await _maybeUnreachable();

    final idLabel = role == UserRole.student
        ? 'Student ID'
        : 'Staff ID';

    final users = await _users();

    final emailKey = email.trim().toLowerCase();
    final id = campusId.trim().toUpperCase();

    final idTaken = users.values.any((u) {
      final record = u as Map;
      final profile = record['profile'] as Map;

      return profile['campusId'] == id;
    });

    if (simulateDuplicateIdOnce || idTaken) {
      simulateDuplicateIdOnce = false;
      throw DuplicateIdException(idLabel);
    }

    if (users.containsKey(emailKey)) {
      throw BackendException(
        'An account with this email already exists.',
      );
    }

    final profile = UserProfile(
      id: randomId(9),
      name: name.trim(),
      email: emailKey,
      campusId: id,
      role: role,
    );

    final salt = randomId();

    users[emailKey] = {
      'profile': profile.toJson(),
      'salt': salt,
      'hash': _hash(salt, password),
    };

    await _storage.write(
      key: _usersKey,
      value: jsonEncode(users),
    );

    return EnrolmentResult(
      profile,
      EnrolmentStatus.pendingReview,
    );
  }

  // --------------------------------------------------
  // MOCK LOGIN
  // --------------------------------------------------

  @override
  Future<UserProfile> login({
    required String identifier,
    required String password,
  }) async {
    await _latency();
    await _maybeUnreachable();

    final users = await _users();
    final key = identifier.trim();

    Map<String, dynamic>? record;

    final emailRecord = users[key.toLowerCase()];

    if (emailRecord != null) {
      record = Map<String, dynamic>.from(
        emailRecord as Map,
      );
    }

    if (record == null) {
      for (final value in users.values) {
        final candidate = Map<String, dynamic>.from(
          value as Map,
        );

        final profile =
            candidate['profile'] as Map;

        if (profile['campusId'] ==
            key.toUpperCase()) {
          record = candidate;
          break;
        }
      }
    }

    if (record == null ||
        record['hash'] !=
            _hash(record['salt'] as String, password)) {
      throw BackendException(
        'Incorrect ID/email or password.',
      );
    }

    return UserProfile.fromJson(
      Map<String, dynamic>.from(
        record['profile'] as Map,
      ),
    );
  }

  // --------------------------------------------------
  // LEGACY CREDENTIAL FUNCTION
  // --------------------------------------------------

  /// Disabled because JWT signing must happen
  /// on the trusted FastAPI backend.
  @override
  Future<String> issueCredential({
    required UserProfile user,
    required Map<String, String> deviceJwk,
  }) async {
    throw UnimplementedError(
      'Local JWT issuance has been disabled. '
      'Use the trusted FastAPI backend.',
    );
  }

  // --------------------------------------------------
  // ISSUER PUBLIC KEYS
  // --------------------------------------------------

  /// No mock issuer keys are trusted.
  @override
  Future<Map<String, Map<String, dynamic>>>
      issuerKeys() async {
    return {};
  }
}
