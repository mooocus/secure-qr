import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import 'backend_api.dart';

/// Real Firebase authentication backend.
///
/// Handles:
/// - User registration
/// - Firestore profile storage
/// - Administrator approval verification
/// - Approved user login
///
/// QR JWT issuance is handled separately
/// by the trusted Python FastAPI service.
class FirebaseBackendApi implements BackendApi {
  FirebaseBackendApi({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  // --------------------------------------------------
  // REGISTER USER
  // --------------------------------------------------

  @override
  Future<EnrolmentResult> enrol({
    required String name,
    required String email,
    required String campusId,
    required String password,
    required UserRole role,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanCampusId =
        campusId.trim().toUpperCase();

    if (cleanName.isEmpty ||
        cleanEmail.isEmpty ||
        cleanCampusId.isEmpty) {
      throw BackendException(
        'Please complete all registration fields.',
      );
    }

    UserCredential credential;

    try {
      // Firebase Authentication creates the user.
      credential = await _auth
          .createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw BackendException(
        _authErrorMessage(e),
      );
    }

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      throw BackendException(
        'Unable to create Firebase account.',
      );
    }

    final profile = UserProfile(
      id: firebaseUser.uid,
      name: cleanName,
      email: cleanEmail,
      campusId: cleanCampusId,
      role: role,
    );

    try {
      // New accounts are ALWAYS pending.
      // The user is not allowed to self-approve.
      await _db
          .collection('users')
          .doc(firebaseUser.uid)
          .set({
        'name': cleanName,
        'email': cleanEmail,
        'campusId': cleanCampusId,
        'role': 'USER',
        'requestedRole': role.name.toUpperCase(),
        'status': 'PENDING',
        'createdAt': FieldValue.serverTimestamp(),
        'approvedAt': null,
        'approvedBy': null,
      });

      // Registration does not grant access.
      await _auth.signOut();

      return EnrolmentResult(
        profile,
        EnrolmentStatus.pendingReview,
      );
    } on FirebaseException catch (e) {
      await _auth.signOut();

      // The Auth account may already exist even
      // if saving the Firestore profile failed.
      // A recovery/admin flow should reconcile it.
      throw BackendException(
        'Account created, but profile could not '
        'be saved: ${e.code}. '
        'Contact an administrator before retrying.',
      );
    }
  }

  // --------------------------------------------------
  // LOGIN
  // --------------------------------------------------

  @override
  Future<UserProfile> login({
    required String identifier,
    required String password,
  }) async {
    final email = identifier.trim().toLowerCase();

    // Firebase email/password authentication
    // requires an email, not a campus ID.
    if (!email.contains('@')) {
      throw BackendException(
        'Please log in using your registered email.',
      );
    }

    UserCredential credential;

    try {
      credential = await _auth
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw BackendException(
        _authErrorMessage(e),
      );
    }

    final firebaseUser = credential.user;

    if (firebaseUser == null) {
      throw BackendException(
        'Unable to authenticate user.',
      );
    }

    try {
      // Read from the server to avoid accepting
      // a stale locally cached approval.
      final snapshot = await _db
          .collection('users')
          .doc(firebaseUser.uid)
          .get(
            const GetOptions(
              source: Source.server,
            ),
          );

      if (!snapshot.exists) {
        throw BackendException(
          'User profile not found. '
          'Please contact an administrator.',
        );
      }

      final data = snapshot.data()!;

      final status =
          (data['status'] ?? '')
              .toString()
              .toUpperCase();

      // Only administrator-approved users
      // may proceed to biometric verification.
      if (status != 'APPROVED') {
        if (status == 'PENDING') {
          throw BackendException(
            'Your account is pending '
            'administrator approval.',
          );
        }

        if (status == 'REJECTED') {
          throw BackendException(
            'Your registration was rejected.',
          );
        }

        if (status == 'SUSPENDED') {
          throw BackendException(
            'Your account has been suspended.',
          );
        }

        throw BackendException(
          'Your account is not approved.',
        );
      }

      final requestedRole =
          (data['requestedRole'] ??
                  data['role'] ??
                  'STUDENT')
              .toString()
              .toUpperCase();

      final userRole = requestedRole == 'STAFF'
          ? UserRole.staff
          : UserRole.student;

      final profile = UserProfile(
        id: firebaseUser.uid,
        name: (data['name'] ?? '').toString(),
        email: (data['email'] ??
                firebaseUser.email ??
                '')
            .toString(),
        campusId:
            (data['campusId'] ?? '').toString(),
        role: userRole,
      );

      // Keep the Firebase user signed in.
      // The QR service will use its ID token.
      return profile;
    } catch (e) {
      // Never retain an authenticated session
      // after approval verification fails.
      await _auth.signOut();

      if (e is BackendException) {
        rethrow;
      }

      if (e is FirebaseException) {
        throw BackendUnreachableException();
      }

      rethrow;
    }
  }

  // --------------------------------------------------
  // LEGACY DEVICE CREDENTIAL API
  // --------------------------------------------------

  /// Retained only to satisfy the old BackendApi
  /// interface. It must not sign QR credentials.
  ///
  /// The Phase 2 AppState generates QR passes
  /// through the separate FastAPI /qr/issue service.
  @override
  Future<String> issueCredential({
    required UserProfile user,
    required Map<String, String> deviceJwk,
  }) async {
    throw UnimplementedError(
      'Legacy device credential issuance is '
      'disabled in Phase 2.',
    );
  }

  // --------------------------------------------------
  // LEGACY ISSUER KEYS API
  // --------------------------------------------------

  @override
  Future<Map<String, Map<String, dynamic>>>
      issuerKeys() async {
    return {};
  }

  // --------------------------------------------------
  // FIREBASE AUTH ERRORS
  // --------------------------------------------------

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';

      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'weak-password':
        return 'Please choose a stronger password.';

      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return 'Incorrect email or password.';

      case 'user-disabled':
        return 'This account has been disabled.';

      case 'too-many-requests':
        return 'Too many attempts. Try again later.';

      case 'network-request-failed':
        return 'Unable to reach Firebase. '
            'Check your internet connection.';

      default:
        return e.message ??
            'Firebase authentication failed.';
    }
  }
}
