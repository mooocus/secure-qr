import 'package:flutter/material.dart';

import '../services/backend_api.dart';
import '../ui/components.dart';
import '../ui/tokens.dart';

/// Figma 11 — Enrolment Submitted.
class EnrolSubmittedScreen extends StatelessWidget {
  const EnrolSubmittedScreen({super.key, required this.status});

  final EnrolmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = switch (status) {
      EnrolmentStatus.pendingReview => ('Pending Review', AppColors.amber),
      EnrolmentStatus.approved => ('Approved', AppColors.green),
      EnrolmentStatus.rejected => ('Rejected', AppColors.red),
    };
    return StateScaffold(
      footer: [
        Text("You'll receive a notification once your enrolment is approved.",
            textAlign: TextAlign.center, style: AppText.footnote),
      ],
      children: [
        const SizedBox(height: 84),
        const IconCircle(
          size: 140,
          color: AppColors.greenSoft,
          child: Icon(Icons.check_rounded, size: 72, color: AppColors.green),
        ),
        const SizedBox(height: 82),
        Text('Enrolment Submitted', textAlign: TextAlign.center, style: AppText.stateTitle),
        const SizedBox(height: 83),
        Container(
          width: double.infinity,
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verification Status', style: AppText.caption),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(label, style: AppText.inter(13, FontWeight.w600, color)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        AppButton(
          label: 'Continue to Log In',
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ],
    );
  }
}
