import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum FileCategory {
  image('รูปภาพ', Icons.image_outlined, AppColors.primary),
  pdf('เอกสาร PDF', Icons.picture_as_pdf_outlined, Colors.red),
  excel('เอกสาร Excel', Icons.table_chart_outlined, Colors.green),
  word('เอกสาร Word', Icons.description_outlined, Colors.blue),
  powerpoint('เอกสาร พรีเซนเตชัน', Icons.slideshow_outlined, Colors.orange),
  text('เอกสารข้อความ / CSV', Icons.text_snippet_outlined, Colors.teal),
  other('ไฟล์ทั่วไป', Icons.insert_drive_file_outlined, AppColors.textSecondary);

  final String label;
  final IconData icon;
  final Color color;

  const FileCategory(this.label, this.icon, this.color);
}

class AttachmentConfig {
  // Max File Size Limit: 10 MB per file
  static const int maxFileSizeBytes = 10 * 1024 * 1024;
  static const String maxFileSizeDisplay = '10 MB';

  // Max File Count Limit: 5 files per batch
  static const int maxFileCount = 5;

  // Allowed File Extensions
  static const Set<String> allowedImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  static const Set<String> allowedDocExtensions = {
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
  };

  static const Set<String> allowedTextExtensions = {
    'txt',
    'csv',
  };

  static Set<String> get allAllowedExtensions => {
        ...allowedImageExtensions,
        ...allowedDocExtensions,
        ...allowedTextExtensions,
      };

  // Check if extension is allowed
  static bool isAllowedExtension(String extension) {
    final cleanExt = extension.toLowerCase().replaceAll('.', '').trim();
    return allAllowedExtensions.contains(cleanExt);
  }

  // File Category Helpers
  static FileCategory getCategory(String fileTypeOrName) {
    final clean = fileTypeOrName.toLowerCase().replaceAll('.', '').trim();
    if (allowedImageExtensions.contains(clean)) {
      return FileCategory.image;
    }
    if (clean == 'pdf') {
      return FileCategory.pdf;
    }
    if (clean == 'xls' || clean == 'xlsx') {
      return FileCategory.excel;
    }
    if (clean == 'doc' || clean == 'docx') {
      return FileCategory.word;
    }
    if (clean == 'ppt' || clean == 'pptx') {
      return FileCategory.powerpoint;
    }
    if (clean == 'txt' || clean == 'csv') {
      return FileCategory.text;
    }
    return FileCategory.other;
  }

  static bool isImage(String fileTypeOrName) {
    return getCategory(fileTypeOrName) == FileCategory.image;
  }

  static IconData getFileIcon(String fileTypeOrName) {
    return getCategory(fileTypeOrName).icon;
  }

  static Color getFileIconColor(String fileTypeOrName) {
    return getCategory(fileTypeOrName).color;
  }

  // Format File Size
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Resolve Extension
  static String resolveExtension({
    required String fileName,
    String? fileExtension,
    String? mimeType,
  }) {
    if (fileExtension != null && fileExtension.trim().isNotEmpty) {
      return fileExtension.toLowerCase().replaceAll('.', '').trim();
    }
    if (fileName.contains('.')) {
      return fileName.split('.').last.toLowerCase().trim();
    }
    if (mimeType != null && mimeType.contains('/')) {
      final sub = mimeType.split('/').last.toLowerCase().trim();
      if (sub == 'jpeg') return 'jpg';
      return sub;
    }
    return '';
  }

  // Validate File
  static String? validateFile({
    required String fileName,
    required int fileSizeBytes,
    String? fileExtension,
    String? mimeType,
  }) {
    var extension = resolveExtension(
      fileName: fileName,
      fileExtension: fileExtension,
      mimeType: mimeType,
    );

    if (extension.isEmpty && mimeType?.startsWith('image/') == true) {
      extension = 'jpg';
    }

    if (extension.isEmpty || !isAllowedExtension(extension)) {
      return 'ไฟล์ "$fileName" ไม่รองรับ (รองรับเฉพาะ รูปภาพ, PDF, Word, Excel, PPT, TXT, CSV)';
    }

    if (fileSizeBytes > maxFileSizeBytes) {
      return 'ไฟล์ "$fileName" มีขนาดเกินกำหนด (${formatFileSize(fileSizeBytes)} > $maxFileSizeDisplay)';
    }

    return null; // Valid
  }
}
