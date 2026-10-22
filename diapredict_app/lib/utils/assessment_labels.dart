import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../theme/app_theme.dart';
import 'user_labels.dart';

// The six model inputs, in the same order as the trained model
const List<String> featureOrder = [
  'FastingBloodSugar',
  'HbA1c',
  'FrequentUrination',
  'Hypertension',
  'ExcessiveThirst',
  'UnexplainedWeightLoss',
];

const Map<String, String> featureLabels = {
  'FastingBloodSugar': 'Fasting Blood Sugar',
  'HbA1c': 'HbA1c',
  'FrequentUrination': 'Frequent Urination',
  'Hypertension': 'Hypertension',
  'ExcessiveThirst': 'Excessive Thirst',
  'UnexplainedWeightLoss': 'Unexplained Weight Loss',
};

// 150.0 -> "150", 126.5 -> "126.5"
String formatNumber(num value) {
  if (value % 1 == 0) return value.toInt().toString();
  return value.toString();
}

// shows an input value with its unit, or Yes/No for binary inputs
String featureValue(String key, dynamic value) {
  if (value == null) return '-';
  if (key == 'FastingBloodSugar') return '${formatNumber(value as num)} mg/dL';
  if (key == 'HbA1c') return '${formatNumber(value as num)} %';
  return value == 1 ? 'Yes' : 'No';
}

String reviewStatusLabel(String? status) {
  if (status == 'pending_review') return 'Pending Review';
  if (status == 'reviewed') return 'Reviewed';
  return 'Not Flagged';
}

Color reviewStatusColor(String? status) {
  if (status == 'pending_review') return pendingColor;
  if (status == 'reviewed') return AppColors.accentGreen;
  return AppColors.textSecondary;
}

Color predictionColor(String? predictedClass) {
  return predictedClass == 'Diabetes' ? AppColors.danger : AppColors.accentGreen;
}

// Firestore Timestamp -> "dd/mm/yyyy hh:mm"
String formatDateTime(dynamic value) {
  if (value is Timestamp) {
    final d = value.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
  return '-';
}
