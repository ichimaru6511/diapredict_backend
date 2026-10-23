import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/notification_center.dart';
import '../../theme/app_theme.dart';
import 'assessment_detail_screen.dart';
import 'patients_screen.dart';
import 'review_queue_screen.dart';
import 'clinician_profile_screen.dart';

// Main screen for Doctors and Nurses, with a bottom navigation bar.
//   Nurse:  Patients | Profile
//   Doctor: Patients | Review Queue | Profile
class ClinicianShell extends StatefulWidget {
  final String role; // 'doctor' or 'nurse'

  const ClinicianShell({super.key, required this.role});

  @override
  State<ClinicianShell> createState() => _ClinicianShellState();
}

class _ClinicianShellState extends State<ClinicianShell> {
  int _index = 0;
  int _pendingCount = 0; // badge number on the doctor's Review Queue tab
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pendingSub;

  bool get _isDoctor => widget.role == 'doctor';

  @override
  void initState() {
    super.initState();

    // in-app notifications: show a pop-up banner when a new one arrives
    NotificationCenter.start(
      uid: FirebaseAuth.instance.currentUser!.uid,
      role: widget.role,
      onNew: _showNotificationBanner,
    );

    // keep counting the assessments waiting for review
    if (_isDoctor) {
      _pendingSub = FirebaseFirestore.instance
          .collectionGroup('assessments')
          .where('reviewStatus', isEqualTo: 'pending_review')
          .snapshots()
          .listen(
        (snapshot) {
          final count = snapshot.docs
              .where((d) => d.data()['enteredInError'] != true)
              .length;
          if (mounted) setState(() => _pendingCount = count);
        },
        onError: (e) => debugPrint('Review badge error: $e'),
      );
    }
  }

  @override
  void dispose() {
    _pendingSub?.cancel();
    NotificationCenter.stop();
    super.dispose();
  }

  void _showNotificationBanner(String id, Map<String, dynamic> data) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            Icon(
              data['type'] == 'flagged' ? Icons.flag_outlined : Icons.task_alt,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text((data['message'] ?? '').toString())),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            NotificationCenter.markRead(id);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AssessmentDetailScreen(
                  patientId: data['patientId'],
                  assessmentId: data['assessmentId'],
                  role: widget.role,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Review Queue icon with a red number badge
  Widget _reviewIcon(bool selected) {
    return Badge(
      isLabelVisible: _pendingCount > 0,
      label: Text('$_pendingCount'),
      child: Icon(selected ? Icons.fact_check : Icons.fact_check_outlined),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      PatientsScreen(role: widget.role),
      if (_isDoctor) const ReviewQueueScreen(),
      const ClinicianProfileScreen(),
    ];

    final destinations = <Widget>[
      const NavigationDestination(
        icon: Icon(Icons.groups_outlined),
        selectedIcon: Icon(Icons.groups),
        label: 'Patients',
      ),
      if (_isDoctor)
        NavigationDestination(
          icon: _reviewIcon(false),
          selectedIcon: _reviewIcon(true),
          label: 'Review Queue',
        ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.25),
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: destinations,
      ),
    );
  }
}
