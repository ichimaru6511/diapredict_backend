import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_theme.dart';

// Helpers to show user roles, statuses and dates in a readable way.

const Color pendingColor = Color(0xFFF5B942); // amber

String roleLabel(String? role) {
  switch (role) {
    case 'doctor':
      return 'Doctor';
    case 'nurse':
      return 'Nurse';
    case 'admin':
      return 'Administrator';
    default:
      return '-';
  }
}

String statusLabel(String? status) {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'approved':
      return 'Approved';
    case 'rejected':
      return 'Rejected';
    case 'deactivated':
      return 'Deactivated';
    default:
      return status ?? '-';
  }
}

Color statusColor(String? status) {
  switch (status) {
    case 'pending':
      return pendingColor;
    case 'approved':
      return AppColors.accentGreen;
    case 'rejected':
      return AppColors.danger;
    default:
      return AppColors.textSecondary;
  }
}

// label for the registration number, based on the role
String registrationLabel(String? role) {
  if (role == 'doctor') return 'MMC Registration Number';
  if (role == 'nurse') return 'Nursing Registration Number';
  return 'Registration Number';
}

// Firestore Timestamp -> "dd/mm/yyyy"
String formatDate(dynamic value) {
  if (value is Timestamp) {
    final d = value.toDate();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month/${d.year}';
  }
  return '-';
}
