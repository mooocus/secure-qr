import '../models/user_profile.dart';

class BackendException implements Exception {
  BackendException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Enrolment rejected because the student/staff ID is already registered
/// (Figma screen 08).
class DuplicateIdException extends BackendException {
  DuplicateIdException(String idLabel)
      : super('This $idLabel is already enrolled. Contact your administrator if this is a mistake.');
}

/// Server could not be reached (Figma screen 07).
class BackendUnreachableException extends BackendException {
  BackendUnreachableException([super.detail = 'request timed out after 10s']);
}

enum EnrolmentStatus { pendingReview, approved, rejected }

class EnrolmentResult {
  EnrolmentResult(this.profile, this.status);
  final UserProfile profile;
  final EnrolmentStatus status;
}

/// Everything the mobile app needs from the backend.
///
/// [MockBackendApi] implements this on-device so the app works before the
/// real backend exists. Later, add an HttpBackendApi with the same methods
/// (10 s timeout -> BackendUnreachableException) and swap it in main.dart.
abstract class BackendApi {
  /// User story #1 – enrol identity (Figma 01 / 08 / 11).
  Future<EnrolmentResult> enrol({
    required String name,
    required String email,
    required String campusId,
    required String password,
    required UserRole role,
  });

  /// [identifier] is the student/staff ID number or the email (Figma 04).
  Future<UserProfile> login({required String identifier, required String password});

  /// Registers the device public key and returns an issuer-signed credential
  /// (JWS) binding the user to that key.
  Future<String> issueCredential({
    required UserProfile user,
    required Map<String, String> deviceJwk,
  });

  /// Issuer public keys (kid -> JWK) – the trust anchors scanners pre-load.
  Future<Map<String, Map<String, dynamic>>> issuerKeys();
}
