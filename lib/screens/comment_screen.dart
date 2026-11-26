import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../config/attachment_config.dart';
import '../widgets/attachment_picker_widget.dart';
import '../widgets/full_screen_image_viewer.dart';

import '../models/role_permission.dart';

class CommentScreen extends StatelessWidget {
  final String caseId;

  const CommentScreen({super.key, required this.caseId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ความคิดเห็น',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: CommentTabWidget(caseId: caseId),
    );
  }
}

class CommentTabWidget extends StatefulWidget {
  final String caseId;

  const CommentTabWidget({super.key, required this.caseId});

  @override
  State<CommentTabWidget> createState() => _CommentTabWidgetState();
}

class _CommentTabWidgetState extends State<CommentTabWidget> {
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _editCommentController = TextEditingController();
  List<PendingFileAttachment> _pendingFiles = [];
  bool _isSending = false;
  String? _editingCommentId;
  bool _isUpdating = false;

  @override
  void dispose() {
    _commentController.dispose();
    _editCommentController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment({bool imagesOnly = false}) async {
    if (_pendingFiles.length >= AttachmentConfig.maxFileCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('แนบไฟล์ได้สูงสุด ${AttachmentConfig.maxFileCount} ไฟล์ ต่อความคิดเห็น'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: imagesOnly ? FileType.image : FileType.custom,
        allowedExtensions: imagesOnly ? null : AttachmentConfig.allAllowedExtensions.toList(),
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final List<PendingFileAttachment> newFiles = List.from(_pendingFiles);
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

        if (ext.isEmpty && imagesOnly) {
          ext = 'jpg';
        }

        if (!fileName.contains('.') && ext.isNotEmpty) {
          fileName = '$fileName.$ext';
        }

        final err = AttachmentConfig.validateFile(
          fileName: fileName,
          fileSizeBytes: fileSize,
          fileExtension: ext,
        );

        if (err != null) {
          errors.add(err);
          continue;
        }

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

      if (errors.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errors.join('\n')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }

      setState(() {
        _pendingFiles = newFiles;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการเลือกไฟล์: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _pendingFiles.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      await appState.addComment(
        widget.caseId,
        text,
        pendingFiles: _pendingFiles,
      );

      if (mounted) {
        _commentController.clear();
        setState(() {
          _pendingFiles = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถส่งความคิดเห็นได้: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _removePendingFile(int index) {
    setState(() {
      _pendingFiles.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final caseObj = appState.cases.firstWhere(
      (c) => c.id == widget.caseId,
      orElse: () => appState.cases.first,
    );

    return Column(
      children: [
        // Comments List
        Expanded(
          child: caseObj.comments.isEmpty
              ? const Center(
                  child: Text(
                    'ยังไม่มีความคิดเห็น',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: caseObj.comments.length,
                  itemBuilder: (context, index) {
                    final comment = caseObj.comments[index];
                    return _buildCommentItem(comment, appState);
                  },
                ),
        ),

        // Input Bar at bottom
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.cardBorder)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pending Files Preview Strip
                if (_pendingFiles.isNotEmpty)
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    color: const Color(0xFFF1F5F9),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pendingFiles.length,
                      itemBuilder: (ctx, idx) {
                        final file = _pendingFiles[idx];
                        final category = AttachmentConfig.getCategory(file.extension);

                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (file.isImage && file.bytes != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.memory(
                                    file.bytes!,
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Icon(category.icon, size: 20, color: category.color),
                              const SizedBox(width: 6),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 100),
                                    child: Text(
                                      file.name,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    file.formattedSize,
                                    style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => _removePendingFile(idx),
                                child: const Icon(Icons.close, size: 16, color: Colors.red),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                // Text Input Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image_outlined, color: AppColors.primary),
                        tooltip: 'แนบรูปภาพ',
                        onPressed: _isSending ? null : () => _pickAttachment(imagesOnly: true),
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file, color: AppColors.primary),
                        tooltip: 'แนบไฟล์เอกสาร',
                        onPressed: _isSending ? null : () => _pickAttachment(imagesOnly: false),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          enabled: !_isSending,
                          decoration: const InputDecoration(
                            hintText: 'พิมพ์ความคิดเห็น...',
                            hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            fillColor: Color(0xFFF8FAFC),
                          ),
                          onSubmitted: (_) => _sendComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary,
                        child: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                                onPressed: _sendComment,
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context, AppState appState, String commentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบความคิดเห็น'),
        content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบความคิดเห็นนี้?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await appState.deleteCaseComment(widget.caseId, commentId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ลบความคิดเห็นสำเร็จ'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(CommentModel comment, AppState appState) {
    final currentUser = appState.currentUser;
    final bool canEdit = currentUser != null && RolePermissionHelper.canEditComment(currentUser, comment);
    final bool canDelete = currentUser != null && RolePermissionHelper.canDeleteComment(currentUser, comment);
    final bool isEditing = _editingCommentId == comment.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            child: Text(
              comment.author.avatarUrl,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          // Content Block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Name (Role), date
                Row(
                  children: [
                    Text(
                      comment.author.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${comment.author.role})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      comment.dateText,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    if (canEdit || canDelete)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          if (value == 'edit') {
                            setState(() {
                              _editingCommentId = comment.id;
                              _editCommentController.text = comment.content;
                            });
                          } else if (value == 'delete') {
                            _showDeleteDialog(context, appState, comment.id);
                          }
                        },
                        itemBuilder: (context) => [
                          if (canEdit)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('แก้ไข', style: TextStyle(fontSize: 13)),
                            ),
                          if (canDelete)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('ลบ', style: TextStyle(fontSize: 13, color: Colors.red)),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Content text or Editor
                if (isEditing) ...[
                  TextField(
                    controller: _editCommentController,
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(8),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isUpdating ? null : () {
                          setState(() {
                            _editingCommentId = null;
                            _editCommentController.clear();
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('ยกเลิก', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isUpdating ? null : () async {
                          final newText = _editCommentController.text.trim();
                          if (newText.isEmpty) return;
                          
                          setState(() { _isUpdating = true; });
                          try {
                            await appState.editCaseComment(widget.caseId, comment.id, newText);
                            if (mounted) {
                              setState(() {
                                _editingCommentId = null;
                                _isUpdating = false;
                              });
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() { _isUpdating = false; });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: AppColors.primary,
                        ),
                        child: _isUpdating 
                            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('บันทึก', style: TextStyle(fontSize: 12, color: Colors.white)),
                      ),
                    ],
                  ),
                ] else if (comment.content.isNotEmpty)
                  Text(
                    comment.content,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                  ),

                // Attached Files Render
                if (comment.attachedFiles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: comment.attachedFiles.map((att) {
                      return FileAttachmentCardWidget(attachment: att);
                    }).toList(),
                  ),
                ] else if (comment.attachedImageUrl != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => FullScreenImageViewer.show(
                      context,
                      imageUrl: comment.attachedImageUrl,
                      title: 'รูปภาพแนบ',
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        comment.attachedImageUrl!,
                        width: 160,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 160,
                          height: 100,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
