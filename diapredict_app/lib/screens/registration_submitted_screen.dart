import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// Shown after a Doctor/Nurse submits the registration form.
class RegistrationSubmittedScreen extends StatelessWidget {
  const RegistrationSubmittedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.mark_email_read_outlined,
                    size: 72, color: AppColors.accentGreen),
                const SizedBox(height: 16),
                Text(
                  'Registration Submitted',
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your registration has been submitted successfully. '
                  'Your professional account is currently pending '
                  'administrator verification. You will be able to access '
                  'DiaPredict once your account has been approved.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    // the Login screen is directly underneath this screen
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Sign In',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
