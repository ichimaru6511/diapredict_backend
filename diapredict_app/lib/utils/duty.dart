import 'package:cloud_firestore/cloud_firestore.dart';

// Doctors on duty.
// Each doctor has a small document in doctorDirectory/{uid}:
//   name     - doctor's name (shown to nurses when referring)
//   dutyDate - the date the doctor marked "On duty today", e.g. '2026-10-23'
// Nurses cannot read the users collection, so this collection only holds
// what they need to pick a doctor.
// Because the date is stored, a doctor is automatically "off duty" the next day.

CollectionReference<Map<String, dynamic>> get doctorDirectory =>
    FirebaseFirestore.instance.collection('doctorDirectory');

// today's date as text, e.g. '2026-10-23'
String todayKey() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}
