import 'package:local_auth/local_auth.dart';

/// Wraps the platform biometric prompt (Face ID / Touch ID / fingerprint).
class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Demo switch: makes the next check fail (Figma "simulate verification failure").
  bool simulateFailureOnce = false;

  /// True if the device has biometric hardware AND the user has enrolled
  /// a face/fingerprint in the phone's settings.
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final enrolled = await _auth.getAvailableBiometrics();
      return supported && enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Human-friendly name for the main biometric on this device.
  Future<String> label() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return 'Face ID';
      if (types.contains(BiometricType.fingerprint)) return 'Fingerprint';
    } catch (_) {}
    return 'Biometrics';
  }

  /// Shows the system biometric prompt. Returns true only on success.
  Future<bool> authenticate(String reason) async {
    if (simulateFailureOnce) {
      simulateFailureOnce = false;
      return false;
    }
    try {
      return await _auth.authenticate(localizedReason: reason);
    } catch (_) {
      return false;
    }
  }
}
