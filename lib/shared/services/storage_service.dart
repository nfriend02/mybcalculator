import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

/// Firebase Storage upload helper (used by Upload feature / UploadPage).
class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;
  final _uuid = const Uuid();

  /// Uploads bytes and returns the download URL.
  Future<String> uploadBytes({
    required String folder,
    required String fileName,
    required Uint8List bytes,
    String contentType = 'application/octet-stream',
  }) async {
    final id = _uuid.v4();
    final path = '$folder/$id-$fileName';
    final ref = _storage.ref().child(path);
    final meta = SettableMetadata(contentType: contentType);
    await ref.putData(bytes, meta);
    return ref.getDownloadURL();
  }
}
