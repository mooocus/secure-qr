import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/user_profile.dart';
import '../services/backend_api.dart';
import '../services/mock_backend_api.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';
import 'enrol_submitted_screen.dart';

/// Figma 01 — Enrol Identity, and 08 — Enrolment Error (Duplicate ID).
/// User story #1.
class EnrolScreen extends StatefulWidget {
  const EnrolScreen({super.key});

  @override
  State<EnrolScreen> createState() => _EnrolScreenState();
}

class _EnrolScreenState extends State<EnrolScreen> {
  final _name = TextEditingController();
  final _campusId = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.student;
  bool _loading = false;
  String? _idError; // set when the backend reports a duplicate ID

  @override
  void dispose() {
    for (final c in [_name, _campusId, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate() {
    if (_name.text.trim().isEmpty) return 'Enter your full name.';
    if (_campusId.text.trim().isEmpty) return 'Enter your ID number.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
      return 'Enter a valid institutional email.';
    }
    final p = _password.text;
    if (p.length < 8 || !RegExp(r'[A-Za-z]').hasMatch(p) || !RegExp(r'\d').hasMatch(p)) {
      return 'Password needs 8+ characters with letters and numbers.';
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      showMessage(context, problem);
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await context.read<AppState>().enrol(
            name: _name.text,
            email: _email.text,
            campusId: _campusId.text,
            password: _password.text,
            role: _role,
          );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => EnrolSubmittedScreen(status: result.status)),
      );
    } on DuplicateIdException catch (e) {
      if (mounted) setState(() => _idError = e.message);
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _simulateDuplicate() {
    final api = context.read<AppState>().api;
    if (api is MockBackendApi) api.simulateDuplicateIdOnce = true;
    if (_name.text.isEmpty) _name.text = 'Alex Johnson';
    if (_campusId.text.isEmpty) _campusId.text = 'STU-204817';
    if (_email.text.isEmpty) _email.text = 'alex.johnson@uni.edu';
    if (_password.text.isEmpty) _password.text = 'password123';
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final idLabel = _role == UserRole.student ? 'Student ID' : 'Staff ID';
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: kPagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                children: [
                  const IconCircle(size: 72, color: AppColors.primarySoft),
                  const Spacer(),
                  if (Navigator.of(context).canPop()) BackCircleButton(onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 16),
              Text('Enrol Identity', style: AppText.title),
              const SizedBox(height: 9),
              Text(
                'Register as an authorised user of the facility. Your details are verified once and stored securely.',
                style: AppText.body,
              ),
              const SizedBox(height: 16),
              Text('I am a', style: AppText.label),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(child: _roleOption(UserRole.student, 'Student')),
                  const SizedBox(width: 9),
                  Expanded(child: _roleOption(UserRole.staff, 'Staff')),
                ],
              ),
              const SizedBox(height: 36),
              AppTextField(
                label: 'Full Name',
                hint: 'e.g. Alex Johnson',
                controller: _name,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: _idError == null ? 'ID Number' : idLabel,
                hint: 'e.g. SIM-204817',
                controller: _campusId,
                errorText: _idError,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) {
                  if (_idError != null) setState(() => _idError = null);
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Institutional Email',
                hint: 'e.g. alex.johnson@sim.edu.sg',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Create Password',
                hint: 'At least 8 characters, letters and numbers',
                controller: _password,
                obscure: true,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Enrol as Authorised User',
                style: AppButtonStyle.slate,
                // Disabled (Figma 08) until the duplicate ID is changed.
                onPressed: _idError == null ? _submit : null,
                loading: _loading,
              ),
              const SizedBox(height: 40),
              DemoLink(label: 'simulate duplicate ID', onTap: _simulateDuplicate),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roleOption(UserRole role, String label) {
    final selected = _role == role;
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: selected ? BorderSide.none : const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() {
          _role = role;
          _idError = null;
        }),
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              label,
              style: AppText.inter(13, FontWeight.w600, selected ? Colors.white : AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
