import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/app_theme.dart';

// Shown when a signed-in user is not approved yet (or cannot use the app).
// status: 'pending', 'rejected', 'deactivated', 'missing' or 'error'
class AccountStatusScreen extends StatelessWidget {
    final String status;
  final VoidCallback? onRetry; // only used for the 'error' status

  const AccountStatusScreen({super.key, required this.status, this.onRetry});
  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    String title;
    String message;

    if (status == 'pending') {
      icon = Icons.hourglass_top;
      iconColor = AppColors.primary;
      title = 'Pending Verification';
      message = 'Your professional account is currently pending '
          'administrator verification. You will be able to access '
          'DiaPredict once your account has been approved.';
    } else if (status == 'rejected') {
      icon = Icons.cancel_outlined;
      iconColor = AppColors.danger;
      title = 'Registration Not Approved';
      message = 'Your registration was not approved by the administrator. '
          'Please contact your administrator for more information.';
    } else if (status == 'deactivated') {
      icon = Icons.block;
      iconColor = AppColors.danger;
      title = 'Account Deactivated';
      message = 'Your account has been deactivated. '
          'Please contact your administrator for more information.';
    } else if (status == 'missing') {
      icon = Icons.person_off_outlined;
      iconColor = AppColors.textSecondary;
      title = 'Account Details Not Found';
      message = 'We could not find your professional account details. '
          'Please contact your administrator or register again.';
    } else {
      icon = Icons.error_outline;
      iconColor = AppColors.danger;
      title = 'Unable to Load Account';
      message = 'Please check your internet connection and try again.';
    }

    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(icon, size: 72, color: iconColor),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                               const SizedBox(height: 32),
                if (onRetry != null) ...[
                  SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: onRetry,
                      child: const Text('Try Again',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    // AuthGate (main.dart) returns to the Login screen
                    onPressed: () => FirebaseAuth.instance.signOut(),
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
