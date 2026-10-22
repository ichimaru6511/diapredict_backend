import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';
import '../../utils/user_labels.dart';
import '../../utils/assessment_labels.dart';
import '../../widgets/label_chip.dart';
import 'patient_form_screen.dart';
import 'new_assessment_screen.dart';
import 'assessment_detail_screen.dart';

class PatientDetailScreen extends StatelessWidget {
  final String patientId;
  final String role;

  const PatientDetailScreen({
    super.key,
    required this.patientId,
    required this.role,
  });

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
    final patientRef =
        FirebaseFirestore.instance.collection('patients').doc(patientId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: patientRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Unable to load patient.')),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final data = snapshot.data!.data();
        if (data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Patient not found.')),
          );
        }

        final name = (data['name'] ?? '-').toString();
        final phone = (data['phone'] ?? '').toString();
        final createdByName = (data['createdByName'] ?? '').toString();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Patient Details'),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit patient',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PatientFormScreen(
                        role: role,
                        patientId: patientId,
                        initialData: data,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // patient header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.surfaceLight,
                        child: Icon(Icons.person_outline,
                            color: AppColors.primary, size: 28),
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
                            Text('MRN: ${data['mrn'] ?? '-'}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // patient information
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Patient Information',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      _infoRow(Icons.cake_outlined, 'Age',
                          '${data['age'] ?? '-'} years'),
                      _infoRow(Icons.wc, 'Gender',
                          (data['gender'] ?? '-').toString()),
                      _infoRow(Icons.phone_outlined, 'Phone Number',
                          phone.isEmpty ? 'Not provided' : phone),
                      _infoRow(
                        Icons.event_outlined,
                        'Registered',
                        createdByName.isEmpty
                            ? formatDate(data['createdAt'])
                            : '${formatDate(data['createdAt'])} by $createdByName',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // new assessment
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NewAssessmentScreen(
                          patientId: patientId,
                          patientName: name,
                          role: role,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_chart),
                  label: const Text('New Assessment',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),

              // assessment history
              const Text('Assessment History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _AssessmentHistory(patientId: patientId, role: role),
            ],
          ),
        );
      },
    );
  }
}

// List of this patient's assessments, newest first
class _AssessmentHistory extends StatelessWidget {
  final String patientId;
  final String role;

  const _AssessmentHistory({required this.patientId, required this.role});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .collection('assessments')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Unable to load assessments.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No assessments yet. Tap "New Assessment" to run the '
                'diabetes prediction.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final doc in docs)
              _AssessmentTile(
                data: doc.data(),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AssessmentDetailScreen(
                        patientId: patientId,
                        assessmentId: doc.id,
                        role: role,
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _AssessmentTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _AssessmentTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final probability = (data['probability'] as num?)?.toDouble() ?? 0;
    final predictedClass = (data['predictedClass'] ?? '-').toString();
    final reviewStatus = (data['reviewStatus'] ?? 'none').toString();
    final inError = data['enteredInError'] == true;
    final color = predictionColor(predictedClass);

    return Opacity(
      // assessments entered in error are shown faded
      opacity: inError ? 0.5 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  '${probability.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(predictedClass,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${formatDateTime(data['createdAt'])} • '
                        '${data['createdByName'] ?? '-'}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (inError)
                            const LabelChip(
                                text: 'Entered in error',
                                color: AppColors.danger),
                          if (reviewStatus != 'none')
                            LabelChip(
                              text: reviewStatusLabel(reviewStatus),
                              color: reviewStatusColor(reviewStatus),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
