import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_models.dart';

class NotificationRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<AppNotificationModel>> loadNotifications({int limit = 100}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final response = await _client
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(limit);

      final list = response as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(mapJsonToNotification)
          .toList();
    } on PostgrestException catch (e) {
      throw Exception('Database Error loading notifications (${e.code}): ${e.message}');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('[NotificationRepository.markAsRead] Error: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('[NotificationRepository.markAllAsRead] Error: $e');
    }
  }

  RealtimeChannel subscribeToNotifications({
    required String userId,
    required void Function(AppNotificationModel notification) onInsert,
  }) {
    final channel = _client.channel('public:notifications:$userId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              onInsert(mapJsonToNotification(record));
            }
          },
        )
        .subscribe();
    return channel;
  }

  Future<void> unsubscribe(RealtimeChannel? channel) async {
    if (channel == null) return;
    try {
      await _client.removeChannel(channel);
    } catch (_) {}
  }

  Future<void> registerDeviceToken({
    required String fcmToken,
    required String platform,
    String? deviceInfo,
  }) async {
    final trimmed = fcmToken.trim();
    if (trimmed.isEmpty) return;

    try {
      await _client.rpc(
        'upsert_device_token',
        params: {
          'p_token': trimmed,
          'p_platform': platform,
          'p_device_info': deviceInfo,
        },
      );
    } catch (e) {
      debugPrint('[NotificationRepository.registerDeviceToken] Error: $e');
    }
  }

  Future<void> removeDeviceToken(String fcmToken) async {
    final trimmed = fcmToken.trim();
    if (trimmed.isEmpty) return;

    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client
          .from('user_device_tokens')
          .delete()
          .eq('user_id', user.id)
          .eq('fcm_token', trimmed);
    } catch (e) {
      debugPrint('[NotificationRepository.removeDeviceToken] Error: $e');
    }
  }

  AppNotificationModel mapJsonToNotification(Map<String, dynamic> json) {
    final moduleStr = (json['module'] as String? ?? 'case').toLowerCase();
    final module = _parseModule(moduleStr);
    final refId = json['reference_id'] as String?;

    return AppNotificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      timeAgo: _formatTimeAgo(json['created_at']),
      icon: _parseIcon(json['icon_name'] as String?),
      iconColor: _parseHexColor(json['icon_color'] as String?, const Color(0xFF2563EB)),
      iconBg: _parseHexColor(json['icon_bg_color'] as String?, const Color(0xFFDBEAFE)),
      isRead: json['is_read'] as bool? ?? false,
      module: module,
      referenceId: refId,
      caseId: refId,
      targetUserId: json['user_id']?.toString(),
      actorUserId: json['actor_id']?.toString(),
    );
  }

  NotificationModule _parseModule(String value) {
    switch (value) {
      case 'order_diff':
      case 'orderdiff':
        return NotificationModule.orderDiff;
      case 'bank_issue':
      case 'bankissue':
        return NotificationModule.bankIssue;
      case 'system':
        return NotificationModule.system;
      default:
        return NotificationModule.caseModule;
    }
  }

  IconData _parseIcon(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'person_add':
        return Icons.person_add_outlined;
      case 'chat_bubble':
        return Icons.chat_bubble_outline;
      case 'swap_horiz':
        return Icons.swap_horiz;
      case 'sync':
        return Icons.sync;
      case 'inventory_2':
        return Icons.inventory_2_outlined;
      case 'account_balance':
        return Icons.account_balance_outlined;
      case 'check_circle':
        return Icons.check_circle_outline;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _parseHexColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      var cleaned = hex.trim().replaceAll('#', '');
      if (cleaned.startsWith('0x') || cleaned.startsWith('0X')) {
        cleaned = cleaned.substring(2);
      }
      if (cleaned.length == 6) {
        cleaned = 'FF$cleaned';
      }
      final val = int.tryParse(cleaned, radix: 16);
      if (val != null) return Color(val);
    } catch (_) {}
    return fallback;
  }

  String _formatTimeAgo(dynamic timestampStr) {
    if (timestampStr == null) return '';
    try {
      final dt = DateTime.parse(timestampStr.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'เมื่อสักครู่';
      if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
      if (diff.inHours < 24) return '${diff.inHours} ชม. ที่ผ่านมา';
      if (diff.inDays < 7) return '${diff.inDays} วันที่ผ่านมา';

      const thaiMonths = ['', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
      return '${dt.day} ${thaiMonths[dt.month]} ${dt.year + 543}';
    } catch (_) {
      return timestampStr.toString();
    }
  }
}
