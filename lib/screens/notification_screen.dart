import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import 'case_detail_screen.dart';
import 'order_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _showOnlyUnread = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final unreadCount = appState.unreadNotificationCount;

    var notifs = _showOnlyUnread
        ? appState.currentUserNotifications.where((n) => !n.isRead).toList()
        : appState.currentUserNotifications;

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      notifs = notifs.where((n) {
        final matchTitle = n.title.toLowerCase().contains(query);
        final matchSubtitle = n.subtitle.toLowerCase().contains(query);
        final matchCaseId = n.caseId != null && n.caseId!.toLowerCase().contains(query);
        final matchReferenceId = n.referenceId != null && n.referenceId!.toLowerCase().contains(query);
        final matchTargetUser = n.targetUserName != null && n.targetUserName!.toLowerCase().contains(query);
        return matchTitle || matchSubtitle || matchCaseId || matchReferenceId || matchTargetUser;
      }).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              )
            : null,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'ค้นหาข้อความ, รหัสเคส, รหัสออเดอร์...',
                  hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                ),
              )
            : const Text(
                'การแจ้งเตือน',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search, color: AppColors.textPrimary),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          if (!_isSearching && unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.done_all, color: AppColors.primary),
              tooltip: 'อ่านทั้งหมด',
              onPressed: () {
                appState.markAllNotificationsRead();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs Area
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildTabChip(
                  label: 'ทั้งหมด',
                  isSelected: !_showOnlyUnread,
                  onTap: () => setState(() => _showOnlyUnread = false),
                ),
                const SizedBox(width: 8),
                _buildTabChip(
                  label: 'ยังไม่ได้อ่าน',
                  badgeCount: unreadCount,
                  isSelected: _showOnlyUnread,
                  onTap: () => setState(() => _showOnlyUnread = true),
                ),
              ],
            ),
          ),

          // Notifications List
          Expanded(
            child: notifs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty ? Icons.search_off : Icons.notifications_off_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'ไม่พบการแจ้งเตือนที่ค้นหา "$_searchQuery"'
                              : 'ไม่มีการแจ้งเตือน',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: notifs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.cardBorder),
                    itemBuilder: (context, index) {
                      final notif = notifs[index];
                      return _buildNotificationTile(context, notif, appState);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip({
    required String label,
    int? badgeCount,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    AppNotificationModel notif,
    AppState appState,
  ) {
    return InkWell(
      onTap: () {
        appState.markNotificationRead(notif.id);
        final refId = notif.referenceId ?? notif.caseId;
        if (refId != null) {
          if (notif.module == NotificationModule.caseModule) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CaseDetailScreen(caseId: refId),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(orderId: refId),
              ),
            );
          }
        }
      },
      child: Container(
        color: notif.isRead ? Colors.transparent : const Color(0xFFEFF6FF),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon Badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: notif.iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(notif.icon, size: 20, color: notif.iconColor),
            ),
            const SizedBox(width: 14),

            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        notif.timeAgo,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (!notif.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
