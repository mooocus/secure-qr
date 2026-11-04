import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// Figma 05 — Log Out? confirmation.
class LogoutScreen extends StatelessWidget {
  const LogoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StateScaffold(
      footer: [
        AppButton(label: 'Cancel', style: AppButtonStyle.outline, onPressed: () => Navigator.of(context).pop()),
        const SizedBox(height: 14),
        AppButton(
          label: 'Log Out',
          style: AppButtonStyle.danger,
          onPressed: () async {
            final app = context.read<AppState>();
            Navigator.of(context).popUntil((r) => r.isFirst);
            await app.logout();
          },
        ),
        const SizedBox(height: 140),
      ],
      children: [
        const SizedBox(height: 164),
        IconCircle(
          size: 96,
          color: AppColors.redSoft,
          child: Text('→', style: AppText.inter(40, FontWeight.w700, AppColors.red)),
        ),
        const SizedBox(height: 34),
        Text('Log Out?', textAlign: TextAlign.center, style: AppText.stateTitle),
        const SizedBox(height: 8),
        Text('Your device key will be removed. You will need to verify again next time.',
            textAlign: TextAlign.center, style: AppText.body),
      ],
    );
  }
}
