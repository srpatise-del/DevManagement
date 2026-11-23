import 'dart:typed_data';
import 'app_models.dart';
import '../config/attachment_config.dart';

class FileAttachmentModel {
  final String id;
  final String fileName;
  final String fileSize;
  final int fileSizeBytes;
  final String fileType; // Extension or category, e.g. 'png', 'pdf'
  final String? mimeType;
  final String? storagePath;
  final String? url; // Signed URL or network URL
  final Uint8List? bytes;
  final String? uploadedBy;
  final String? createdAt;

  FileAttachmentModel({
    required this.id,
    required this.fileName,
    required this.fileSize,
    this.fileSizeBytes = 0,
    required this.fileType,
    this.mimeType,
    this.storagePath,
    this.url,
    this.bytes,
    this.uploadedBy,
    this.createdAt,
  });

  bool get isImage => AttachmentConfig.isImage(fileType);

  FileAttachmentModel copyWith({
    String? id,
    String? fileName,
    String? fileSize,
    int? fileSizeBytes,
    String? fileType,
    String? mimeType,
    String? storagePath,
    bool clearStoragePath = false,
    String? url,
    bool clearUrl = false,
    Uint8List? bytes,
    bool clearBytes = false,
    String? uploadedBy,
    String? createdAt,
  }) {
    return FileAttachmentModel(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      fileType: fileType ?? this.fileType,
      mimeType: mimeType ?? this.mimeType,
      storagePath: clearStoragePath ? null : (storagePath ?? this.storagePath),
      url: clearUrl ? null : (url ?? this.url),
      bytes: clearBytes ? null : (bytes ?? this.bytes),
      uploadedBy: uploadedBy ?? this.uploadedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Convert to legacy CaseFileAttachment
  CaseFileAttachment toCaseFileAttachment() {
    return CaseFileAttachment(
      fileName: fileName,
      fileSize: fileSize,
      fileType: fileType,
      storagePath: storagePath,
    );
  }

  // Convert to legacy AttachmentModel
  AttachmentModel toAttachmentModel() {
    return AttachmentModel(
      id: id,
      name: fileName,
      size: fileSize,
      dateText: createdAt ?? 'วันนี้',
      fileType: fileType,
    );
  }

  // Factory from legacy CaseFileAttachment
  factory FileAttachmentModel.fromCaseFileAttachment(CaseFileAttachment att, {String? id}) {
    return FileAttachmentModel(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      fileName: att.fileName,
      fileSize: att.fileSize,
      fileSizeBytes: att.fileSizeBytes,
      fileType: att.fileType ?? (att.fileName.contains('.') ? att.fileName.split('.').last : 'file'),
      mimeType: att.mimeType,
      storagePath: att.storagePath,
      url: att.url,
    );
  }

  // Factory from legacy AttachmentModel
  factory FileAttachmentModel.fromAttachmentModel(AttachmentModel att) {
    return FileAttachmentModel(
      id: att.id,
      fileName: att.name,
      fileSize: att.size,
      fileType: att.fileType,
      createdAt: att.dateText,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'file_name': fileName,
      'file_size': fileSize,
      'file_size_bytes': fileSizeBytes,
      'file_type': fileType,
      'mime_type': mimeType,
      'storage_path': storagePath,
      'url': url,
      'uploaded_by': uploadedBy,
      'created_at': createdAt,
    };
  }

  factory FileAttachmentModel.fromJson(Map<String, dynamic> json) {
    final fileName = json['file_name'] as String? ?? json['fileName'] as String? ?? 'unknown';
    final fileType = json['file_type'] as String? ?? json['fileType'] as String? ?? (fileName.contains('.') ? fileName.split('.').last : 'file');
    final fileSize = json['file_size'] as String? ?? json['fileSize'] as String? ?? '0 KB';
    final fileSizeBytes = json['file_size_bytes'] as int? ?? json['fileSizeBytes'] as int? ?? 0;

    return FileAttachmentModel(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      fileName: fileName,
      fileSize: fileSize,
      fileSizeBytes: fileSizeBytes,
      fileType: fileType,
      mimeType: json['mime_type'] as String? ?? json['mimeType'] as String?,
      storagePath: json['storage_path'] as String? ?? json['storagePath'] as String?,
      url: json['url'] as String?,
      uploadedBy: json['uploaded_by'] as String? ?? json['uploadedBy'] as String?,
      createdAt: json['created_at'] as String? ?? json['createdAt'] as String?,
    );
  }
}
