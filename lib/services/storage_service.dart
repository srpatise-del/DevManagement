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

  static final RegExp _uuidRegExp = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Generates structured storage path according to Requirement 5
  /// Case main: cases/{case_id}/{file_name}
  /// Case comment: cases/{case_id}/comments/{comment_id}/{file_name} (or cases/{case_id}/comments/{file_name})
  /// Order main: orders/{order_id}/{file_name}
  /// Order comment: orders/{order_id}/comments/{comment_id}/{file_name}
  static String buildStoragePath({
    required bool isCase, // true for Case, false for Order
    required String itemId, // case_id (UUID) or order_id
    String? commentId,
    required String fileName,
  }) {
    final typePrefix = isCase ? 'cases' : 'orders';
    final cleanFileName = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    if (commentId != null && commentId.isNotEmpty) {
      if (_uuidRegExp.hasMatch(commentId)) {
        return '$typePrefix/$itemId/comments/$commentId/$cleanFileName';
      }
      return '$typePrefix/$itemId/comments/$cleanFileName';
    }
    return '$typePrefix/$itemId/$cleanFileName';
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

    final firstBucket = isCase ? fallbackCaseBucket : primaryBucket;
    final secondBucket = isCase ? primaryBucket : fallbackCaseBucket;
    String targetBucket = firstBucket;

    try {
      // Upload to preferred bucket ('case-attachments' for cases, 'attachments' for orders)
      try {
        await _client.storage.from(firstBucket).uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: mimeType,
              ),
            );
        targetBucket = firstBucket;
      } catch (e) {
        debugPrint('[StorageService] Bucket "$firstBucket" failed ($e), trying "$secondBucket"');
        await _client.storage.from(secondBucket).uploadBinary(
              storagePath,
              bytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: mimeType,
              ),
            );
        targetBucket = secondBucket;
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
    final preferCaseBucket = storagePath.startsWith('cases/');
    final firstBucket = preferCaseBucket ? fallbackCaseBucket : primaryBucket;
    final secondBucket = preferCaseBucket ? primaryBucket : fallbackCaseBucket;
    try {
      return await _client.storage
          .from(firstBucket)
          .createSignedUrl(storagePath, 60 * 60 * 24);
    } catch (_) {
      try {
        return await _client.storage
            .from(secondBucket)
            .createSignedUrl(storagePath, 60 * 60 * 24);
      } catch (_) {
        return null;
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
