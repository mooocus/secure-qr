import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import 'enrol_screen.dart';

/// Figma 04 — Login.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_identifier.text.trim().isEmpty || _password.text.isEmpty) {
      showMessage(context, 'Enter your ID number or email and password.');
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<AppState>().login(_identifier.text, _password.text);
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: kPagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 46),
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                  child: Text('QR', style: AppText.inter(16, FontWeight.w700, Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
              Center(child: Text('SecureAccess', style: AppText.brand)),
              const SizedBox(height: 42),
              Text('Welcome Back', style: AppText.title),
              const SizedBox(height: 7),
              Text('Log in to manage your enrolment and access pass.', style: AppText.body),
              const SizedBox(height: 38),
              AppTextField(
                label: 'ID Number or Email',
                hint: 'e.g. alex.johnson@sim.edu.sg',
                controller: _identifier,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Password',
                hint: '••••••••',
                controller: _password,
                obscure: true,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 52),
              AppButton(label: 'Log In', style: AppButtonStyle.slate, onPressed: _submit, loading: _loading),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.border, height: 1)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: AppText.small)),
                  const Expanded(child: Divider(color: AppColors.border, height: 1)),
                ],
              ),
              const SizedBox(height: 22),
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EnrolScreen())),
                  child: Text('New here? Enrol as a user', style: AppText.link),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
