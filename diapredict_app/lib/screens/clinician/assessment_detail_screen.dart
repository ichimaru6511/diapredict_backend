import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';
import '../../utils/assessment_labels.dart';
import '../../widgets/label_chip.dart';

// Shows a saved assessment. Inputs and prediction cannot be edited.
// Nurse: edit notes. Creator: mark as "entered in error".
// (Flagging and doctor review are added in the next step.)
class AssessmentDetailScreen extends StatefulWidget {
  final String patientId;
  final String assessmentId;
  final String role;

  const AssessmentDetailScreen({
    super.key,
    required this.patientId,
    required this.assessmentId,
    required this.role,
  });

  @override
  State<AssessmentDetailScreen> createState() => _AssessmentDetailScreenState();
}

class _AssessmentDetailScreenState extends State<AssessmentDetailScreen> {
  bool _busy = false;

  late final DocumentReference<Map<String, dynamic>> _ref = FirebaseFirestore
      .instance
      .collection('patients')
      .doc(widget.patientId)
      .collection('assessments')
      .doc(widget.assessmentId);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // asks for some text in a dialog; returns null if cancelled
  Future<String?> _askText({
    required String title,
    required String label,
    required String initial,
    required String action,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(action),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _update(Map<String, dynamic> changes, String doneMessage) async {
    setState(() => _busy = true);
    try {
      await _ref.update(changes);
      _showMessage(doneMessage);
    } on FirebaseException catch (e) {
      _showMessage('Could not update the assessment (${e.code}).');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editNurseNotes(String current) async {
    final text = await _askText(
      title: 'Assessment Notes',
      label: 'Notes',
      initial: current,
      action: 'Save',
    );
    if (text == null) return;
    await _update({'nurseNotes': text}, 'Notes saved.');
  }

  Future<void> _markEnteredInError() async {
    final reason = await _askText(
      title: 'Mark as entered in error?',
      label: 'Reason (required)',
      initial: '',
      action: 'Confirm',
    );
    if (reason == null) return;
    if (reason.isEmpty) {
      _showMessage('Please give a reason.');
      return;
    }
    await _update({
      'enteredInError': true,
      'errorReason': reason,
      'errorMarkedAt': FieldValue.serverTimestamp(),
    }, 'Assessment marked as entered in error.');
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Assessment Details')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _ref.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load assessment.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data();
          if (data == null) {
            return const Center(child: Text('Assessment not found.'));
          }

          final inputs = Map<String, dynamic>.from(data['inputs'] ?? {});
          final probability = (data['probability'] as num?)?.toDouble() ?? 0;
          final predictedClass = (data['predictedClass'] ?? '-').toString();
          final threshold = (data['threshold'] as num?)?.toDouble() ?? 0.5;
          final warnings = List<String>.from(data['warnings'] ?? []);
          final inError = data['enteredInError'] == true;
          final reviewStatus = (data['reviewStatus'] ?? 'none').toString();
          final nurseNotes = (data['nurseNotes'] ?? '').toString();
          final doctorNotes = (data['doctorNotes'] ?? '').toString();
          final isCreator = data['createdBy'] == myUid;
          final color = predictionColor(predictedClass);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // entered in error banner
              if (inError)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: AppColors.danger.withValues(alpha: 0.15),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.report_outlined,
                                color: AppColors.danger),
                            SizedBox(width: 8),
                            Text('Marked as entered in error',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.danger)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Reason: ${data['errorReason'] ?? '-'}'),
                        Text('Marked on ${formatDateTime(data['errorMarkedAt'])}',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ),

              // prediction result
              _section('Prediction Result', [
                Text(
                  '${probability.toStringAsFixed(1)}%',
                  style: TextStyle(
                      fontSize: 40, fontWeight: FontWeight.bold, color: color),
                ),
                const Text('Predicted probability of diabetes',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Predicted class: '),
                    LabelChip(text: predictedClass, color: color),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Model: ${data['modelVersion'] ?? '-'} • threshold '
                  '${(threshold * 100).toStringAsFixed(0)}%. '
                  'Model prediction, not a confirmed diagnosis.',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
              ]),

              // inputs
              _section('Inputs Used', [
                for (final key in featureOrder)
                  _row(featureLabels[key]!, featureValue(key, inputs[key])),
              ]),

              if (warnings.isNotEmpty)
                _section('Warnings', [
                  for (final w in warnings) Text('• $w'),
                ]),

              // who and when
              _section('Assessment Information', [
                _row('Assessed by',
                    '${data['createdByName'] ?? '-'} (${data['createdByRole'] ?? '-'})'),
                _row('Date', formatDateTime(data['createdAt'])),
              ]),

              // nurse notes
              _section('Assessment Notes', [
                Text(nurseNotes.isEmpty ? 'No notes.' : nurseNotes,
                    style: TextStyle(
                        color: nurseNotes.isEmpty
                            ? AppColors.textSecondary
                            : null)),
                if (widget.role == 'nurse' && !inError) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed:
                          _busy ? null : () => _editNurseNotes(nurseNotes),
                      icon: const Icon(Icons.edit_note),
                      label: Text(nurseNotes.isEmpty ? 'Add Notes' : 'Edit Notes'),
                    ),
                  ),
                ],
              ]),

              // review status (flagging and review actions come next)
              _section('Doctor Review', [
                Row(
                  children: [
                    const Text('Status: '),
                    LabelChip(
                      text: reviewStatusLabel(reviewStatus),
                      color: reviewStatusColor(reviewStatus),
                    ),
                  ],
                ),
                if (doctorNotes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(doctorNotes),
                ],
              ]),

              // creator can mark the assessment as entered in error
              if (isCreator && !inError) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _markEnteredInError,
                    icon: const Icon(Icons.report_outlined),
                    label: const Text('Mark as Entered in Error'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Saved inputs and results cannot be edited. If a value was '
                  'entered incorrectly, mark this assessment as entered in '
                  'error and create a new assessment.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
