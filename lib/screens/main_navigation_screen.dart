import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/role_permission.dart';
import '../services/notification_service.dart';
import 'dashboard_screen.dart';
import 'order_list_screen.dart';
import 'case_list_screen.dart';
import 'case_detail_screen.dart';
import 'order_detail_screen.dart';
import 'notification_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.onNotificationOpened = _handlePushNavigation;
    NotificationService.onForegroundMessage = _handleForegroundPush;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialMsg = NotificationService.consumeInitialMessage();
      if (initialMsg != null) {
        _handlePushNavigation(initialMsg);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      Provider.of<AppState>(context, listen: false).syncAllFromSupabase();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (NotificationService.onNotificationOpened == _handlePushNavigation) {
      NotificationService.onNotificationOpened = null;
    }
    if (NotificationService.onForegroundMessage == _handleForegroundPush) {
      NotificationService.onForegroundMessage = null;
    }
    super.dispose();
  }

  void _handleForegroundPush(RemoteMessage message) {
    if (!mounted) return;
    final title = message.notification?.title ?? message.data['title']?.toString() ?? 'การแจ้งเตือนใหม่';
    final body = message.notification?.body ?? message.data['body']?.toString() ?? '';
    final hasTarget = (message.data['reference_id']?.toString() ?? '').isNotEmpty;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content: Text(body.isNotEmpty ? '$title\n$body' : title),
        action: hasTarget
            ? SnackBarAction(
                label: 'ดูเลย',
                textColor: Colors.white,
                onPressed: () => _handlePushNavigation(message),
              )
            : null,
      ),
    );
  }

  void _handlePushNavigation(RemoteMessage message) {
    if (!mounted) return;
    final appState = Provider.of<AppState>(context, listen: false);
    final notifId = message.data['notification_id']?.toString() ?? '';
    final module = (message.data['module']?.toString() ?? '').toLowerCase();
    final refId = message.data['reference_id']?.toString() ?? '';

    if (notifId.isNotEmpty) {
      appState.markNotificationRead(notifId);
    }

    if (module == 'case' && refId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: refId)),
      );
    } else if ((module == 'order_diff' || module == 'bank_issue') && refId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: refId)),
      );
    } else {
      appState.setNavIndex(3); // Notifications tab
    }
  }

  void _onTabTapped(BuildContext context, AppState appState, int index) {
    final role = appState.currentUser.roleEnum;
    bool canAccess = true;

    // Check if user has permission to access specific navigation tab
    if (index == 2) {
      // Case List tab - accessible to all, content filtered per role
      canAccess = RolePermissionHelper.hasPermission(role, Permission.viewOwnCases) ||
          RolePermissionHelper.hasPermission(role, Permission.viewTeamCases) ||
          RolePermissionHelper.hasPermission(role, Permission.viewAllCases);
    }

    if (canAccess) {
      appState.setNavIndex(index);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('คุณไม่มีสิทธิ์เข้าถึงหน้านี้'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    final pages = [
      const DashboardScreen(),
      const OrderListScreen(),
      const CaseListScreen(),
      const NotificationScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: appState.selectedNavIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.cardBorder, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: appState.selectedNavIndex,
          onTap: (index) => _onTabTapped(context, appState, index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'หน้าแรก',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined),
              activeIcon: Icon(Icons.shopping_bag),
              label: 'ออเดอร์ทั้งหมด',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: 'เคสทั้งหมด',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications_none),
                  if (appState.unreadNotificationCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          '${appState.unreadNotificationCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              activeIcon: Stack(
                children: [
                  const Icon(Icons.notifications),
                  if (appState.unreadNotificationCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 12,
                          minHeight: 12,
                        ),
                        child: Text(
                          '${appState.unreadNotificationCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              label: 'แจ้งเตือน',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'โปรไฟล์',
            ),
          ],
        ),
      ),
    );
  }
}
