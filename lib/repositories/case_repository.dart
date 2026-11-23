import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_models.dart';

class CaseRepository {
  SupabaseClient get _client => Supabase.instance.client;

  // 3.1 Load Cases
  Future<List<CaseModel>> loadCases() async {
    try {
      final response = await _client
          .from('cases')
          .select('''
            *,
            teams:team_id(id, name, code),
            creator:created_by(id, employee_code, full_name, email, role),
            assignee:assignee_id(id, employee_code, full_name, email, role),
            case_comments(
              id, case_id, author_id, content, attached_image_path, created_at,
              author:author_id(id, employee_code, full_name, email, role),
              case_comment_likes(user_id)
            ),
            case_activity_logs(
              id, case_id, title, author_name, icon_name, icon_color, icon_bg_color, created_at
            ),
            case_attachments(
              id, case_id, file_name, file_size, file_type, storage_path, uploaded_by, created_at
            )
          ''')
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      List<CaseModel> cases = [];

      for (var json in data) {
        cases.add(await _mapJsonToCaseModel(json));
      }

      return cases;
    } on AuthException catch (e) {
      throw Exception('Authentication Error: ${e.message}');
    } on PostgrestException catch (e) {
      throw Exception('Database Error (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error loading cases: $e');
    }
  }

  // 3.2 Create Case
  Future<CaseModel> createCase({
    required String title,
    String? details,
    required CasePriority priority,
    required CaseStatus status,
    required String teamId, // UUID of team
    required String category,
    String? assigneeId, // UUID of assignee profile
    String? systemAffected,
    String? environment,
    String? url,
    String? browser,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated.');
      }

      final insertData = {
        'title': title,
        'details': details,
        'priority': priority.name,
        'status': status.name,
        'team_id': teamId,
        'category': category,
        'assignee_id': assigneeId,
        'system_affected': systemAffected,
        'environment': environment,
        'url': url,
        'browser': browser,
        'created_by': user.id,
      };

      final response = await _client
          .from('cases')
          .insert(insertData)
          .select('''
            *,
            teams:team_id(id, name, code),
            creator:created_by(id, employee_code, full_name, email, role),
            assignee:assignee_id(id, employee_code, full_name, email, role)
          ''')
          .single();

      return await _mapJsonToCaseModel(response);
    } on AuthException catch (e) {
      throw Exception('Authentication Error during case creation: ${e.message}');
    } on PostgrestException catch (e) {
      throw Exception('Database Error during case creation (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error creating case: $e');
    }
  }

  // 3.3 Update Case
  Future<CaseModel> updateCase(String supabaseId, Map<String, dynamic> updates) async {
    try {
      final response = await _client
          .from('cases')
          .update(updates)
          .eq('id', supabaseId)
          .select('''
            *,
            teams:team_id(id, name, code),
            creator:created_by(id, employee_code, full_name, email, role),
            assignee:assignee_id(id, employee_code, full_name, email, role),
            case_comments(
              id, case_id, author_id, content, attached_image_path, created_at,
              author:author_id(id, employee_code, full_name, email, role),
              case_comment_likes(user_id)
            ),
            case_activity_logs(
              id, case_id, title, author_name, icon_name, icon_color, icon_bg_color, created_at
            ),
            case_attachments(
              id, case_id, file_name, file_size, file_type, storage_path, uploaded_by, created_at
            )
          ''')
          .single();

      return await _mapJsonToCaseModel(response);
    } on PostgrestException catch (e) {
      throw Exception('Database Error during case update (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating case: $e');
    }
  }

  // 3.4 Delete Case
  Future<void> deleteCase(String supabaseId) async {
    try {
      // 1. Fetch attachments to clean up storage
      final attachmentsRes = await _client
          .from('case_attachments')
          .select('storage_path')
          .eq('case_id', supabaseId);

      final pathsToDelete = <String>[];
      if (attachmentsRes is List) {
        for (var att in attachmentsRes) {
          final path = att['storage_path'] as String?;
          if (path != null && path.isNotEmpty) {
            pathsToDelete.add(path);
          }
        }
      }

      // Also check comments with attached images
      final commentsRes = await _client
          .from('case_comments')
          .select('attached_image_path')
          .eq('case_id', supabaseId);

      if (commentsRes is List) {
        for (var com in commentsRes) {
          final path = com['attached_image_path'] as String?;
          if (path != null && path.isNotEmpty) {
            pathsToDelete.add(path);
          }
        }
      }

      // 2. Delete database record (foreign keys cascade handle related tables)
      await _client.from('cases').delete().eq('id', supabaseId);

      // 3. Clean up storage objects if any
      if (pathsToDelete.isNotEmpty) {
        try {
          await _client.storage.from('case-attachments').remove(pathsToDelete);
        } catch (_) {}
      }
    } on PostgrestException catch (e) {
      throw Exception('Database Error during case deletion (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting case: $e');
    }
  }

  // 4. Comment Operations
  Future<CommentModel> addComment(String supabaseCaseId, String content, {String? attachedImagePath}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated.');
      }

      final insertData = {
        'case_id': supabaseCaseId,
        'author_id': user.id,
        'content': content,
        'attached_image_path': attachedImagePath,
      };

      final response = await _client
          .from('case_comments')
          .insert(insertData)
          .select('''
            *,
            author:author_id(id, employee_code, full_name, email, role),
            case_comment_likes(user_id)
          ''')
          .single();

      return await _mapJsonToCommentModel(response);
    } on PostgrestException catch (e) {
      throw Exception('Database Error adding comment (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error adding comment: $e');
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      final commentRes = await _client
          .from('case_comments')
          .select('attached_image_path')
          .eq('id', commentId)
          .maybeSingle();

      final imagePath = commentRes?['attached_image_path'] as String?;

      await _client.from('case_comments').delete().eq('id', commentId);

      // If delete succeeds, also remove the file from storage
      if (imagePath != null && imagePath.isNotEmpty) {
        try {
          await _client.storage.from('case-attachments').remove([imagePath]);
        } catch (_) {}
      }
    } on PostgrestException catch (e) {
      throw Exception('Database Error deleting comment (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error deleting comment: $e');
    }
  }

  Future<CommentModel> editComment(String commentId, String content) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated.');
      }
      
      final response = await _client
          .from('case_comments')
          .update({'content': content})
          .eq('id', commentId)
          .select('''
            *,
            author:author_id(id, employee_code, full_name, email, role),
            case_comment_likes(user_id)
          ''')
          .single();

      return await _mapJsonToCommentModel(response);
    } on PostgrestException catch (e) {
      throw Exception('Database Error editing comment (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error editing comment: $e');
    }
  }

  // 5. Comment Likes
  Future<bool> toggleLikeComment(String commentId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated.');
      }

      final existingLike = await _client
          .from('case_comment_likes')
          .select()
          .eq('comment_id', commentId)
          .eq('user_id', user.id)
          .maybeSingle();

      if (existingLike != null) {
        await _client
            .from('case_comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_id', user.id);
        return false;
      } else {
        await _client.from('case_comment_likes').insert({
          'comment_id': commentId,
          'user_id': user.id,
        });
        return true;
      }
    } on PostgrestException catch (e) {
      throw Exception('Database Error toggling like (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error toggling like: $e');
    }
  }

  // 7. Attachments & Storage
  Future<CaseFileAttachment> uploadAttachment({
    required String supabaseCaseId,
    required Uint8List fileBytes,
    required String fileName,
    required String fileSize,
    required String fileType,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated.');
      }

      final storagePath = 'cases/$supabaseCaseId/$fileName';

      await _client.storage.from('case-attachments').uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final insertData = {
        'case_id': supabaseCaseId,
        'file_name': fileName,
        'file_size': fileSize,
        'file_type': fileType,
        'storage_path': storagePath,
        'uploaded_by': user.id,
      };

      try {
        await _client.from('case_attachments').insert(insertData);
      } catch (dbError) {
        try {
          await _client.storage.from('case-attachments').remove([storagePath]);
        } catch (_) {}
        rethrow;
      }

      return CaseFileAttachment(
        fileName: fileName,
        fileSize: fileSize,
        fileType: fileType,
        storagePath: storagePath,
      );
    } on StorageException catch (e) {
      throw Exception('Storage Error during upload: ${e.message}');
    } on PostgrestException catch (e) {
      throw Exception('Database Error saving attachment metadata (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error uploading attachment: $e');
    }
  }

  Future<String?> getSignedUrl(String storagePath) async {
    try {
      if (storagePath.isEmpty) return null;
      return await _client.storage
          .from('case-attachments')
          .createSignedUrl(storagePath, 60 * 60 * 24);
    } catch (_) {
      return null;
    }
  }

  // Mapping Helpers
  Future<CaseModel> _mapJsonToCaseModel(Map<String, dynamic> json) async {
    final supabaseId = json['id'] as String?;
    final caseNo = json['case_no'] as String? ?? 'DEV-000';
    final title = json['title'] as String? ?? '';
    final details = json['details'] as String?;
    final priority = _parsePriority(json['priority'] as String?);
    final status = _parseStatus(json['status'] as String?);
    final team = _parseTeam(json['teams']);
    final category = json['category'] as String? ?? 'General';
    
    final assigneeJson = json['assignee'];
    UserModel? assignee;
    if (assigneeJson != null && assigneeJson is Map<String, dynamic>) {
      assignee = _mapJsonToUserModel(assigneeJson);
    }

    final creatorJson = json['creator'];
    String createdById = 'EMP-001';
    if (creatorJson != null && creatorJson is Map<String, dynamic>) {
      createdById = creatorJson['employee_code'] as String? ?? 'EMP-001';
    }

    final createdAtStr = json['created_at'];
    final dateText = _formatDate(createdAtStr);

    final systemAffected = json['system_affected'] as String? ?? '';
    final environment = json['environment'] as String? ?? '';
    final url = json['url'] as String? ?? '';
    final browser = json['browser'] as String? ?? '';

    final commentsList = json['case_comments'] as List<dynamic>? ?? [];
    List<CommentModel> comments = [];
    for (var c in commentsList) {
      if (c is Map<String, dynamic>) {
        comments.add(await _mapJsonToCommentModel(c));
      }
    }
    comments.sort((a, b) => a.id.compareTo(b.id));

    final logsList = json['case_activity_logs'] as List<dynamic>? ?? [];
    List<ActivityLogModel> activityLogs = [];
    for (var l in logsList) {
      if (l is Map<String, dynamic>) {
        activityLogs.add(_mapJsonToActivityLogModel(l));
      }
    }

    final attachmentsList = json['case_attachments'] as List<dynamic>? ?? [];
    List<CaseFileAttachment> attachedFiles = [];
    List<String> attachedImages = [];

    for (var att in attachmentsList) {
      if (att is Map<String, dynamic>) {
        final fileName = att['file_name'] as String? ?? '';
        final fileSize = att['file_size'] as String? ?? '0 KB';
        final fileType = att['file_type'] as String?;
        final storagePath = att['storage_path'] as String?;

        attachedFiles.add(CaseFileAttachment(
          fileName: fileName,
          fileSize: fileSize,
          fileType: fileType,
          storagePath: storagePath,
        ));

        if (fileType != null && (fileType.toLowerCase().contains('image') || fileName.toLowerCase().endsWith('.png') || fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.jpeg'))) {
          if (storagePath != null) {
            final signedUrl = await getSignedUrl(storagePath);
            if (signedUrl != null) {
              attachedImages.add(signedUrl);
            }
          }
        }
      }
    }

    return CaseModel(
      id: caseNo,
      supabaseId: supabaseId,
      title: title,
      details: details,
      priority: priority,
      status: status,
      team: team,
      category: category,
      assignee: assignee,
      dateText: dateText,
      systemAffected: systemAffected,
      environment: environment,
      url: url,
      browser: browser,
      createdById: createdById,
      attachedImages: attachedImages,
      attachedFiles: attachedFiles,
      comments: comments,
      activityLogs: activityLogs,
    );
  }

  Future<CommentModel> _mapJsonToCommentModel(Map<String, dynamic> json) async {
    final id = json['id'] as String? ?? '';
    final caseId = json['case_id'] as String? ?? '';
    final content = json['content'] as String? ?? '';
    final createdAt = json['created_at'];
    final dateText = _formatDate(createdAt);

    final authorJson = json['author'];
    final author = _mapJsonToUserModel(authorJson);

    final attachedImagePath = json['attached_image_path'] as String?;
    String? attachedImageUrl;
    if (attachedImagePath != null && attachedImagePath.isNotEmpty) {
      attachedImageUrl = await getSignedUrl(attachedImagePath);
    } else if (json['attached_image_url'] != null) {
      attachedImageUrl = json['attached_image_url'] as String?;
    }

    final likesList = json['case_comment_likes'] as List<dynamic>? ?? [];
    final likesCount = likesList.length;
    
    final currentUserId = _client.auth.currentUser?.id;
    final isLiked = currentUserId != null && likesList.any((l) => l['user_id'] == currentUserId);

    return CommentModel(
      id: id,
      caseId: caseId,
      author: author,
      content: content,
      dateText: dateText,
      attachedImageUrl: attachedImageUrl,
      attachedImagePath: attachedImagePath,
      likes: likesCount,
      isLiked: isLiked,
    );
  }

  ActivityLogModel _mapJsonToActivityLogModel(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final caseId = json['case_id'] as String? ?? '';
    final title = json['title'] as String? ?? '';
    final authorName = json['author_name'] as String? ?? 'System';
    final createdAt = json['created_at'];
    final dateText = _formatDate(createdAt);

    final iconName = json['icon_name'] as String?;
    final iconColorStr = json['icon_color'] as String?;
    final iconBgColorStr = json['icon_bg_color'] as String?;

    return ActivityLogModel(
      id: id,
      caseId: caseId,
      title: title,
      authorName: authorName,
      dateText: dateText,
      icon: _parseIcon(iconName),
      iconColor: _parseColor(iconColorStr, Colors.blue),
      iconBgColor: _parseColor(iconBgColorStr, const Color(0xFFDBEAFE)),
    );
  }

  UserModel _mapJsonToUserModel(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const UserModel(
        id: 'EMP-001',
        name: 'Unknown User',
        role: 'user',
        email: '',
        avatarUrl: 'U',
      );
    }
    final employeeCode = json['employee_code'] as String? ?? 'EMP-001';
    final fullName = json['full_name'] as String? ?? 'User';
    final email = json['email'] as String? ?? '';
    final role = json['role'] as String? ?? 'user';
    final avatarLetter = fullName.isNotEmpty ? fullName.substring(0, 1).toUpperCase() : 'U';

    return UserModel(
      id: employeeCode,
      authUserId: json['id']?.toString(),
      name: fullName,
      role: role,
      email: email,
      password: '',
      avatarUrl: avatarLetter,
      position: role.toUpperCase(),
    );
  }

  TeamType _parseTeam(dynamic teamData) {
    if (teamData is Map<String, dynamic>) {
      final code = (teamData['code'] as String? ?? '').toLowerCase();
      return TeamType.values.firstWhere(
        (t) => t.name.toLowerCase() == code,
        orElse: () => TeamType.web,
      );
    }
    return TeamType.web;
  }

  CasePriority _parsePriority(String? priorityStr) {
    switch (priorityStr?.toLowerCase()) {
      case 'low': return CasePriority.low;
      case 'medium': return CasePriority.medium;
      case 'high': return CasePriority.high;
      case 'critical': return CasePriority.critical;
      default: return CasePriority.medium;
    }
  }

  CaseStatus _parseStatus(String? statusStr) {
    switch (statusStr) {
      case 'open': return CaseStatus.open;
      case 'assigned': return CaseStatus.assigned;
      case 'inProgress': return CaseStatus.inProgress;
      case 'pending': return CaseStatus.pending;
      case 'waiting': return CaseStatus.waiting;
      case 'testing': return CaseStatus.testing;
      case 'done': return CaseStatus.done;
      case 'closed': return CaseStatus.closed;
      default: return CaseStatus.open;
    }
  }

  IconData _parseIcon(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'add':
      case 'add_circle': return Icons.add_circle;
      case 'person_add': return Icons.person_add;
      case 'sync': return Icons.sync;
      case 'chat':
      case 'chat_bubble': return Icons.chat_bubble;
      case 'attach':
      case 'attach_file': return Icons.attach_file;
      case 'check':
      case 'check_circle': return Icons.check_circle;
      default: return Icons.history;
    }
  }

  Color _parseColor(String? colorStr, Color defaultColor) {
    if (colorStr == null) return defaultColor;
    if (colorStr.startsWith('0x') || colorStr.startsWith('0X')) {
      final val = int.tryParse(colorStr.substring(2), radix: 16);
      if (val != null) return Color(val);
    }
    switch (colorStr.toLowerCase()) {
      case 'blue': return Colors.blue;
      case 'indigo': return Colors.indigo;
      case 'teal': return Colors.teal;
      case 'green': return Colors.green;
      case 'orange': return Colors.orange;
      case 'red': return Colors.red;
      case 'purple': return Colors.purple;
      case 'blueaccent': return Colors.blueAccent;
      default: return defaultColor;
    }
  }

  String _formatDate(dynamic timestampStr) {
    if (timestampStr == null) return '';
    try {
      final dt = DateTime.parse(timestampStr.toString()).toLocal();
      const thaiMonths = ['', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
      final buddhistYear = dt.year + 543;
      final monthStr = (dt.month >= 1 && dt.month <= 12) ? thaiMonths[dt.month] : '';
      return '${dt.day} $monthStr $buddhistYear ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestampStr.toString();
    }
  }
}
