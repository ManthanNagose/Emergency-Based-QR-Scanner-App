// StorageRepository - handles file uploads and signed URLs
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import '../core/supabase_client.dart';
import 'package:file_picker/file_picker.dart';

class StorageRepository {
  final SupabaseClient _client = SupabaseConfig.client;
  final Uuid _uuid = const Uuid();

  // Generate a unique storage path: {userId}/{uuid}.{ext}
  String _generatePath(String userId, String originalFileName) {
    final ext = path.extension(originalFileName).toLowerCase();
    final fileName = '${_uuid.v4()}$ext';
    return '$userId/$fileName';
  }

  // Upload a file to the specified bucket (mobile/desktop with file path)
  // Returns the storage path (e.g., "userId/uuid.ext")
  Future<String> uploadFile({
    required String bucket,
    required File file,
    required String userId,
  }) async {
    final storagePath = _generatePath(userId, file.path);
    
    await _client.storage.from(bucket).upload(
          storagePath,
          file,
          fileOptions: const FileOptions(upsert: false),
        );

    return storagePath;
  }

  // Upload a PlatformFile (cross-platform, works on web via bytes, mobile via path)
  Future<String> uploadPlatformFile({
    required String bucket,
    required PlatformFile file,
    required String userId,
  }) async {
    final storagePath = _generatePath(userId, file.name);
    
    // Read bytes from file
    final bytes = await _readPlatformFileBytes(file);
    
    await _client.storage.from(bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );

    return storagePath;
  }

  // Read bytes from PlatformFile (cross-platform)
  Future<Uint8List> _readPlatformFileBytes(PlatformFile file) async {
    // On mobile/desktop, read from path
    if (file.path != null) {
      return await File(file.path!).readAsBytes();
    }
    
    // On web with withReadStream, we'd use file.readStream
    // For now, throw if no path
    throw Exception('Cannot read file: no path available (web requires withReadStream)');
  }

  // Upload bytes (for web or when file is in memory)
  Future<String> uploadBytes({
    required String bucket,
    required Uint8List bytes,
    required String userId,
    required String fileName,
  }) async {
    final storagePath = _generatePath(userId, fileName);
    
    await _client.storage.from(bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );

    return storagePath;
  }

  // Get a signed URL for private buckets (expires in 10 minutes)
  Future<String> getSignedUrl({
    required String bucket,
    required String path,
    int expiresInSeconds = 600,
  }) async {
    return await _client.storage.from(bucket).createSignedUrl(
          path,
          expiresInSeconds,
        );
  }

  // Get public URL for profile-photos bucket
  String getPublicUrl({
    required String bucket,
    required String path,
  }) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  // Delete a file
  Future<void> deleteFile({
    required String bucket,
    required String path,
  }) async {
    await _client.storage.from(bucket).remove([path]);
  }

  // List files in a user's folder
  Future<List<FileObject>> listUserFiles({
    required String bucket,
    required String userId,
  }) async {
    return await _client.storage.from(bucket).list(path: userId);
  }
}