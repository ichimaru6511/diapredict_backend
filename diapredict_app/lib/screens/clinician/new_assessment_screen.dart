import 'package:flutter/material.dart';

import '../../services/prediction_service.dart';
import '../../theme/app_theme.dart';
import 'assessment_result_screen.dart';

class NewAssessmentScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String role;

  const NewAssessmentScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.role,
  });

  @override
  State<NewAssessmentScreen> createState() => _NewAssessmentScreenState();
}

class _NewAssessmentScreenState extends State<NewAssessmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fbsController = TextEditingController();
  final _hba1cController = TextEditingController();

  // yes/no answers: null = not answered, 0 = No, 1 = Yes
  final Map<String, int?> _answers = {
    'FrequentUrination': null,
    'Hypertension': null,
    'ExcessiveThirst': null,
    'UnexplainedWeightLoss': null,
  };

  // [key, question, explanation]
  final List<List<String>> _questions = const [
    ['FrequentUrination', 'Frequent urination',
        'Passing urine more often than usual'],
    ['Hypertension', 'Hypertension', 'Diagnosed high blood pressure'],
    ['ExcessiveThirst', 'Excessive thirst', 'Feeling unusually thirsty'],
    ['UnexplainedWeightLoss', 'Unexplained weight loss',
        'Losing weight without trying'],
  ];

  bool _loading = false;
  bool _showAnswerErrors = false;

  @override
  void dispose() {
    _fbsController.dispose();
    _hba1cController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _runPrediction() async {
    final formOk = _formKey.currentState!.validate();
    final allAnswered = !_answers.values.contains(null);
    if (!allAnswered) setState(() => _showAnswerErrors = true);
    if (!formOk || !allAnswered) {
      _showMessage('Please complete all six inputs.');
      return;
    }

    // the six inputs, using the exact names the model expects
    final inputs = <String, num>{
      'FastingBloodSugar': double.parse(_fbsController.text.trim()),
      'HbA1c': double.parse(_hba1cController.text.trim()),
      'FrequentUrination': _answers['FrequentUrination']!,
      'Hypertension': _answers['Hypertension']!,
      'ExcessiveThirst': _answers['ExcessiveThirst']!,
      'UnexplainedWeightLoss': _answers['UnexplainedWeightLoss']!,
    };

    setState(() => _loading = true);
    PredictionResult result;
    try {
      result = await PredictionService.predict(inputs);
    } on PredictionException catch (e) {
      _showMessage(e.message);
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted) return;
    // show the result; returns true if the assessment was saved
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AssessmentResultScreen(
          patientId: widget.patientId,
          patientName: widget.patientName,
          role: widget.role,
          inputs: inputs,
          result: result,
        ),
      ),
    );
    if (saved == true && mounted) Navigator.pop(context);
  }

  Widget _yesNoQuestion(String key, String title, String subtitle) {
    final answer = _answers[key];
    final missing = _showAnswerErrors && answer == null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('No')),
                  ButtonSegment(value: 1, label: Text('Yes')),
                ],
                selected: answer == null ? <int>{} : {answer},
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() {
                    _answers[key] = selection.isEmpty ? null : selection.first;
                  });
                },
              ),
            ),
            if (missing)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Please select Yes or No',
                    style: TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Assessment')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // patient
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.person_outline,
                        color: AppColors.primary),
                    title: Text(widget.patientName),
                    subtitle: const Text('Diabetes prediction assessment'),
                  ),
                ),
                const SizedBox(height: 16),

                // laboratory results
                const Text('Laboratory Results',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fbsController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Fasting Blood Sugar',
                    suffixText: 'mg/dL',
                    prefixIcon: Icon(Icons.bloodtype_outlined),
                  ),
                  validator: (value) {
                    final v = double.tryParse(value?.trim() ?? '');
                    if (v == null) return 'Please enter a number';
                    if (v < 20 || v > 600) {
                      return 'Please enter a value between 20 and 600 mg/dL';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hba1cController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'HbA1c',
                    suffixText: '%',
                    prefixIcon: Icon(Icons.science_outlined),
                  ),
                  validator: (value) {
                    final v = double.tryParse(value?.trim() ?? '');
                    if (v == null) return 'Please enter a number';
                    if (v < 3 || v > 20) {
                      return 'Please enter a value between 3 and 20 %';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // symptoms and history
                const Text('Symptoms and Medical History',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                for (final q in _questions) _yesNoQuestion(q[0], q[1], q[2]),
                const SizedBox(height: 12),

                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _runPrediction,
                    icon: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.analytics_outlined),
                    label: Text(_loading ? 'Running prediction...' : 'Run Prediction',
                        style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The first prediction may take up to a minute while the '
                  'prediction server starts.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
