import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/mock_backend_api.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// Figma 02 — Biometric Unlock ("Verify It's You"). User story #2.
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
    context.read<AppState>().biometrics.label().then((l) {
      if (mounted) setState(() => _label = l);
    });
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final message = await context.read<AppState>().verify();
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) showMessage(context, message);
  }

  void _simulateFailure() {
    context.read<AppState>().biometrics.simulateFailureOnce = true;
    _verify();
  }

  void _simulateUnreachable() {
    final api = context.read<AppState>().api;
    if (api is MockBackendApi) api.simulateUnreachableOnce = true;
    // Force a fresh credential request so the backend is actually called.
    context.read<AppState>().keys.deleteKey().then((_) => _verify());
  }

  @override
  Widget build(BuildContext context) {
    return StateScaffold(
      footer: [
        DemoLink(label: 'simulate verification failure', onTap: _simulateFailure),
        DemoLink(label: 'simulate backend unreachable', onTap: _simulateUnreachable),
      ],
      children: [
        const SizedBox(height: 46),
        Text("Verify It's You", textAlign: TextAlign.center, style: AppText.title),
        const SizedBox(height: 141),
        const IconCircle(size: 140, color: AppColors.primarySoft, child: FaceFrame(color: AppColors.primary)),
        const SizedBox(height: 60),
        AppButton(label: 'Use $_label', style: AppButtonStyle.slate, onPressed: _verify, loading: _busy),
      ],
    );
  }
}
