import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'patients_screen.dart';
import 'clinician_profile_screen.dart';

// Main screen for Doctors and Nurses, with a bottom navigation bar.
// (The Doctor Review Queue tab will be added later.)
class ClinicianShell extends StatefulWidget {
  final String role; // 'doctor' or 'nurse'

  const ClinicianShell({super.key, required this.role});

  @override
  State<ClinicianShell> createState() => _ClinicianShellState();
}

class _ClinicianShellState extends State<ClinicianShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      PatientsScreen(role: widget.role),
      const ClinicianProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.25),
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
