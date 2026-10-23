import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Keeps the signed-in Doctor/Nurse's in-app notifications up to date.
//   Doctor: notifications sent to all doctors (recipientRole == 'doctor'),
//           e.g. "Nurse X flagged an assessment for review", and
//           notifications sent to them only (recipientUid == their uid),
//           e.g. "Nurse X referred an assessment to you"
//   Nurse:  notifications sent to them (recipientUid == their uid),
//           e.g. "Doctor Y reviewed the assessment you flagged"
// Each notification stores the uids of users who have read it (readBy).
class NotificationCenter {
  static final ValueNotifier<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      items = ValueNotifier([]);
  static final ValueNotifier<int> unread = ValueNotifier(0);

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _mySub;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _roleSub;
  static List<QueryDocumentSnapshot<Map<String, dynamic>>> _myDocs = [];
  static List<QueryDocumentSnapshot<Map<String, dynamic>>> _roleDocs = [];
  static String _uid = '';

  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('notifications');

  static bool isRead(Map<String, dynamic> data) {
    final readBy = List<String>.from(data['readBy'] ?? []);
    return readBy.contains(_uid);
  }

  // joins both lists, newest first, and updates the unread count
  static void _publish() {
    final docs = [..._myDocs, ..._roleDocs];
    docs.sort((a, b) {
      final ta = a.data()['createdAt'];
      final tb = b.data()['createdAt'];
      if (ta is! Timestamp || tb is! Timestamp) return 0;
      return tb.compareTo(ta);
    });
    items.value = docs;
    unread.value = docs.where((d) => !isRead(d.data())).length;
  }

  // listens to one query; onNew is called for notifications that arrive
  // while the app is open (used to show a pop-up banner)
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>> _listen(
    Query<Map<String, dynamic>> query,
    void Function(List<QueryDocumentSnapshot<Map<String, dynamic>>>) save,
    void Function(String id, Map<String, dynamic> data) onNew,
  ) {
    bool firstLoad = true;
    return query.snapshots().listen(
      (snapshot) {
        save(snapshot.docs.toList());
        _publish();

        // pop-up only for new notifications after the first load
        if (!firstLoad) {
          for (final change in snapshot.docChanges) {
            final data = change.doc.data();
            if (change.type == DocumentChangeType.added &&
                data != null &&
                data['createdBy'] != _uid &&
                !isRead(data)) {
              onNew(change.doc.id, data);
            }
          }
        }
        firstLoad = false;
      },
      onError: (e) => debugPrint('Notifications error: $e'),
    );
  }

  static void start({
    required String uid,
    required String role,
    required void Function(String id, Map<String, dynamic> data) onNew,
  }) {
    stop();
    _uid = uid;

    // everyone: notifications sent to me
    _mySub = _listen(
      _collection.where('recipientUid', isEqualTo: uid),
      (docs) => _myDocs = docs,
      onNew,
    );

    // doctors also: notifications sent to all doctors
    if (role == 'doctor') {
      _roleSub = _listen(
        _collection.where('recipientRole', isEqualTo: 'doctor'),
        (docs) => _roleDocs = docs,
        onNew,
      );
    }
  }

  static void stop() {
    _mySub?.cancel();
    _roleSub?.cancel();
    _mySub = null;
    _roleSub = null;
    _myDocs = [];
    _roleDocs = [];
    items.value = [];
    unread.value = 0;
  }

  static Future<void> markRead(String id) async {
    await _collection.doc(id).update({
      'readBy': FieldValue.arrayUnion([_uid]),
    });
  }

  static Future<void> markAllRead() async {
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in items.value) {
      if (!isRead(doc.data())) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([_uid]),
        });
      }
    }
    await batch.commit();
  }
}
