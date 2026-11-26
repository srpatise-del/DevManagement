import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/attachment_config.dart';
import '../models/app_models.dart';

class OrderRepository {
  SupabaseClient get _client => Supabase.instance.client;

  static const String _orderSelect = '''
    id, order_number, card_type, title, description, activity_status, amount,
    bank_code, bank_name, bank_account_number, issue_type, due_date,
    payment_method_code, payment_method, status_order, delivery_type, priority,
    created_by_id, assignee_id, deleted_at, created_at, updated_at,
    creator:profiles!orders_created_by_id_fkey(id, employee_code, full_name, email, role, phone_number),
    assignee:profiles!orders_assignee_id_fkey(id, employee_code, full_name, email, role, phone_number),
    order_items(id, order_id, item_name, delivery_type, quantity, unit_price, created_at),
    order_comments(
      id, order_id, author_id, content, created_at,
      author:profiles!order_comments_author_id_fkey(id, employee_code, full_name, email, role),
      order_comment_likes(user_id)
    ),
    order_attachments(
      id, order_id, file_name, file_size, file_size_bytes, file_type, mime_type, storage_path, uploaded_by, created_at
    ),
    order_activity_logs(
      id, order_id, author_id, action_type, title, details, icon, icon_color, icon_bg_color, created_at,
      author:profiles!order_activity_logs_author_id_fkey(full_name)
    )
  ''';

  Future<List<OrderModel>> loadOrders() async {
    try {
      final response = await _client
          .from('orders')
          .select(_orderSelect)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final List<OrderModel> orders = [];
      for (final json in data) {
        if (json is Map<String, dynamic>) {
          orders.add(await _mapJsonToOrderModel(json));
        }
      }
      return orders;
    } on AuthException catch (e) {
      throw Exception('Authentication Error loading orders: ${e.message}');
    } on PostgrestException catch (e) {
      throw Exception('Database Error loading orders (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error loading orders: $e');
    }
  }

