import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_theme.dart';
import '../../utils/assessment_labels.dart';
import '../../widgets/label_chip.dart';
import '../../widgets/notification_bell.dart';
import 'assessment_detail_screen.dart';

// Doctor only: assessments flagged by nurses (Pending) and those already
// reviewed (Reviewed), across all patients.
class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({super.key});

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  String _view = 'pending_review'; // or 'reviewed'
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  // collectionGroup = search the "assessments" subcollection of every patient
  void _listen() {
    _stream = FirebaseFirestore.instance
        .collectionGroup('assessments')
        .where('reviewStatus', isEqualTo: _view)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Queue'),
        actions: const [NotificationBell(role: 'doctor')],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'pending_review',
                    label: Text('Pending'),
                    icon: Icon(Icons.flag_outlined),
                  ),
                  ButtonSegment(
                    value: 'reviewed',
                    label: Text('Reviewed'),
                    icon: Icon(Icons.task_alt),
                  ),
                ],
                selected: {_view},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() {
                    _view = selection.first;
                    _listen();
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  // if an index is missing, the full error (with a link to
                  // create it) is printed in the terminal
                  debugPrint('Review queue error: ${snapshot.error}');
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Unable to load the review queue.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs
                    // assessments entered in error do not need review
                    .where((d) =>
                        _view == 'reviewed' ||
                        d.data()['enteredInError'] != true)
                    .toList();

                // pending: cases referred to me first, then oldest flag first
                // reviewed: newest review first
                final myUid = FirebaseAuth.instance.currentUser!.uid;
                docs.sort((a, b) {
                  if (_view == 'pending_review') {
                    final aMine = a.data()['referredTo'] == myUid;
                    final bMine = b.data()['referredTo'] == myUid;
                    if (aMine && !bMine) return -1;
                    if (bMine && !aMine) return 1;
                  }
                  final field =
                      _view == 'pending_review' ? 'flaggedAt' : 'reviewedAt';
                  final ta = a.data()[field];
                  final tb = b.data()[field];
                  if (ta is! Timestamp || tb is! Timestamp) return 0;
                  return _view == 'pending_review'
                      ? ta.compareTo(tb)
                      : tb.compareTo(ta);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inbox_outlined,
                              size: 64, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            _view == 'pending_review'
                                ? 'No assessments waiting for review'
                                : 'No reviewed assessments yet',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: docs.length,
                  itemBuilder: (context, i) => _QueueTile(
                    key: ValueKey(docs[i].id),
                    doc: docs[i],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// One flagged/reviewed assessment, with the patient's name loaded separately
class _QueueTile extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _QueueTile({super.key, required this.doc});

  @override
  State<_QueueTile> createState() => _QueueTileState();
}

class _QueueTileState extends State<_QueueTile> {
  late final DocumentReference<Map<String, dynamic>> _patientRef;
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _patientFuture;

  @override
  void initState() {
    super.initState();
    // assessments are stored in patients/{patientId}/assessments/{id}
    _patientRef = widget.doc.reference.parent.parent!;
    _patientFuture = _patientRef.get();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data();
    final probability = (data['probability'] as num?)?.toDouble() ?? 0;
    final predictedClass = (data['predictedClass'] ?? '-').toString();
    final reviewStatus = (data['reviewStatus'] ?? 'none').toString();
    final nurseNotes = (data['nurseNotes'] ?? '').toString();
    final color = predictionColor(predictedClass);
    final referredTo = (data['referredTo'] ?? '').toString();
    final referredToName = (data['referredToName'] ?? '').toString();
    final referredToMe =
        referredTo.isNotEmpty &&
            referredTo == FirebaseAuth.instance.currentUser!.uid;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AssessmentDetailScreen(
                patientId: _patientRef.id,
                assessmentId: widget.doc.id,
                role: 'doctor',
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // patient name and MRN
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: _patientFuture,
                builder: (context, snap) {
                  final p = snap.data?.data();
                  final name = p == null ? 'Loading...' : '${p['name']}';
                  final mrn = p == null ? '' : 'MRN: ${p['mrn']}';
                  return Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16)),
                      ),
                      Text(mrn,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 10),

              // result
              Row(
                children: [
                  Text(
                    '${probability.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                  const SizedBox(width: 10),
                  LabelChip(text: predictedClass, color: color),
                  const Spacer(),
                  LabelChip(
                    text: reviewStatusLabel(reviewStatus),
                    color: reviewStatusColor(reviewStatus),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // who flagged / reviewed and when
              Text(
                reviewStatus == 'reviewed'
                    ? 'Reviewed by ${data['reviewedByName'] ?? '-'} • '
                        '${formatDateTime(data['reviewedAt'])}'
                    : 'Flagged by ${data['flaggedByName'] ?? '-'} • '
                        '${formatDateTime(data['flaggedAt'])}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
              if (referredTo.isNotEmpty) ...[
                const SizedBox(height: 6),
                referredToMe
                    ? const LabelChip(
                        text: 'Referred to you', color: AppColors.accentGreen)
                    : Text('Referred to $referredToName',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
              ],
              if (nurseNotes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Nurse notes: $nurseNotes',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
