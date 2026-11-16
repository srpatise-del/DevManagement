import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';

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

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _sendComment() {
    final text = _commentController.text.trim();
    if (text.isNotEmpty) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.addComment(widget.caseId, text);
      _commentController.clear();
    }
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.cardBorder)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.crop_original, color: AppColors.textMuted),
                  onPressed: () {
                    // Simulate image attachment
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('เลือกรูปภาพเรียบร้อย')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.attach_file, color: AppColors.textMuted),
                  onPressed: () {
                    // Simulate file attachment
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('เลือกไฟล์เรียบร้อย')),
                    );
                  },
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _commentController,
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
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _sendComment,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentItem(CommentModel comment, AppState appState) {
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
                // Header row: Name (Role), date, menu
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
                    const Icon(Icons.more_vert, size: 16, color: AppColors.textMuted),
                  ],
                ),
                Text(
                  comment.dateText,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 8),

                // Content text
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4),
                ),

                // Attached image thumbnail if present
                if (comment.attachedImageUrl != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: 120,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: const DecorationImage(
                        image: NetworkImage('https://picsum.photos/200/150'),
                        fit: BoxFit.cover,
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
