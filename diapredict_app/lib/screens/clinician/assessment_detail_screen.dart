import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';
import '../../utils/assessment_labels.dart';
import '../../utils/duty.dart';
import '../../widgets/label_chip.dart';

// Shows a saved assessment. Inputs and prediction cannot be edited.
//   Nurse:   edit notes, flag for doctor review (optionally refer to a doctor
//            on duty today), remove own flag (while pending)
//   Doctor:  review a flagged assessment and mark it as reviewed
//   Creator: mark the assessment as "entered in error" (cannot be undone)
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

  User get _me => FirebaseAuth.instance.currentUser!;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ---------- dialogs ----------

  // asks for some text; returns null if cancelled
  Future<String?> _askText({
    required String title,
    required String label,
    required String initial,
    required String action,
    String? helper,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (helper != null) ...[
              Text(helper,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(labelText: label),
            ),
          ],
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

  Future<void> _update(Map<String, dynamic> changes, String doneMessage) async {
    setState(() => _busy = true);
    try {
      await _ref.update(changes);
      _showMessage(doneMessage);
    } on FirebaseException catch (e) {
      _showMessage(_errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // writes the assessment change and a notification together
  // (a batch: either both are saved or neither is)
  Future<void> _updateWithNotification(Map<String, dynamic> changes,
      Map<String, dynamic> notification, String doneMessage) async {
    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.update(_ref, changes);
      batch.set(db.collection('notifications').doc(), notification);
      await batch.commit();
      _showMessage(doneMessage);
    } on FirebaseException catch (e) {
      _showMessage(_errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _errorText(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return 'This action is no longer allowed. The assessment may have '
          'been changed by another user.';
    }
    return 'Could not update the assessment (${e.code}).';
  }

  // reads the latest copy of the assessment from the server before an
  // action, in case another user changed it while this screen was open.
  // (the Firestore rules are the real protection; this check just gives
  // a clearer message)
  Future<Map<String, dynamic>?> _latest() async {
    try {
      final doc = await _ref.get(const GetOptions(source: Source.server));
      return doc.data();
    } on FirebaseException catch (e) {
      _showMessage('Could not check the latest status (${e.code}).');
      return null;
    }
  }

  Future<String> _patientName() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.patientId)
          .get();
      return (doc.data()?['name'] ?? 'a patient').toString();
    } catch (_) {
      return 'a patient';
    }
  }

  // the notification document (fields must match the Firestore rules)
  Map<String, dynamic> _notification({
    required String type,
    required String recipientRole,
    required String recipientUid,
    required String patientName,
    required Map<String, dynamic> data,
    required String message,
  }) {
    return {
      'type': type,
      'recipientRole': recipientRole, // 'doctor' = all doctors
      'recipientUid': recipientUid, // one specific nurse
      'patientId': widget.patientId,
      'patientName': patientName,
      'assessmentId': widget.assessmentId,
      'probability': data['probability'],
      'predictedClass': data['predictedClass'],
      'message': message,
      'createdBy': _me.uid,
      'createdByName': _me.displayName ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': <String>[],
    };
  }

  // ---------- nurse actions ----------

  Future<void> _editNurseNotes(String current) async {
    final text = await _askText(
      title: 'Assessment Notes',
      label: 'Notes',
      initial: current,
      action: 'Save',
    );
    if (text == null) return;
    // keep track of who last edited the shared notes
    await _update({
      'nurseNotes': text,
      'nurseNotesUpdatedBy': _me.uid,
      'nurseNotesUpdatedByName': _me.displayName ?? '',
      'nurseNotesUpdatedAt': FieldValue.serverTimestamp(),
    }, 'Notes saved.');
  }

  // Lets the nurse choose a doctor on duty today, or "Any doctor".
  // Returns {'uid': ..., 'name': ...} (uid '' = any doctor), or null if cancelled.
  Future<Map<String, String>?> _pickDoctor() async {
    List<Map<String, String>> doctors = [];
    try {
      final snapshot = await doctorDirectory
          .where('dutyDate', isEqualTo: todayKey())
          .get();
      for (final doc in snapshot.docs) {
        doctors.add({
          'uid': doc.id,
          'name': (doc.data()['name'] ?? 'Doctor').toString(),
        });
      }
      doctors.sort((a, b) => a['name']!.compareTo(b['name']!));
    } on FirebaseException catch (e) {
      debugPrint('Could not load doctors on duty: ${e.code}');
    }
    if (!mounted) return null;

    String selected = ''; // '' = any doctor
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Flag for Doctor Review'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Refer this assessment to a doctor on duty today, or send '
                  'it to all doctors. Any doctor can still review it.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  value: '',
                  groupValue: selected,
                  onChanged: (v) => setDialogState(() => selected = v!),
                  title: const Text('Any doctor'),
                  subtitle: const Text('All doctors are notified'),
                  contentPadding: EdgeInsets.zero,
                ),
                if (doctors.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('No doctor has marked "On duty today".',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ),
                for (final d in doctors)
                  RadioListTile<String>(
                    value: d['uid']!,
                    groupValue: selected,
                    onChanged: (v) => setDialogState(() => selected = v!),
                    title: Text(d['name']!),
                    subtitle: const Text('On duty today'),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Flag'),
            ),
          ],
        ),
      ),
    );
    if (result != true) return null;

    String name = '';
    for (final d in doctors) {
      if (d['uid'] == selected) name = d['name']!;
    }
    return {'uid': selected, 'name': name};
  }

  Future<void> _flag(Map<String, dynamic> data) async {
    final doctor = await _pickDoctor();
    if (doctor == null) return;

    final latest = await _latest();
    if (latest == null) return;
    if (latest['enteredInError'] == true) {
      _showMessage('This assessment was marked as entered in error.');
      return;
    }
    if ((latest['reviewStatus'] ?? 'none') != 'none') {
      _showMessage('This assessment has already been flagged.');
      return;
    }

    final patientName = await _patientName();
    final probability =
        ((data['probability'] as num?) ?? 0).toDouble().toStringAsFixed(1);
    final nurseName = _me.displayName ?? 'A nurse';
    final referred = doctor['uid']!.isNotEmpty;

    // flag the assessment and notify the chosen doctor (or all doctors)
    await _updateWithNotification(
      {
        'reviewStatus': 'pending_review',
        'flaggedBy': _me.uid,
        'flaggedByName': _me.displayName ?? '',
        'flaggedAt': FieldValue.serverTimestamp(),
        'referredTo': doctor['uid'], // '' = any doctor
        'referredToName': doctor['name'],
      },
      _notification(
        type: 'flagged',
        recipientRole: referred ? '' : 'doctor',
        recipientUid: referred ? doctor['uid']! : '',
        patientName: patientName,
        data: data,
        message: referred
            ? '$nurseName referred the assessment for $patientName '
                '($probability% - ${data['predictedClass']}) to you for review.'
            : '$nurseName flagged the assessment for $patientName '
                '($probability% - ${data['predictedClass']}) for doctor review.',
      ),
      referred
          ? 'Assessment referred to ${doctor['name']}.'
          : 'Assessment flagged for doctor review.',
    );
  }

  Future<void> _removeFlag() async {
    final ok = await _confirm(
      'Remove flag?',
      'This assessment will be removed from the Doctor Review Queue.',
      'Remove Flag',
    );
    if (!ok) return;

    final latest = await _latest();
    if (latest == null) return;
    if (latest['reviewStatus'] != 'pending_review') {
      _showMessage('The flag can no longer be removed because the '
          'assessment has already been reviewed.');
      return;
    }

    await _update({
      'reviewStatus': 'none',
      'flaggedBy': FieldValue.delete(),
      'flaggedByName': FieldValue.delete(),
      'flaggedAt': FieldValue.delete(),
      'referredTo': FieldValue.delete(),
      'referredToName': FieldValue.delete(),
    }, 'Flag removed.');
  }

  // ---------- doctor actions ----------

  Future<void> _review(Map<String, dynamic> data, String currentNotes) async {
    final notes = await _askText(
      title: 'Doctor Review',
      label: 'Review notes (required)',
      initial: currentNotes,
      action: 'Mark as Reviewed',
      helper: 'Record your review of this assessment, e.g. recommended '
          'follow-up or confirmatory testing.',
    );
    if (notes == null) return;
    if (notes.isEmpty) {
      _showMessage('Please enter your review notes.');
      return;
    }

    // the case may have changed while the dialog was open
    final latest = await _latest();
    if (latest == null) return;
    if (latest['enteredInError'] == true) {
      _showMessage('This assessment was marked as entered in error, '
          'so no review is needed.');
      return;
    }
    if (latest['reviewStatus'] == 'reviewed') {
      _showMessage('This assessment has already been reviewed by '
          '${latest['reviewedByName'] ?? 'another doctor'}.');
      return;
    }
    if (latest['reviewStatus'] != 'pending_review') {
      _showMessage('The nurse removed the flag, so this assessment no '
          'longer needs review.');
      return;
    }

    final changes = {
      'reviewStatus': 'reviewed',
      'doctorNotes': notes,
      'reviewedBy': _me.uid,
      'reviewedByName': _me.displayName ?? '',
      'reviewedAt': FieldValue.serverTimestamp(),
    };

    // notify the nurse who flagged the assessment
    final flaggedBy = (data['flaggedBy'] ?? '').toString();
    if (flaggedBy.isEmpty) {
      await _update(changes, 'Assessment marked as reviewed.');
      return;
    }
    final patientName = await _patientName();
    await _updateWithNotification(
      changes,
      _notification(
        type: 'reviewed',
        recipientRole: '',
        recipientUid: flaggedBy,
        patientName: patientName,
        data: data,
        message: '${_me.displayName ?? 'A doctor'} reviewed the assessment '
            'for $patientName that you flagged.',
      ),
      'Assessment marked as reviewed.',
    );
  }

  Future<void> _editReviewNotes(String current) async {
    final notes = await _askText(
      title: 'Edit Review Notes',
      label: 'Review notes',
      initial: current,
      action: 'Save',
    );
    if (notes == null) return;
    if (notes.isEmpty) {
      _showMessage('Review notes cannot be empty.');
      return;
    }
    await _update({'doctorNotes': notes}, 'Review notes updated.');
  }

  // ---------- creator action ----------

  Future<void> _markEnteredInError() async {
    final reason = await _askText(
      title: 'Mark as entered in error?',
      label: 'Reason (required)',
      initial: '',
      action: 'Confirm',
      helper: 'This cannot be undone. The assessment will stay in the '
          'history but will be marked as entered in error.',
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

  // ---------- layout helpers ----------

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

  Widget _fullButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool outlined = false,
    Color? color,
  }) {
    final callback = _busy ? null : onPressed;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: outlined
            ? OutlinedButton.icon(
                onPressed: callback,
                icon: Icon(icon),
                label: Text(label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color ?? AppColors.primary,
                  side: BorderSide(color: color ?? AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              )
            : FilledButton.icon(
                onPressed: callback,
                icon: Icon(icon),
                label: Text(label),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _me.uid;
    final isNurse = widget.role == 'nurse';
    final isDoctor = widget.role == 'doctor';

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
          // notes typed when saving belong to the creator
          final notesBy = (data['nurseNotesUpdatedByName'] ??
                  data['createdByName'] ??
                  '-')
              .toString();
          final notesAt = data['nurseNotesUpdatedAt'] ?? data['createdAt'];
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
                if (nurseNotes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Last updated by $notesBy • ${formatDateTime(notesAt)}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                if (isNurse && !inError)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed:
                          _busy ? null : () => _editNurseNotes(nurseNotes),
                      icon: const Icon(Icons.edit_note),
                      label:
                          Text(nurseNotes.isEmpty ? 'Add Notes' : 'Edit Notes'),
                    ),
                  ),
              ]),

              // doctor review
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
                if (reviewStatus != 'none') ...[
                  const SizedBox(height: 8),
                  _row('Flagged by', (data['flaggedByName'] ?? '-').toString()),
                  _row('Flagged on', formatDateTime(data['flaggedAt'])),
                  _row(
                      'Referred to',
                      (data['referredToName'] ?? '').toString().isEmpty
                          ? 'Any doctor'
                          : data['referredToName'].toString()),
                ],
                if (reviewStatus == 'reviewed') ...[
                  _row('Reviewed by',
                      (data['reviewedByName'] ?? '-').toString()),
                  _row('Reviewed on', formatDateTime(data['reviewedAt'])),
                  const SizedBox(height: 8),
                  const Text('Review notes',
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(doctorNotes.isEmpty ? '-' : doctorNotes),
                ],

                // nurse: flag / remove flag
                if (isNurse && !inError && reviewStatus == 'none')
                  _fullButton(
                    label: 'Flag for Doctor Review',
                    icon: Icons.flag_outlined,
                    onPressed: () => _flag(data),
                  ),
                if (isNurse &&
                    reviewStatus == 'pending_review' &&
                    data['flaggedBy'] == myUid)
                  _fullButton(
                    label: 'Remove Flag',
                    icon: Icons.outlined_flag,
                    onPressed: _removeFlag,
                    outlined: true,
                  ),

                // doctor: review
                if (isDoctor && reviewStatus == 'pending_review' && !inError)
                  _fullButton(
                    label: 'Review & Mark as Reviewed',
                    icon: Icons.task_alt,
                    onPressed: () => _review(data, doctorNotes),
                  ),
                if (isDoctor &&
                    reviewStatus == 'reviewed' &&
                    data['reviewedBy'] == myUid)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed:
                          _busy ? null : () => _editReviewNotes(doctorNotes),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Edit Review Notes'),
                    ),
                  ),
                if (reviewStatus == 'pending_review' && inError)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'This assessment was marked as entered in error, '
                      'so no review is needed.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
              ]),

              // creator can mark the assessment as entered in error
              if (isCreator && !inError) ...[
                const SizedBox(height: 8),
                _fullButton(
                  label: 'Mark as Entered in Error',
                  icon: Icons.report_outlined,
                  onPressed: _markEnteredInError,
                  outlined: true,
                  color: AppColors.danger,
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
