import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// Figma 06 — Biometric Failed (Retry).
class VerifyFailedScreen extends StatefulWidget {
  const VerifyFailedScreen({super.key});

  @override
  State<VerifyFailedScreen> createState() => _VerifyFailedScreenState();
}

class _VerifyFailedScreenState extends State<VerifyFailedScreen> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    final message = await context.read<AppState>().verify();
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) showMessage(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final left = app.triesLeft;
    return StateScaffold(
      onBack: app.backToVerify,
      footer: [
        Text('After ${AppState.maxAttempts} failed attempts, your account will be temporarily locked for security.',
            textAlign: TextAlign.center, style: AppText.footnote),
        const SizedBox(height: 10),
        DemoLink(label: '3rd failed attempt (account locked)', onTap: () async {
          while (app.stage == AppStage.verifyFailed) {
            await app.registerFailedAttempt();
          }
        }),
      ],
      children: [
        const SizedBox(height: 44),
        Text('Verification Failed', textAlign: TextAlign.center, style: AppText.stateTitle),
        const SizedBox(height: 46),
        const IconCircle(size: 140, color: AppColors.redSoft, child: FaceFrame(color: AppColors.red)),
        const SizedBox(height: 30),
        Text("We couldn't verify your identity. Please try again.", textAlign: TextAlign.center, style: AppText.body),
        const SizedBox(height: 24),
        StatusPill(
          text: '$left of ${AppState.maxAttempts} ${left == 1 ? 'try' : 'tries'} left',
          background: AppColors.amberSoft,
          style: AppText.inter(12, FontWeight.w600, AppColors.amber),
        ),
        const SizedBox(height: 22),
        AppButton(label: 'Try Again', onPressed: _retry, loading: _busy),
      ],
    );
  }
}
