import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';
import '../../utils/user_labels.dart';
import '../../utils/duty.dart';

// Profile for Doctors and Nurses: view details, edit name/workplace, logout.
class ClinicianProfileScreen extends StatelessWidget {
  const ClinicianProfileScreen({super.key});

  Future<void> _editProfile(
      BuildContext context, Map<String, dynamic> data) async {
    final nameController =
        TextEditingController(text: (data['name'] ?? '').toString());
    final workplaceController =
        TextEditingController(text: (data['workplace'] ?? '').toString());

    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: workplaceController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Workplace / Institution (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    final name = nameController.text.trim();
    final workplace = workplaceController.text.trim();

    if (save != true) return;
    if (name.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name cannot be empty.')),
        );
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser!;
    try {
      // users may change only their name and workplace (see Firestore rules)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'name': name, 'workplace': workplace});
      await user.updateDisplayName(name);
      if (data['role'] == 'doctor') {
        // update the name nurses see (only if the doctor has an entry)
        final entry = await doctorDirectory.doc(user.uid).get();
        if (entry.exists) {
          await doctorDirectory.doc(user.uid).update({
            'name': name,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated.')),
        );
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update profile (${e.code}).')),
        );
      }
    }
  }

  // Doctor only: turn "On duty today" on or off
  Future<void> _setOnDuty(BuildContext context, bool onDuty) async {
    final user = FirebaseAuth.instance.currentUser!;
    try {
      await doctorDirectory.doc(user.uid).set({
        'name': user.displayName ?? '',
        'dutyDate': onDuty ? todayKey() : '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update duty status (${e.code}).')),
        );
      }
    }
  }

  Widget _dutyCard(BuildContext context, String uid) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: doctorDirectory.doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final onDuty = data != null && data['dutyDate'] == todayKey();
        return Card(
          child: SwitchListTile(
            value: onDuty,
            onChanged: snapshot.hasData ? (v) => _setOnDuty(context, v) : null,
            secondary: Icon(
              onDuty ? Icons.event_available : Icons.event_busy_outlined,
              color: onDuty ? AppColors.accentGreen : AppColors.textSecondary,
            ),
            title: const Text('On duty today'),
            subtitle: const Text(
              'Nurses can refer flagged assessments to you today. '
              'Turns off automatically tomorrow.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() ?? {};
          final role = data['role'] as String?;
          final workplace = (data['workplace'] ?? '').toString();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.surfaceLight,
                        child: Icon(
                          role == 'doctor'
                              ? Icons.medical_services_outlined
                              : Icons.health_and_safety_outlined,
                          size: 36,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        (data['name'] ?? '-').toString(),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        roleLabel(role),
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (role == 'doctor') ...[
                _dutyCard(context, uid),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _infoRow(Icons.email_outlined, 'Email Address',
                          (data['email'] ?? '-').toString()),
                      _infoRow(Icons.verified_user_outlined,
                          registrationLabel(role),
                          (data['registrationNo'] ?? '-').toString()),
                      _infoRow(Icons.local_hospital_outlined,
                          'Workplace / Institution',
                          workplace.isEmpty ? 'Not provided' : workplace),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: () => _editProfile(context, data),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Profile'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
