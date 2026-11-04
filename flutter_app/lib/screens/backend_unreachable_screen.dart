import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// Figma 07 — Can't Reach Server.
class BackendUnreachableScreen extends StatefulWidget {
  const BackendUnreachableScreen({super.key});

  @override
  State<BackendUnreachableScreen> createState() => _BackendUnreachableScreenState();
}

class _BackendUnreachableScreenState extends State<BackendUnreachableScreen> {
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
    return StateScaffold(
      onBack: app.backToVerify,
      children: [
        const SizedBox(height: 144),
        IconCircle(
          size: 120,
          color: AppColors.amberSoft,
          child: Text('!', style: AppText.inter(52, FontWeight.w700, AppColors.amber)),
        ),
        const SizedBox(height: 30),
        Text("Can't Reach Server", textAlign: TextAlign.center, style: AppText.stateTitle),
        const SizedBox(height: 11),
        Text("We couldn't generate your access pass. Check your connection and try again.",
            textAlign: TextAlign.center, style: AppText.body),
        const SizedBox(height: 12),
        Text(app.errorDetail, textAlign: TextAlign.center, style: AppText.footnote),
        const SizedBox(height: 35),
        AppButton(label: 'Retry', onPressed: _retry, loading: _busy),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => showMessage(context, 'Contact the facility help desk or IT support.'),
          child: Text('Contact Support', style: AppText.link),
        ),
      ],
    );
  }
}
