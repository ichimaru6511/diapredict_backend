import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/user_labels.dart';
import 'status_chip.dart';

// One row in the Pending Verification and Users lists
class UserCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const UserCard({super.key, required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final role = data['role'] as String?;
    final workplace = (data['workplace'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.surfaceLight,
                child: Icon(
                  role == 'doctor'
                      ? Icons.medical_services_outlined
                      : Icons.health_and_safety_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (data['name'] ?? '-').toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${roleLabel(role)} • ${data['registrationNo'] ?? '-'}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (workplace.isNotEmpty)
                      Text(
                        workplace,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(status: data['status'] as String?),
            ],
          ),
        ),
      ),
    );
  }
}