  Future<OrderModel> createOrder({
    required String orderNumber,
    required OrderCardType cardType,
    required DeliveryType deliveryType,
    required CasePriority priority,
    String? assigneeId,
    String? errorDetails,
    String? bankCode,
    String? bankName,
    String? paymentMethodCode,
    String? paymentMethod,
    double? amount,
    OrderStatus? statusOrder,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated.');
      }

      final dbCardType = cardType == OrderCardType.bankIssue ? 'bank_issue' : 'order_diff';
      final insertData = <String, dynamic>{
        'order_number': orderNumber,
        'card_type': dbCardType,
        'title': 'Order $orderNumber',
        'description': errorDetails,
        'activity_status': OrderActivityStatus.newOrder.name,
        'amount': amount ?? 0,
        'delivery_type': deliveryType.name,
        'priority': priority.name,
        'bank_code': bankCode,
        'bank_name': bankName,
        'payment_method_code': paymentMethodCode,
        'payment_method': paymentMethod,
        'status_order': (statusOrder ?? OrderStatus.pending).code,
        'created_by_id': user.id,
        'assignee_id': assigneeId,
      };

      final inserted = await _client
          .from('orders')
          .insert(insertData)
          .select('id')
          .single();

      final newOrderId = inserted['id'] as String;

      // Insert initial order item matching the main order number
      await _client.from('order_items').insert({
        'order_id': newOrderId,
        'item_name': orderNumber,
        'delivery_type': deliveryType.name,
        'quantity': 1,
        'unit_price': amount ?? 0,
      });

      final full = await _client
          .from('orders')
          .select(_orderSelect)
          .eq('id', newOrderId)
          .single();

      return await _mapJsonToOrderModel(full);
    } on PostgrestException catch (e) {
      throw Exception('Database Error creating order (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error creating order: $e');
    }
  }

  Future<OrderModel> updateOrder(
    String supabaseOrderId,
    Map<String, dynamic> updates, {
    List<OrderItemModel>? items,
  }) async {
    try {
      if (updates.isNotEmpty) {
        await _client.from('orders').update(updates).eq('id', supabaseOrderId);
      }

      if (items != null) {
        await _client.from('order_items').delete().eq('order_id', supabaseOrderId);
        if (items.isNotEmpty) {
          await _client.from('order_items').insert(
            items
                .map((item) => {
                      'order_id': supabaseOrderId,
                      'item_name': item.id.trim(),
                      'delivery_type': item.deliveryType.name,
                      'quantity': 1,
                      'unit_price': 0,
                    })
                .toList(),
          );
        }
      }

      final full = await _client
          .from('orders')
          .select(_orderSelect)
          .eq('id', supabaseOrderId)
          .single();

      return await _mapJsonToOrderModel(full);
    } on PostgrestException catch (e) {
      throw Exception('Database Error updating order (${e.code}): ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error updating order: $e');
    }
  }

  Future<void> addOrderItem(
    String supabaseOrderId,
    String orderNo,
    DeliveryType deliveryType,
  ) async {
    try {
      await _client.from('order_items').insert({
        'order_id': supabaseOrderId,
        'item_name': orderNo.trim(),
        'delivery_type': deliveryType.name,
        'quantity': 1,
        'unit_price': 0,
      });
    } on PostgrestException catch (e) {
      throw Exception('Database Error adding order item (${e.code}): ${e.message}');
    }
  }

  Future<void> softDeleteOrder(String supabaseOrderId, {String? reason}) async {
    try {
      await _client.rpc(
        'soft_delete_order',
        params: {
          'p_order_id': supabaseOrderId,
          'p_reason': reason,
        },
      );
    } on PostgrestException catch (e) {
      throw Exception('Database Error deleting order (${e.code}): ${e.message}');
    }
  }

  Future<CommentModel> addComment(String supabaseOrderId, String content) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated.');
      }

      final response = await _client
          .from('order_comments')
          .insert({
            'order_id': supabaseOrderId,
            'author_id': user.id,
            'content': content,
          })
          .select('''
            id, order_id, author_id, content, created_at,
            author:profiles!order_comments_author_id_fkey(id, employee_code, full_name, email, role),
            order_comment_likes(user_id)
          ''')
          .single();

      return _mapJsonToCommentModel(response);
    } on PostgrestException catch (e) {
      throw Exception('Database Error adding order comment (${e.code}): ${e.message}');
    }
  }

  Future<void> editComment(String commentId, String newContent) async {
    try {
      await _client
          .from('order_comments')
          .update({'content': newContent})
          .eq('id', commentId);
    } on PostgrestException catch (e) {
      throw Exception('Database Error editing order comment (${e.code}): ${e.message}');
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await _client.from('order_comments').delete().eq('id', commentId);
    } on PostgrestException catch (e) {
      throw Exception('Database Error deleting order comment (${e.code}): ${e.message}');
    }
  }

  Future<AttachmentModel> uploadOrderAttachment({
    required String supabaseOrderId,
    required Uint8List fileBytes,
    required String fileName,
    required String fileType,
    int? fileSizeBytes,
    String? mimeType,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated.');
      }

      final sizeBytes = fileSizeBytes ?? fileBytes.length;
      final formattedSize = AttachmentConfig.formatFileSize(sizeBytes);
      final resolvedMime = mimeType ?? lookupMimeType(fileName) ?? 'application/octet-stream';

      final sanitized = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final prefix = DateTime.now().millisecondsSinceEpoch.toString();
      var safeFileName = '${prefix}_$sanitized';
      if (safeFileName.length > 250) {
        safeFileName = safeFileName.substring(0, 250);
      }
      final storagePath = '$supabaseOrderId/$safeFileName';

      await _client.storage.from('order-attachments').uploadBinary(
            storagePath,
            fileBytes,
            fileOptions: FileOptions(
              upsert: false,
              contentType: resolvedMime,
            ),
          );

      Map<String, dynamic> inserted;
      try {
        inserted = await _client
            .from('order_attachments')
            .insert({
              'order_id': supabaseOrderId,
              'file_name': fileName,
              'file_size': formattedSize,
              'file_size_bytes': sizeBytes,
              'file_type': fileType,
              'mime_type': resolvedMime,
              'storage_path': storagePath,
              'uploaded_by': user.id,
            })
            .select()
            .single();
      } catch (dbErr) {
        try {
          await _client.storage.from('order-attachments').remove([storagePath]);
        } catch (_) {}
        rethrow;
      }

      final signedUrl = await getSignedUrl(storagePath);

      return AttachmentModel(
        id: inserted['id'] as String,
        name: fileName,
        size: formattedSize,
        dateText: _formatDate(inserted['created_at']),
        fileType: fileType,
        storagePath: storagePath,
        url: signedUrl,
        mimeType: resolvedMime,
        fileSizeBytes: sizeBytes,
      );
    } on StorageException catch (e) {
      throw Exception('Storage Error uploading order attachment: ${e.message}');
    } on PostgrestException catch (e) {
      throw Exception('Database Error saving order attachment (${e.code}): ${e.message}');
    }
  }

  Future<void> deleteOrderAttachment(String attachmentId, {String? storagePath}) async {
    try {
      await _client.from('order_attachments').delete().eq('id', attachmentId);
      if (storagePath != null && storagePath.isNotEmpty) {
        try {
          await _client.storage.from('order-attachments').remove([storagePath]);
        } catch (_) {
          try {
            await _client.storage.from('attachments').remove([storagePath]);
          } catch (_) {}
        }
      }
    } on PostgrestException catch (e) {
      throw Exception('Database Error deleting order attachment (${e.code}): ${e.message}');
    }
  }

  Future<String?> getSignedUrl(String storagePath) async {
    if (storagePath.isEmpty) return null;
    try {
      return await _client.storage
          .from('order-attachments')
          .createSignedUrl(storagePath, 60 * 60 * 24);
    } catch (_) {
      try {
        return await _client.storage
            .from('attachments')
            .createSignedUrl(storagePath, 60 * 60 * 24);
      } catch (_) {
        return null;
      }
    }
  }

  Future<OrderModel> _mapJsonToOrderModel(Map<String, dynamic> json) async {
    final supabaseId = json['id'] as String;
    final orderNumber = json['order_number'] as String? ?? supabaseId;
    final cardType = _parseCardType(json['card_type'] as String?);
    final deliveryType = _parseDeliveryType(json['delivery_type'] as String?);
    final priority = _parsePriority(json['priority'] as String?);
    final activityStatus = _parseActivityStatus(json['activity_status'] as String?);

    UserModel? assignee;
    if (json['assignee'] is Map<String, dynamic>) {
      assignee = _mapJsonToUserModel(json['assignee']);
    }

    String createBy = 'System';
    if (json['creator'] is Map<String, dynamic>) {
      final creatorMap = json['creator'] as Map<String, dynamic>;
      createBy = (creatorMap['full_name'] as String?)?.trim().isNotEmpty == true
          ? creatorMap['full_name'] as String
          : (creatorMap['email'] as String? ?? 'System');
    }

    final createdAtRaw = json['created_at'];
    final dateText = _formatDate(createdAtRaw);
    final standardDate = _formatStandardDate(createdAtRaw);

    final rawAmount = json['amount'];
    final double? amount = rawAmount is num
        ? rawAmount.toDouble()
        : (rawAmount != null ? double.tryParse(rawAmount.toString()) : null);

    final statusOrderCode = json['status_order'] as String?;
    final statusOrder = statusOrderCode != null && statusOrderCode.isNotEmpty
        ? OrderStatus.fromCode(statusOrderCode)
        : OrderStatus.pending;

    // Map items
    final itemsList = json['order_items'] as List<dynamic>? ?? [];
    final items = itemsList
        .whereType<Map<String, dynamic>>()
        .map((item) => OrderItemModel(
              id: item['item_name'] as String? ?? orderNumber,
              deliveryType: _parseDeliveryType(item['delivery_type'] as String? ?? json['delivery_type'] as String?),
            ))
        .toList();

    // Map attachments with signed URLs
    final attachList = json['order_attachments'] as List<dynamic>? ?? [];
    final List<AttachmentModel> attachments = [];
    for (final att in attachList) {
      if (att is Map<String, dynamic>) {
        final storagePath = att['storage_path'] as String?;
        final signedUrl = (storagePath != null && storagePath.isNotEmpty)
            ? await getSignedUrl(storagePath)
            : null;
        final rawBytes = att['file_size_bytes'];
        final sizeBytes = rawBytes is num ? rawBytes.toInt() : 0;
        attachments.add(AttachmentModel(
          id: att['id'] as String? ?? '',
          name: att['file_name'] as String? ?? '',
          size: att['file_size'] as String? ?? AttachmentConfig.formatFileSize(sizeBytes),
          dateText: _formatDate(att['created_at']),
          fileType: att['file_type'] as String? ?? 'file',
          storagePath: storagePath,
          url: signedUrl,
          mimeType: att['mime_type'] as String?,
          fileSizeBytes: sizeBytes,
        ));
      }
    }

    // Map comments
    final commentsList = json['order_comments'] as List<dynamic>? ?? [];
    final comments = commentsList
        .whereType<Map<String, dynamic>>()
        .map(_mapJsonToCommentModel)
        .toList();

    // Map activity logs
    final logsList = json['order_activity_logs'] as List<dynamic>? ?? [];
    final activityLogs = logsList
        .whereType<Map<String, dynamic>>()
        .map((l) => _mapJsonToActivityLogModel(l, orderNumber))
        .toList();

    return OrderModel(
      id: orderNumber,
      supabaseId: supabaseId,
      cardType: cardType,
      deliveryType: deliveryType,
      priority: priority,
      activityStatus: activityStatus,
      assignee: assignee,
      createBy: createBy,
      dateText: dateText,
      standardDate: standardDate,
      attachments: attachments,
      items: items.isNotEmpty ? items : [OrderItemModel(id: orderNumber, deliveryType: deliveryType)],
      errorDetails: json['description'] as String?,
      bankCode: json['bank_code'] as String?,
      bankName: json['bank_name'] as String?,
      paymentMethodCode: json['payment_method_code'] as String?,
      paymentMethod: json['payment_method'] as String?,
      amount: amount,
      statusOrder: statusOrder,
      comments: comments,
      activityLogs: activityLogs,
    );
  }

  CommentModel _mapJsonToCommentModel(Map<String, dynamic> json) {
    final author = _mapJsonToUserModel(json['author']);
    final likesList = json['order_comment_likes'] as List<dynamic>? ?? [];
    final currentUid = _client.auth.currentUser?.id;
    final isLiked = currentUid != null && likesList.any((l) => l is Map && l['user_id'] == currentUid);

    return CommentModel(
      id: json['id'] as String? ?? '',
      caseId: json['order_id'] as String? ?? '',
      author: author,
      content: json['content'] as String? ?? '',
      dateText: _formatDate(json['created_at']),
      likes: likesList.length,
      isLiked: isLiked,
    );
  }

  ActivityLogModel _mapJsonToActivityLogModel(Map<String, dynamic> json, String orderNo) {
    String authorName = 'System';
    if (json['author'] is Map<String, dynamic>) {
      final name = (json['author']['full_name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) authorName = name;
    }

    return ActivityLogModel(
      id: json['id'] as String? ?? '',
      caseId: orderNo,
      title: json['title'] as String? ?? '',
      authorName: authorName,
      dateText: _formatDate(json['created_at']),
      icon: _parseIcon(json['icon'] as String?),
      iconColor: _parseColor(json['icon_color'] as String?, Colors.blue),
      iconBgColor: _parseColor(json['icon_bg_color'] as String?, const Color(0xFFDBEAFE)),
    );
  }

  UserModel _mapJsonToUserModel(dynamic json) {
    if (json == null || json is! Map<String, dynamic>) {
      return const UserModel(
        id: 'EMP-000',
        name: 'Unknown User',
        role: 'user',
        email: '',
        avatarUrl: 'U',
      );
    }
    final authId = json['id']?.toString();
    final rawEmpCode = (json['employee_code'] as String?)?.trim();
    final employeeCode = (rawEmpCode != null && rawEmpCode.isNotEmpty)
        ? rawEmpCode
        : (authId != null && authId.length >= 6
            ? 'EMP-${authId.substring(0, 6).toUpperCase()}'
            : 'EMP-000');
    final fullName = json['full_name'] as String? ?? 'User';
    final email = json['email'] as String? ?? '';
    final role = json['role'] as String? ?? 'user';
    final avatarLetter = fullName.isNotEmpty ? fullName.substring(0, 1).toUpperCase() : 'U';

    return UserModel(
      id: employeeCode,
      authUserId: authId,
      name: fullName,
      role: role,
      email: email,
      password: '',
      avatarUrl: avatarLetter,
      phoneNumber: json['phone_number'] as String?,
      position: role.toUpperCase(),
    );
  }

  OrderCardType _parseCardType(String? value) {
    if (value == 'bank_issue' || value == 'bankIssue') {
      return OrderCardType.bankIssue;
    }
    return OrderCardType.orderDiff;
  }

  DeliveryType _parseDeliveryType(String? value) {
    switch (value?.toLowerCase()) {
      case 'sameday':
        return DeliveryType.sameday;
      case 'nextday':
        return DeliveryType.nextday;
      case 'normal':
        return DeliveryType.normal;
      default:
        return DeliveryType.express;
    }
  }

  CasePriority _parsePriority(String? value) {
    switch (value?.toLowerCase()) {
      case 'low':
        return CasePriority.low;
      case 'high':
        return CasePriority.high;
      case 'critical':
        return CasePriority.critical;
      default:
        return CasePriority.medium;
    }
  }

  OrderActivityStatus _parseActivityStatus(String? value) {
    switch (value) {
      case 'inProgress':
        return OrderActivityStatus.inProgress;
      case 'investigating':
        return OrderActivityStatus.investigating;
      case 'resolved':
        return OrderActivityStatus.resolved;
      case 'closed':
        return OrderActivityStatus.closed;
      case 'newOrder':
      case 'pending':
      default:
        return OrderActivityStatus.newOrder;
    }
  }

  IconData _parseIcon(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'add_circle':
        return Icons.add_circle;
      case 'person':
      case 'person_add':
        return Icons.person_add;
      case 'swap_horiz':
      case 'sync':
        return Icons.sync;
      case 'payments':
        return Icons.payments_outlined;
      case 'account_balance':
        return Icons.account_balance_outlined;
      case 'delete':
        return Icons.delete_outline;
      case 'restore':
        return Icons.restore;
      default:
        return Icons.history;
    }
  }

  Color _parseColor(String? colorStr, Color defaultColor) {
    if (colorStr == null) return defaultColor;
    switch (colorStr.toLowerCase()) {
      case 'green':
        return Colors.green;
      case 'lightgreen':
        return const Color(0xFFDCFCE7);
      case 'blue':
        return Colors.blue;
      case 'lightblue':
        return const Color(0xFFDBEAFE);
      case 'orange':
        return Colors.orange;
      case 'moccasin':
        return const Color(0xFFFFEDD5);
      case 'purple':
        return Colors.purple;
      case 'lavender':
        return const Color(0xFFF3E8FF);
      case 'red':
      case 'darkred':
        return Colors.red;
      case 'lightcoral':
      case 'mistyrose':
        return const Color(0xFFFEE2E2);
      case 'teal':
        return Colors.teal;
      case 'lightcyan':
        return const Color(0xFFCCFBF1);
      case 'gray':
        return Colors.blueGrey;
      case 'lightgray':
        return const Color(0xFFF1F5F9);
      default:
        return defaultColor;
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

  String? _formatStandardDate(dynamic timestampStr) {
    if (timestampStr == null) return null;
    try {
      final dt = DateTime.parse(timestampStr.toString()).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }
}
