import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firestore CRUD service.
///
/// List queries avoid composite-index requirements by filtering on `status`
/// and sorting `createdAt` on the client.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _db.collection(path);

  /// Create a document. Auto-sets `createdAt` and default `status`.
  Future<DocumentReference<Map<String, dynamic>>> create({
    required String collectionPath,
    required Map<String, dynamic> data,
    String? docId,
    String status = 'active',
  }) async {
    final payload = <String, dynamic>{
      ...data,
      'status': data['status'] ?? status,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (docId != null && docId.isNotEmpty) {
      final ref = _db.collection(collectionPath).doc(docId);
      await ref.set(payload);
      return ref;
    }
    return _db.collection(collectionPath).add(payload);
  }

  Future<Map<String, dynamic>?> read({
    required String collectionPath,
    required String docId,
  }) async {
    final snap = await _db.collection(collectionPath).doc(docId).get();
    if (!snap.exists) return null;
    return {'id': snap.id, ...?snap.data()};
  }

  Future<void> update({
    required String collectionPath,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _db.collection(collectionPath).doc(docId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Soft-delete via `status: deleted` (keeps history for portfolio sync).
  Future<void> softDelete({
    required String collectionPath,
    required String docId,
  }) async {
    await update(
      collectionPath: collectionPath,
      docId: docId,
      data: {'status': 'deleted'},
    );
  }

  Future<void> hardDelete({
    required String collectionPath,
    required String docId,
  }) async {
    await _db.collection(collectionPath).doc(docId).delete();
  }

  /// List active documents. Client-sorts by createdAt (no composite index).
  Future<List<Map<String, dynamic>>> list({
    required String collectionPath,
    String status = 'active',
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db
          .collection(collectionPath)
          .where('status', isEqualTo: status)
          .limit(limit.clamp(1, 100));

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snap = await query.get();
      final rows =
          snap.docs.map((d) => <String, dynamic>{'id': d.id, ...d.data()}).toList();
      rows.sort((a, b) => _createdAtMs(b['createdAt']).compareTo(_createdAtMs(a['createdAt'])));
      return rows;
    } catch (e, st) {
      debugPrint('FirestoreService.list error: $e\n$st');
      try {
        final snap = await _db.collection(collectionPath).limit(100).get();
        final rows = snap.docs
            .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
            .where((d) => (d['status'] as String? ?? 'active') == status)
            .toList()
          ..sort(
            (a, b) =>
                _createdAtMs(b['createdAt']).compareTo(_createdAtMs(a['createdAt'])),
          );
        return rows.take(limit).toList();
      } catch (e2, st2) {
        debugPrint('FirestoreService.list fallback error: $e2\n$st2');
        rethrow;
      }
    }
  }

  Stream<List<Map<String, dynamic>>> watch({
    required String collectionPath,
    String status = 'active',
    int limit = 10,
  }) {
    return _db
        .collection(collectionPath)
        .where('status', isEqualTo: status)
        .limit(limit.clamp(1, 100))
        .snapshots()
        .map((snap) {
          final rows = snap.docs
              .map((d) => <String, dynamic>{'id': d.id, ...d.data()})
              .toList()
            ..sort(
              (a, b) => _createdAtMs(b['createdAt'])
                  .compareTo(_createdAtMs(a['createdAt'])),
            );
          return rows;
        });
  }

  static int _createdAtMs(dynamic value) {
    if (value == null) return 0;
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is String) {
      return DateTime.tryParse(value)?.millisecondsSinceEpoch ?? 0;
    }
    try {
      return (value as dynamic).millisecondsSinceEpoch as int;
    } catch (_) {
      return 0;
    }
  }
}
