import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoredImageUpload {
  final String url;
  final String path;

  const StoredImageUpload({required this.url, required this.path});
}

class StorageService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> uploadImage({
    required XFile image,
    required String bucket,
    required String folder,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Please sign in again.');

    final extension = image.name.contains('.')
        ? image.name.split('.').last.toLowerCase()
        : 'jpg';
    final path =
        '$userId/$folder/${DateTime.now().microsecondsSinceEpoch}.$extension';
    final bytes = await image.readAsBytes();

    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: image.mimeType ?? 'image/jpeg',
            upsert: false,
          ),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  Future<StoredImageUpload> uploadBytes({
    required Uint8List bytes,
    required String bucket,
    required String folder,
    required String extension,
    required String contentType,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Please sign in again.');
    final path =
        '$userId/$folder/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    return StoredImageUpload(
      url: _client.storage.from(bucket).getPublicUrl(path),
      path: path,
    );
  }

  Future<void> removeFiles(String bucket, List<String> paths) async {
    if (paths.isEmpty) return;
    await _client.storage.from(bucket).remove(paths);
  }
}
