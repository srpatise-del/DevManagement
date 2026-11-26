import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/attachment_config.dart';
import '../models/file_attachment_model.dart';
import '../theme/app_theme.dart';
import 'full_screen_image_viewer.dart';

class PendingFileAttachment {
  final String name;
  final int sizeBytes;
  final String extension;
  final String? mimeType;
  final Uint8List? bytes;
  final String? path;

  PendingFileAttachment({
    required this.name,
    required this.sizeBytes,
    required this.extension,
    this.mimeType,
    this.bytes,
    this.path,
  });

  String get formattedSize => AttachmentConfig.formatFileSize(sizeBytes);
  bool get isImage => AttachmentConfig.isImage(extension);

  Future<Uint8List?> getBytes() async {
    if (bytes != null && bytes!.isNotEmpty) {
      return bytes;
    }
    if (!kIsWeb && path != null && path!.isNotEmpty) {
      try {
        final file = File(path!);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      } catch (e) {
        debugPrint('[PendingFileAttachment.getBytes] Error reading file: $e');
      }
    }
    return null;
  }
}

class AttachmentPickerWidget extends StatelessWidget {
  final List<PendingFileAttachment> pendingFiles;
  final ValueChanged<List<PendingFileAttachment>> onFilesChanged;
  final bool isUploading;
  final String? uploadProgressText;

  const AttachmentPickerWidget({
    super.key,
    required this.pendingFiles,
    required this.onFilesChanged,
    this.isUploading = false,
    this.uploadProgressText,
  });

  Future<void> _pickFiles(BuildContext context) async {
    if (pendingFiles.length >= AttachmentConfig.maxFileCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('แนบไฟล์ได้สูงสุด ${AttachmentConfig.maxFileCount} ไฟล์'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: AttachmentConfig.allAllowedExtensions.toList(),
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final List<PendingFileAttachment> newFiles = List.from(pendingFiles);
      final List<String> errors = [];

      for (var file in result.files) {
        if (newFiles.length >= AttachmentConfig.maxFileCount) {
          errors.add('เกินโควตาแนบไฟล์สูงสุด ${AttachmentConfig.maxFileCount} ไฟล์');
          break;
        }

        var fileName = file.name;
        final fileSize = file.size;
        var ext = AttachmentConfig.resolveExtension(
          fileName: fileName,
          fileExtension: file.extension,
        );

        if (!fileName.contains('.') && ext.isNotEmpty) {
          fileName = '$fileName.$ext';
        }

        // Validation
        final err = AttachmentConfig.validateFile(
          fileName: fileName,
          fileSizeBytes: fileSize,
          fileExtension: ext,
        );

        if (err != null) {
          errors.add(err);
          continue;
        }

        // Duplicate check
        if (newFiles.any((f) => f.name == fileName && f.sizeBytes == fileSize)) {
          continue;
        }

        newFiles.add(PendingFileAttachment(
          name: fileName,
          sizeBytes: fileSize,
          extension: ext,
          bytes: file.bytes,
          path: kIsWeb ? null : file.path,
        ));
      }

      if (errors.isNotEmpty && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errors.join('\n')),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      onFilesChanged(newFiles);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการเลือกไฟล์: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeFile(int index) {
    final updated = List<PendingFileAttachment>.from(pendingFiles)..removeAt(index);
    onFilesChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Add Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.attach_file, size: 18, color: AppColors.primary),
                SizedBox(width: 6),
                Text(
                  'แนบไฟล์ประกอบ (Attachments)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: isUploading ? null : () => _pickFiles(context),
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: Text('เลือกไฟล์ (${pendingFiles.length}/${AttachmentConfig.maxFileCount})'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Upload progress indicator if uploading
        if (isUploading) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    uploadProgressText ?? 'กำลังอัปโหลดไฟล์แนบ...',
                    style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // List of Pending Files
        if (pendingFiles.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cardBorder, style: BorderStyle.solid),
            ),
            child: const Column(
              children: [
                Icon(Icons.cloud_upload_outlined, size: 28, color: AppColors.textMuted),
                SizedBox(height: 4),
                Text(
                  'ยังไม่ได้เลือกไฟล์แนบ (รองรับรูปภาพ, PDF, Word, Excel, PPT, TXT, CSV สูงสุด 10MB)',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Column(
            children: List.generate(pendingFiles.length, (index) {
              final file = pendingFiles[index];
              final category = AttachmentConfig.getCategory(file.extension);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    // Preview thumbnail if image, else icon
                    if (file.isImage && file.bytes != null)
                      GestureDetector(
                        onTap: () => FullScreenImageViewer.show(
                          context,
                          imageBytes: file.bytes,
                          title: file.name,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.memory(
                            file.bytes!,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: category.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(category.icon, color: category.color, size: 22),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                category.label,
                                style: TextStyle(fontSize: 11, color: category.color, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                file.formattedSize,
                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!isUploading)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.red),
                        tooltip: 'ลบไฟล์ออก',
                        onPressed: () => _removeFile(index),
                      ),
                  ],
                ),
              );
            }),
          ),
      ],
    );
  }
}

class FileAttachmentCardWidget extends StatelessWidget {
  final FileAttachmentModel attachment;
  final VoidCallback? onDelete;
  final bool isDeleting;

  const FileAttachmentCardWidget({
    super.key,
    required this.attachment,
    this.onDelete,
    this.isDeleting = false,
  });

  Future<void> _openFile(BuildContext context) async {
    final url = attachment.url;
    final path = attachment.storagePath;

    if (attachment.isImage) {
      FullScreenImageViewer.show(
        context,
        imageUrl: url,
        imageBytes: attachment.bytes,
        title: attachment.fileName,
      );
      return;
    }

    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      try {
        if (kIsWeb) {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        } else {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ไม่สามารถเปิดลิงก์ไฟล์ได้: $e')),
          );
        }
      }
    } else if (!kIsWeb && path != null && path.isNotEmpty) {
      try {
        final fileUri = Uri.file(path);
        final launched = await launchUrl(fileUri, mode: LaunchMode.externalApplication);
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่สามารถเปิดไฟล์ในเครื่องได้')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เกิดข้อผิดพลาดในการเปิดไฟล์: $e')),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่มีลิงก์หรือที่อยู่ไฟล์สำหรับเปิดดู')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = AttachmentConfig.getCategory(attachment.fileType);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // If image with bytes or URL, show a larger preview image above card info
          if (attachment.isImage && (attachment.bytes != null || (attachment.url != null && attachment.url!.isNotEmpty))) ...[
            GestureDetector(
              onTap: () => _openFile(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: attachment.bytes != null
                    ? Image.memory(
                        attachment.bytes!,
                        width: double.infinity,
                        height: 140,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        attachment.url!,
                        width: double.infinity,
                        height: 140,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: double.infinity,
                          height: 100,
                          color: Colors.grey.shade200,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(category.icon, color: category.color, size: 32),
                              const SizedBox(height: 4),
                              const Text('ไม่สามารถโหลดรูปภาพได้', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(category.icon, color: category.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _openFile(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.fileName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            category.label,
                            style: TextStyle(fontSize: 11, color: category.color, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            attachment.fileSize,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
                tooltip: 'เปิดดูไฟล์',
                onPressed: () => _openFile(context),
              ),
              if (onDelete != null)
                IconButton(
                  icon: isDeleting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  tooltip: 'ลบไฟล์',
                  onPressed: isDeleting ? null : onDelete,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
