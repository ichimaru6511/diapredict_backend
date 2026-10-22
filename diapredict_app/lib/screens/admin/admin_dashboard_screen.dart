import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';
import '../../utils/user_labels.dart';

class AdminDashboardScreen extends StatelessWidget {
  final VoidCallback onOpenPending; // switches to the Verification tab

  const AdminDashboardScreen({super.key, required this.onOpenPending});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load data.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // count professional accounts (administrators are not counted)
          int pending = 0;
          int doctors = 0;
          int nurses = 0;
          int rejected = 0;
          int deactivated = 0;

          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            final role = data['role'];
            final status = data['status'];
            if (role == 'admin') continue;

            if (status == 'pending') {
              pending++;
            } else if (status == 'approved') {
              if (role == 'doctor') doctors++;
              if (role == 'nurse') nurses++;
            } else if (status == 'rejected') {
              rejected++;
            } else if (status == 'deactivated') {
              deactivated++;
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Welcome, Administrator',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Verify professional registrations and manage user accounts.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),

              // pending registrations (main task for the admin)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.hourglass_top, color: pendingColor),
                          SizedBox(width: 8),
                          Text(
                            'Pending Verification',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$pending',
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'registration(s) waiting for review',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: FilledButton(
                          onPressed: pending == 0 ? null : onOpenPending,
                          child: const Text('Review Registrations'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // other counts
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _StatCard(
                    label: 'Approved Doctors',
                    value: doctors,
                    icon: Icons.medical_services_outlined,
                    color: AppColors.primary,
                  ),
                  _StatCard(
                    label: 'Approved Nurses',
                    value: nurses,
                    icon: Icons.health_and_safety_outlined,
                    color: AppColors.accentGreen,
                  ),
                  _StatCard(
                    label: 'Rejected',
                    value: rejected,
                    icon: Icons.cancel_outlined,
                    color: AppColors.danger,
                  ),
                  _StatCard(
                    label: 'Deactivated',
                    value: deactivated,
                    icon: Icons.block,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Text(
              '$value',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
