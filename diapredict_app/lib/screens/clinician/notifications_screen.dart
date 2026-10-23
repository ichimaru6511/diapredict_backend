import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/notification_center.dart';
import '../../theme/app_theme.dart';
import '../../utils/assessment_labels.dart';
import '../../widgets/label_chip.dart';
import 'assessment_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  final String role;

  const NotificationsScreen({super.key, required this.role});

  void _open(BuildContext context, String id, Map<String, dynamic> data) {
    NotificationCenter.markRead(id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssessmentDetailScreen(
          patientId: data['patientId'],
          assessmentId: data['assessmentId'],
          role: role,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: NotificationCenter.unread,
            builder: (context, count, _) => TextButton(
              onPressed: count == 0
                  ? null
                  : () async {
                      try {
                        await NotificationCenter.markAllRead();
                      } on FirebaseException catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not update (${e.code}).')),
                          );
                        }
                      }
                    },
              child: const Text('Mark all read'),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<
          List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        valueListenable: NotificationCenter.items,
        builder: (context, docs, _) {
          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none,
                      size: 64, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text('No notifications yet',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final read = NotificationCenter.isRead(data);
              final flagged = data['type'] == 'flagged';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                // unread notifications are highlighted
                color: read
                    ? AppColors.surface
                    : AppColors.primary.withValues(alpha: 0.18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _open(context, docs[i].id, data),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.surfaceLight,
                          child: Icon(
                            flagged ? Icons.flag_outlined : Icons.task_alt,
                            color: flagged
                                ? AppColors.danger
                                : AppColors.accentGreen,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                flagged ? 'Flagged for review' : 'Assessment reviewed',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text((data['message'] ?? '').toString()),
                              // what has happened to the assessment since
                              _CurrentStatus(
                                patientId: (data['patientId'] ?? '').toString(),
                                assessmentId:
                                    (data['assessmentId'] ?? '').toString(),
                                type: (data['type'] ?? '').toString(),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                formatDateTime(data['createdAt']),
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        if (!read)
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(top: 6, left: 8),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Shows the CURRENT status of the assessment a notification is about,
// because the notification text only describes what happened at that time.
//   - entered in error         -> red "Entered in error - no action needed"
//   - flag notification, but the case is now reviewed -> "Reviewed by X"
//   - flag notification, but the flag was removed     -> "Flag removed"
class _CurrentStatus extends StatelessWidget {
  final String patientId;
  final String assessmentId;
  final String type;

  const _CurrentStatus({
    required this.patientId,
    required this.assessmentId,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    if (patientId.isEmpty || assessmentId.isEmpty) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('patients')
          .doc(patientId)
          .collection('assessments')
          .doc(assessmentId)
          .snapshots(),
      builder: (context, snapshot) {
        final a = snapshot.data?.data();
        if (a == null) return const SizedBox.shrink();

        String text = '';
        Color color = AppColors.textSecondary;

        if (a['enteredInError'] == true) {
          text = 'Entered in error - no action needed';
          color = AppColors.danger;
        } else if (type == 'flagged' && a['reviewStatus'] == 'reviewed') {
          text = 'Reviewed by ${a['reviewedByName'] ?? '-'}';
          color = reviewStatusColor('reviewed');
        } else if (type == 'flagged' && a['reviewStatus'] == 'none') {
          text = 'Flag removed';
        }

        if (text.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: LabelChip(text: text, color: color),
        );
      },
    );
  }
}