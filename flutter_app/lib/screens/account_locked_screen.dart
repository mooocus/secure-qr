import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import 'logout_screen.dart';

/// Figma 10 — Account Temporarily Locked (after 3 failed biometric checks).
class AccountLockedScreen extends StatefulWidget {
  const AccountLockedScreen({super.key});

  @override
  State<AccountLockedScreen> createState() => _AccountLockedScreenState();
}

class _AccountLockedScreenState extends State<AccountLockedScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final app = context.read<AppState>();
      if (!app.isLocked) {
        _timer?.cancel();
        app.lockExpired();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final remaining = app.lockedUntil == null ? Duration.zero : app.lockedUntil!.difference(DateTime.now());
    final secs = remaining.isNegative ? 0 : remaining.inSeconds;
    final mmss = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    return StateScaffold(
      onBack: app.backToVerify,
      children: [
        const SizedBox(height: 124),
        const IconCircle(
          size: 140,
          color: AppColors.redSoft,
          child: Icon(Icons.lock_rounded, size: 60, color: AppColors.red),
        ),
        const SizedBox(height: 30),
        Text('Account Temporarily Locked', textAlign: TextAlign.center, style: AppText.stateTitle),
        const SizedBox(height: 11),
        Text(
          'Too many failed verification attempts. For your security, this device is locked for '
          '${AppState.lockDuration.inMinutes} minutes.',
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
        const SizedBox(height: 30),
        StatusPill(
          text: 'Unlocks in $mmss',
          height: 36,
          background: AppColors.fieldFill,
          border: AppColors.border,
          style: AppText.inter(14, FontWeight.w600, AppColors.textPrimary),
        ),
        const SizedBox(height: 40),
        AppButton(
          label: 'Log Out',
          style: AppButtonStyle.danger,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LogoutScreen())),
        ),
      ],
    );
  }
}
