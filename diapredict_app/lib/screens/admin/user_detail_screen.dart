import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';
import '../../utils/user_labels.dart';
import '../../widgets/status_chip.dart';

// Shows one Doctor/Nurse account and lets the Administrator
// approve, reject, deactivate or reactivate it.
class UserDetailScreen extends StatefulWidget {
  final String uid;

  const UserDetailScreen({super.key, required this.uid});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  bool _busy = false;

  late final DocumentReference<Map<String, dynamic>> _userRef =
      FirebaseFirestore.instance.collection('users').doc(widget.uid);

  Future<bool> _confirm(String title, String message, String action) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _changeStatus({
    required String newStatus,
    required String title,
    required String message,
    required String action,
    required String doneMessage,
    required bool closeAfter,
  }) async {
    final ok = await _confirm(title, message, action);
    if (!ok) return;

    setState(() => _busy = true);
    final adminUid = FirebaseAuth.instance.currentUser!.uid;

    // only these fields may be changed by the admin (see Firestore rules)
    final update = <String, dynamic>{
      'status': newStatus,
      'statusUpdatedBy': adminUid,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
    };
    if (newStatus == 'approved') {
      update['approvedBy'] = adminUid;
      update['approvedAt'] = FieldValue.serverTimestamp();
    }

    try {
      // a doctor who is no longer approved is also removed from the
      // "on duty" list nurses use for referrals (both writes together)
      final batch = FirebaseFirestore.instance.batch();
      batch.update(_userRef, update);
      if (newStatus != 'approved') {
        batch.delete(FirebaseFirestore.instance
            .collection('doctorDirectory')
            .doc(widget.uid));
      }
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(doneMessage)),
      );
      if (closeAfter) Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update the account (${e.code}).')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // buttons shown depend on the current status
  List<Widget> _actionButtons(String status, String name) {
    if (status == 'pending') {
      return [
        _bigButton(
          label: 'Approve',
          icon: Icons.check_circle_outline,
          filled: true,
          onPressed: () => _changeStatus(
            newStatus: 'approved',
            title: 'Approve registration?',
            message: '$name will be able to access DiaPredict.',
            action: 'Approve',
            doneMessage: 'Registration approved.',
            closeAfter: true,
          ),
        ),
        const SizedBox(height: 12),
        _bigButton(
          label: 'Reject',
          icon: Icons.cancel_outlined,
          filled: false,
          danger: true,
          onPressed: () => _changeStatus(
            newStatus: 'rejected',
            title: 'Reject registration?',
            message: '$name will not be able to access DiaPredict.',
            action: 'Reject',
            doneMessage: 'Registration rejected.',
            closeAfter: true,
          ),
        ),
      ];
    }
    if (status == 'approved') {
      return [
        _bigButton(
          label: 'Deactivate Account',
          icon: Icons.block,
          filled: false,
          danger: true,
          onPressed: () => _changeStatus(
            newStatus: 'deactivated',
            title: 'Deactivate account?',
            message: '$name will no longer be able to access DiaPredict '
                'until the account is reactivated.',
            action: 'Deactivate',
            doneMessage: 'Account deactivated.',
            closeAfter: false,
          ),
        ),
      ];
    }
    if (status == 'deactivated') {
      return [
        _bigButton(
          label: 'Reactivate Account',
          icon: Icons.restart_alt,
          filled: true,
          onPressed: () => _changeStatus(
            newStatus: 'approved',
            title: 'Reactivate account?',
            message: '$name will be able to access DiaPredict again.',
            action: 'Reactivate',
            doneMessage: 'Account reactivated.',
            closeAfter: false,
          ),
        ),
      ];
    }
    if (status == 'rejected') {
      return [
        _bigButton(
          label: 'Approve Registration',
          icon: Icons.check_circle_outline,
          filled: true,
          onPressed: () => _changeStatus(
            newStatus: 'approved',
            title: 'Approve this registration?',
            message: 'This registration was rejected earlier. '
                '$name will be able to access DiaPredict.',
            action: 'Approve',
            doneMessage: 'Registration approved.',
            closeAfter: false,
          ),
        ),
      ];
    }
    return [];
  }

  Widget _bigButton({
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback onPressed,
    bool danger = false,
  }) {
    final callback = _busy ? null : onPressed;
    return SizedBox(
      height: 50,
      child: filled
          ? FilledButton.icon(
              onPressed: callback,
              icon: Icon(icon),
              label: Text(label),
            )
          : OutlinedButton.icon(
              onPressed: callback,
              icon: Icon(icon),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: danger ? AppColors.danger : AppColors.primary,
                side: BorderSide(
                  color: danger ? AppColors.danger : AppColors.primary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Account Details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _userRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load account.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data();
          if (data == null) {
            return const Center(child: Text('Account not found.'));
          }

          final name = (data['name'] ?? '-').toString();
          final role = data['role'] as String?;
          final status = (data['status'] ?? '').toString();
          final workplace = (data['workplace'] ?? '').toString();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.surfaceLight,
                        child: Icon(
                          role == 'doctor'
                              ? Icons.medical_services_outlined
                              : Icons.health_and_safety_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(roleLabel(role),
                                style: const TextStyle(
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      StatusChip(status: status),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // professional information submitted at registration
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Professional Information',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _infoRow(Icons.email_outlined, 'Email Address',
                          (data['email'] ?? '-').toString()),
                      _infoRow(Icons.badge_outlined, 'Professional Role',
                          roleLabel(role)),
                      _infoRow(Icons.verified_user_outlined,
                          registrationLabel(role),
                          (data['registrationNo'] ?? '-').toString()),
                      _infoRow(Icons.local_hospital_outlined,
                          'Workplace / Institution',
                          workplace.isEmpty ? 'Not provided' : workplace),
                      _infoRow(Icons.event_outlined, 'Registered On',
                          formatDate(data['createdAt'])),
                      if (data['statusUpdatedAt'] != null)
                        _infoRow(Icons.update, 'Status Last Updated',
                            formatDate(data['statusUpdatedAt'])),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (status == 'pending')
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Please verify the professional registration number '
                    'before approving this account.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),

              ..._actionButtons(status, name),
            ],
          );
        },
      ),
    );
  }
}
