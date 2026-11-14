
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/mock_backend_api.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// Figma 02 — Biometric Unlock ("Verify It's You").
///
/// Supports normal biometric verification and
/// an optional development-only biometric bypass.
class VerifyScreen extends StatefulWidget {
  const VerifyScreen({super.key});

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  bool _busy = false;
  String _label = 'Face ID';

  @override
  void initState() {
    super.initState();

    context.read<AppState>().biometrics.label().then((label) {
      if (mounted) {
        setState(() => _label = label);
      }
    });
  }

  // --------------------------------------------------
  // NORMAL BIOMETRIC VERIFICATION
  // --------------------------------------------------

  Future<void> _verify() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final message = await context.read<AppState>().verify();

      if (!mounted) return;

      if (message != null) {
        showMessage(context, message);
      }
    } catch (e) {
      if (!mounted) return;

      showMessage(
        context,
        'Biometric verification failed: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  // --------------------------------------------------
  // DEVELOPMENT-ONLY BIOMETRIC BYPASS
  // --------------------------------------------------

  Future<void> _skipBiometrics() async {
    if (_busy || !AppState.allowDemoBypass) {
      return;
    }

    setState(() => _busy = true);

    try {
      await context
          .read<AppState>()
          .bypassBiometricsForTesting();
    } catch (e) {
      if (!mounted) return;

      showMessage(
        context,
        'Unable to bypass biometrics: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  // --------------------------------------------------
  // DEMO: SIMULATE BIOMETRIC FAILURE
  // --------------------------------------------------

  void _simulateFailure() {
    if (_busy) return;

    context
        .read<AppState>()
        .biometrics
        .simulateFailureOnce = true;

    _verify();
  }

  // --------------------------------------------------
  // DEMO: SIMULATE BACKEND UNREACHABLE
  // --------------------------------------------------

  void _simulateUnreachable() {
    if (_busy) return;

    final app = context.read<AppState>();
    final api = app.api;

    if (api is MockBackendApi) {
      api.simulateUnreachableOnce = true;
      _verify();
    } else {
      showMessage(
        context,
        'Backend-unreachable simulation is available only in mock mode. '
        'To test the real FastAPI connection failure, stop the backend '
        'and retry QR generation.',
      );
    }
  }

  // --------------------------------------------------
  // BUILD SCREEN
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return StateScaffold(
      footer: [
        DemoLink(
          label: 'simulate verification failure',
          onTap: _simulateFailure,
        ),
        DemoLink(
          label: 'simulate backend unreachable',
          onTap: _simulateUnreachable,
        ),
      ],
      children: [
        const SizedBox(height: 46),

        Text(
          "Verify It's You",
          textAlign: TextAlign.center,
          style: AppText.title,
        ),

        const SizedBox(height: 141),

        const IconCircle(
          size: 140,
          color: AppColors.primarySoft,
          child: FaceFrame(
            color: AppColors.primary,
          ),
        ),

        const SizedBox(height: 60),

        // NORMAL BIOMETRIC BUTTON
        AppButton(
          label: 'Use $_label',
          style: AppButtonStyle.slate,
          onPressed: _verify,
          loading: _busy,
        ),

        // TEMPORARY TESTING BYPASS
        if (AppState.allowDemoBypass) ...[
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _skipBiometrics,
              icon: const Icon(
                Icons.science_outlined,
                size: 20,
              ),
              label: const Text(
                'Skip Biometrics (Testing Only)',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(
                  color: AppColors.primary,
                ),
                minimumSize: const Size(
                  double.infinity,
                  52,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          const SizedBox(
            width: double.infinity,
            child: Text(
              'Development mode only — biometric '
              'authentication is skipped.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
