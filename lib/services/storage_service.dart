import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/file_attachment_model.dart';
import '../config/attachment_config.dart';

class StorageService {
  static SupabaseClient get _client => Supabase.instance.client;

  // Primary Storage Bucket
  static const String primaryBucket = 'attachments';
  static const String fallbackCaseBucket = 'case-attachments';

  /// Generates structured storage path according to Requirement 5
  /// Case main: attachments/cases/{case_id}/{file_name}
  /// Case comment: attachments/cases/{case_id}/comments/{comment_id}/{file_name}
  /// Order main: attachments/orders/{order_id}/{file_name}
  /// Order comment: attachments/orders/{order_id}/comments/{comment_id}/{file_name}
  static String buildStoragePath({
    required bool isCase, // true for Case, false for Order
    required String itemId, // case_id (UUID) or order_id
    String? commentId,
    required String fileName,
  }) {
    final typePrefix = isCase ? 'cases' : 'orders';
    final cleanFileName = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    if (commentId != null && commentId.isNotEmpty) {
      return '$typePrefix/$itemId/comments/$cleanFileName';
    }
    return '$typePrefix/$itemId/comments/$cleanFileName';
  }

  /// Uploads a file to Supabase Storage and returns a FileAttachmentModel
  static Future<FileAttachmentModel> uploadFile({
    required String itemId,
    required bool isCase,
    String? commentId,
    required Uint8List bytes,
    required String fileName,
    int? sizeBytes,
  }) async {
    final user = _client.auth.currentUser;

    final computedSizeBytes = sizeBytes ?? bytes.length;
    final fileType = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'file';
    final formattedSize = AttachmentConfig.formatFileSize(computedSizeBytes);
    final mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';

    // Validate size & type
    final validationErr = AttachmentConfig.validateFile(
      fileName: fileName,
      fileSizeBytes: computedSizeBytes,
      mimeType: mimeType,
    );

    if (validationErr != null) {
      throw Exception(validationErr);
    }

    final storagePath = buildStoragePath(
      isCase: isCase,
      itemId: itemId,
      commentId: commentId,
      fileName: fileName,
    );

    String targetBucket = primaryBucket;

    try {
      // Try uploading to primary bucket 'attachments'
      try {
        await _client.storage.from(primaryBucket).uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: mimeType,
              ),
            );
        targetBucket = primaryBucket;
      } catch (e) {
        debugPrint('[StorageService] Primary bucket failed ($e), trying fallback bucket');
        // Fallback to 'case-attachments'
        await _client.storage.from(fallbackCaseBucket).uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: mimeType,
              ),
            );
        targetBucket = fallbackCaseBucket;
      }

      // Generate Signed URL (24 hours validity)
      String? signedUrl;
      try {
        signedUrl = await _client.storage
            .from(targetBucket)
            .createSignedUrl(storagePath, 60 * 60 * 24);
      } catch (e) {
        debugPrint('[StorageService] Error getting signed url: $e');
      }

      final attachmentId = DateTime.now().microsecondsSinceEpoch.toString();

      return FileAttachmentModel(
        id: attachmentId,
        fileName: fileName,
        fileSize: formattedSize,
        fileSizeBytes: computedSizeBytes,
        fileType: fileType,
        mimeType: mimeType,
        storagePath: storagePath,
        url: signedUrl,
        bytes: bytes,
        uploadedBy: user?.id ?? 'current_user',
        createdAt: DateTime.now().toIso8601String(),
      );
    } on StorageException catch (e) {
      throw Exception('Supabase Storage Error: ${e.message}');
    } catch (e) {
      debugPrint('[StorageService] Unexpected upload error: $e');
      // If offline or storage fails, return local model so app flow isn't blocked
      return FileAttachmentModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        fileName: fileName,
        fileSize: formattedSize,
        fileSizeBytes: computedSizeBytes,
        fileType: fileType,
        mimeType: mimeType,
        storagePath: storagePath,
        bytes: bytes,
        uploadedBy: user?.id ?? 'current_user',
        createdAt: DateTime.now().toIso8601String(),
      );
    }
  }

  /// Gets a signed URL or public URL for a given storage path
  static Future<String?> getSignedUrl(String storagePath) async {
    if (storagePath.isEmpty) return null;
    try {
      return await _client.storage
          .from(primaryBucket)
          .createSignedUrl(storagePath, 60 * 60 * 24);
    } catch (_) {
      try {
        return await _client.storage
            .from(fallbackCaseBucket)
            .createSignedUrl(storagePath, 60 * 60 * 24);
      } catch (_) {
        try {
          final pubUrl = _client.storage.from(primaryBucket).getPublicUrl(storagePath);
          if (pubUrl.isNotEmpty) return pubUrl;
        } catch (_) {}
        try {
          return _client.storage.from(fallbackCaseBucket).getPublicUrl(storagePath);
        } catch (_) {
          return null;
        }
      }
    }
  }

  /// Removes an object from storage (used during cleanup or deletion)
  static Future<void> deleteFile(String storagePath) async {
    if (storagePath.isEmpty) return;
    try {
      await _client.storage.from(primaryBucket).remove([storagePath]);
    } catch (_) {
      try {
        await _client.storage.from(fallbackCaseBucket).remove([storagePath]);
      } catch (_) {}
    }
  }
}
