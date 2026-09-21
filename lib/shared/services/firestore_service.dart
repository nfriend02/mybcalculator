import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firestore CRUD service.
///
/// Default indexes (see `firestore.indexes.json`): `createdAt`, `status`.
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
    final payload = {
      ...data,
      'status': data['status'] ?? status,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (docId != null) {
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

  /// List with default indexes: status + createdAt desc, page-sized.
  Future<List<Map<String, dynamic>>> list({
    required String collectionPath,
    String status = 'active',
    int limit = 10,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _db
        .collection(collectionPath)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    try {
      final snap = await query.get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e, st) {
      // Composite index may still be building — fall back to a simple query.
      debugPrint('FirestoreService.list error: $e\n$st');
      try {
        final snap = await _db
            .collection(collectionPath)
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
        return snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .where((d) => d['status'] == status)
            .toList();
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
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }
}
