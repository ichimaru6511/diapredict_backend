import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/prediction_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/assessment_labels.dart';
import '../../utils/user_labels.dart';

// Shows the model result before it is saved.
// Returns true to the previous screen if the assessment was saved.
class AssessmentResultScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String role;
  final Map<String, num> inputs;
  final PredictionResult result;

  const AssessmentResultScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.role,
    required this.inputs,
    required this.result,
  });

  @override
  State<AssessmentResultScreen> createState() => _AssessmentResultScreenState();
}

class _AssessmentResultScreenState extends State<AssessmentResultScreen> {
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

      // pop-up asking the user to double-check the inputs before saving,
  // because saved inputs and predictions cannot be edited later
  Future<bool> _confirmSave() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        // red border to draw attention
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.danger, width: 2),
        ),
        icon: const Icon(Icons.warning_amber_rounded,
            color: AppColors.danger, size: 44),
        title: const Text(
          'Check Before Saving',
          style: TextStyle(
            color: AppColors.danger,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient: ${widget.patientName}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              for (final key in featureOrder)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(featureLabels[key]!,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ),
                      Text(featureValue(key, widget.inputs[key]),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // red warning box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'Once saved, the inputs and prediction CANNOT be edited. '
                  'Please make sure every value is correct before saving.',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm & Save'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _save() async {
    // ask the user to double-check before anything is saved
    final confirmed = await _confirmSave();
    if (!confirmed) return;

    setState(() => _saving = true);
    final user = FirebaseAuth.instance.currentUser!;
    final r = widget.result;

    // inputs and prediction are saved together and are not edited later
    final data = <String, dynamic>{
      'inputs': widget.inputs,
      'probability': r.probability,
      'predictedClass': r.prediction,
      'threshold': r.threshold,
      'warnings': r.warnings,
      'modelVersion': PredictionService.modelVersion,
      'createdBy': user.uid,
      'createdByName': user.displayName ?? '',
      'createdByRole': widget.role,
      'createdAt': FieldValue.serverTimestamp(),
      'nurseNotes': widget.role == 'nurse' ? _notesController.text.trim() : '',
      'reviewStatus': 'none',
      'enteredInError': false,
    };

    try {
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.patientId)
          .collection('assessments')
          .add(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assessment saved.')),
      );
      Navigator.pop(context, true);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save assessment (${e.code}).')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final color = predictionColor(r.prediction);

    return Scaffold(
      appBar: AppBar(title: const Text('Prediction Result')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // main result
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.patientName,
                        style:
                            const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    const Text('Predicted probability of diabetes'),
                    const SizedBox(height: 4),
                    Text(
                      '${r.probability.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: r.probability / 100,
                        minHeight: 10,
                        color: color,
                        backgroundColor: AppColors.surfaceLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Predicted class: '),
                        Text(
                          r.prediction,
                          style: TextStyle(
                              color: color, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Model prediction (Random Forest, threshold '
                      '${(r.threshold * 100).toStringAsFixed(0)}%). '
                      'This is not a confirmed diagnosis.',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // warnings from the backend (e.g. value outside training range)
            if (r.warnings.isNotEmpty) ...[
              Card(
                color: pendingColor.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: pendingColor),
                          SizedBox(width: 8),
                          Text('Please note',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final w in r.warnings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $w'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // inputs used
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Inputs Used',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    for (final key in featureOrder)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(featureLabels[key]!,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary)),
                            ),
                            Text(featureValue(key, widget.inputs[key]),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // disclaimer
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(r.disclaimer,
                          style: const TextStyle(
                              color: AppColors.textSecondary, height: 1.4)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // nurse notes (optional)
            if (widget.role == 'nurse') ...[
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Assessment notes (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
            ],

            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save Assessment',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: const Text('Back without saving'),
            ),
          ],
        ),
      ),
    );
  }
}
