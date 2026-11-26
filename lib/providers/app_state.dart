import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_models.dart';
import '../models/role_permission.dart';
import '../models/file_attachment_model.dart';
import '../theme/app_theme.dart';
import '../repositories/case_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/notification_repository.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../widgets/attachment_picker_widget.dart';

enum AppDataMode {
  initializing,
  real,
}

class AppState extends ChangeNotifier {
  final CaseRepository caseRepository = CaseRepository();
  final OrderRepository orderRepository = OrderRepository();
  final NotificationRepository notificationRepository = NotificationRepository();
  RealtimeChannel? _notificationsChannel;
  AppDataMode dataMode = AppDataMode.initializing;
  // Active users directory (populated from Supabase public.profiles)
  List<UserModel> registeredUsers = [];

  // Active logged-in user (initialized to empty placeholder until Supabase login)
  UserModel currentUser = const UserModel(
    id: '',
    name: '',
    role: 'user',
    email: '',
    avatarUrl: 'U',
  );

  // Authentication state
  bool isLoggedIn = false;

  // Selected bottom nav index (0: Dashboard, 1: Order List, 2: Case List, 3: Notifications, 4: Profile)
  int selectedNavIndex = 0;

  // Filter criteria for search & filter
  String searchQuery = '';
  CaseStatus? filterStatus;
  CasePriority? filterPriority;
  TeamType? filterTeam;
  String? filterAssignee;
  DateTimeRange? filterDateRange;

  // All cases list
  List<CaseModel> cases = [];

  // All orders list (Order Diff & Bank Issue Cards)
  List<OrderModel> orders = [];

  // Notifications
  List<AppNotificationModel> notifications = [];

  AppState();

  UserModel _mapProfileRowToUserModel(Map<String, dynamic> profile) {
    final authId = profile['id']?.toString();
    final fullName = (profile['full_name'] as String?)?.trim();
    final displayName = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : (profile['email'] as String? ?? 'User');
    final email = profile['email'] as String? ?? '';
    final role = profile['role'] as String? ?? 'user';
    final rawEmpCode = (profile['employee_code'] as String?)?.trim();
    final employeeCode = (rawEmpCode != null && rawEmpCode.isNotEmpty)
        ? rawEmpCode
        : (authId != null && authId.length >= 6
            ? 'EMP-${authId.substring(0, 6).toUpperCase()}'
            : 'EMP-000');
    final teamStatus = profile['team_status'] as String? ?? 'pending';
    final requestedTeamId = profile['requested_team_id'] as String?;
    final isActive = profile['is_active'] as bool? ?? true;
    final phoneNumber = (profile['phone_number'] as String?)?.trim();

    TeamType? teamEnum;
    final teamData = profile['teams'];
    if (teamData != null && teamData is Map<String, dynamic>) {
      final code = (teamData['code'] as String? ?? '').toLowerCase();
      teamEnum = TeamType.values.firstWhere(
        (t) => t.name.toLowerCase() == code,
        orElse: () => TeamType.other,
      );
    }

    final avatarLetter = displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'U';

    return UserModel(
      id: employeeCode,
      authUserId: authId,
      name: displayName,
      role: role,
      email: email,
      password: '',
      avatarUrl: avatarLetter,
      team: teamEnum,
      phoneNumber: (phoneNumber != null && phoneNumber.isNotEmpty) ? phoneNumber : null,
      position: role.toUpperCase(),
      teamStatus: teamStatus,
      requestedTeamId: requestedTeamId,
      isActive: isActive,
    );
  }

  Future<void> loadUsersFromSupabase() async {
    if (dataMode != AppDataMode.real) return;
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('id, employee_code, full_name, email, role, team_id, phone_number, is_active, team_status, requested_team_id, teams!profiles_team_id_fkey(id, name, code)')
          .eq('is_active', true)
          .order('full_name', ascending: true);

      final loaded = (res as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(_mapProfileRowToUserModel)
          .toList();

      if (loaded.isNotEmpty) {
        registeredUsers = loaded;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AppState.loadUsersFromSupabase] Error: $e');
    }
  }

  Future<void> loadCasesFromSupabase() async {
    if (dataMode != AppDataMode.real) return;
    try {
      cases = await caseRepository.loadCases();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadOrdersFromSupabase() async {
    if (dataMode != AppDataMode.real) return;
    try {
      orders = await orderRepository.loadOrders();
      notifyListeners();
    } catch (e) {
      debugPrint('[AppState.loadOrdersFromSupabase] Error: $e');
    }
  }

  Future<void> loadNotificationsFromSupabase() async {
    if (dataMode != AppDataMode.real) return;
    try {
      notifications = await notificationRepository.loadNotifications();
      notifyListeners();
    } catch (e) {
      debugPrint('[AppState.loadNotificationsFromSupabase] Error: $e');
    }
  }

  void _startNotificationsRealtime() {
    final userId = currentUser.authUserId ?? Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    notificationRepository.unsubscribe(_notificationsChannel);
    _notificationsChannel = notificationRepository.subscribeToNotifications(
      userId: userId,
      onInsert: (newNotif) {
        if (!notifications.any((n) => n.id == newNotif.id)) {
          notifications.insert(0, newNotif);
          notifyListeners();
        }
      },
    );
  }

  Future<void> _stopNotificationsRealtime() async {
    await notificationRepository.unsubscribe(_notificationsChannel);
    _notificationsChannel = null;
  }

  Future<void> syncDeviceTokenToSupabase() async {
    if (dataMode != AppDataMode.real) return;

    NotificationService.onTokenRefreshed = (newToken) {
      if (dataMode == AppDataMode.real) {
        notificationRepository.registerDeviceToken(
          fcmToken: newToken,
          platform: NotificationService.currentPlatformName,
        );
      }
    };

    final token = await NotificationService.getToken();
    if (token != null && token.isNotEmpty) {
      await notificationRepository.registerDeviceToken(
        fcmToken: token,
        platform: NotificationService.currentPlatformName,
      );
    }
  }

  String? _findSupabaseOrderId(String orderId) {
    final idx = _findOrderIndex(orderId);
    if (idx != -1 && orders[idx].supabaseId != null && orders[idx].supabaseId!.isNotEmpty) {
      return orders[idx].supabaseId;
    }
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(orderId)) return orderId;
    return null;
  }

  Future<String?> _getTeamUuid(TeamType team) async {
    try {
      final code = team.name.toLowerCase();
      final res = await Supabase.instance.client
          .from('teams')
          .select('id')
          .eq('code', code)
          .maybeSingle();
      return res?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  String? _findSupabaseCaseId(String caseId) {
    final match = cases.firstWhere(
      (c) => c.id == caseId || c.supabaseId == caseId,
      orElse: () => CaseModel(
        id: '',
        title: '',
        priority: CasePriority.low,
        status: CaseStatus.open,
        team: TeamType.web,
        category: '',
        dateText: '',
        systemAffected: '',
        environment: '',
        url: '',
        browser: '',
      ),
    );
    return match.supabaseId;
  }

  Future<String?> _getOrFetchSupabaseCaseId(String caseId) async {
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (uuidRegex.hasMatch(caseId)) {
      return caseId;
    }

    final localId = _findSupabaseCaseId(caseId);
    if (localId != null && uuidRegex.hasMatch(localId)) {
      return localId;
    }

    try {
      final res = await Supabase.instance.client
          .from('cases')
          .select('id')
          .eq('case_no', caseId)
          .maybeSingle();
      final fetchedId = res?['id'] as String?;
      if (fetchedId != null && uuidRegex.hasMatch(fetchedId)) {
        return fetchedId;
      }
    } catch (e) {
      debugPrint('[AppState._getOrFetchSupabaseCaseId] Error fetching UUID for $caseId: $e');
    }

    return localId;
  }

  Future<void> loginWithSupabaseProfile(Map<String, dynamic> profile) async {
    currentUser = _mapProfileRowToUserModel(profile);

    dataMode = AppDataMode.real;
    isLoggedIn = true;
    selectedNavIndex = 0;
    registeredUsers = [currentUser];
    cases = [];
    orders = [];
    notifications = [];
    notifyListeners();
    await Future.wait([
      loadUsersFromSupabase(),
      loadCasesFromSupabase(),
      loadOrdersFromSupabase(),
      loadNotificationsFromSupabase(),
    ]);
    _startNotificationsRealtime();
    // Register FCM token in background without blocking navigation
    syncDeviceTokenToSupabase();
  }

  Future<bool> requestTeam(String teamId) async {
    try {
      final response = await Supabase.instance.client.rpc('request_team', params: {'p_team_id': teamId});
      if (response == true || response == null) {
        await refreshProfile();
        return true;
      }
      return response == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> refreshProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profileRes = await Supabase.instance.client
            .from('profiles')
            .select('*, teams!profiles_team_id_fkey(id, name, code), requested_team:teams!profiles_requested_team_id_fkey(id, name, code)')
            .eq('id', user.id)
            .maybeSingle();
        if (profileRes != null) {
          await loginWithSupabaseProfile(profileRes);
        }
      }
    } catch (_) {}
  }

  Future<bool> approveTeam(String userId) async {
    try {
      final response = await Supabase.instance.client.rpc('approve_team', params: {'p_user_id': userId});
      return response == true || response == null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectTeam(String userId) async {
    try {
      final response = await Supabase.instance.client.rpc('reject_team', params: {'p_user_id': userId});
      return response == true || response == null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setProfileRole(String profileId, String newRole) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'devc_case_set_profile_role',
        params: {
          'p_profile_id': profileId,
          'p_new_role': newRole,
        },
      );
      return response == true || response == null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setProfileTeam(String profileId, String teamId) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'devc_case_set_profile_team',
        params: {
          'p_profile_id': profileId,
          'p_team_id': teamId,
        },
      );
      return response == true || response == null;
    } catch (_) {
      return false;
    }
  }

  // Set active tab index
  void setNavIndex(int index) {
    selectedNavIndex = index;
    notifyListeners();
  }

  bool _isWithinDateRange(String standardDateStr, DateTimeRange? range) {
    if (range == null) return true;
    final dt = DateTime.tryParse(standardDateStr);
    if (dt == null) return true;
    final dayOnly = DateTime(dt.year, dt.month, dt.day);
    final startOnly = DateTime(range.start.year, range.start.month, range.start.day);
    final endOnly = DateTime(range.end.year, range.end.month, range.end.day);
    return !dayOnly.isBefore(startOnly) && !dayOnly.isAfter(endOnly);
  }

  // Filter getters with Case Access Control per Role
  List<CaseModel> get filteredCases {
    return cases.where((c) {
      // 0. Case Access Control Check
      if (!RolePermissionHelper.canAccessCase(currentUser, c)) {
        return false;
      }

      // Search query
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final matchId = c.id.toLowerCase().contains(query);
        final matchTitle = c.title.toLowerCase().contains(query);
        final matchAssignee = c.assignee != null && c.assignee!.name.toLowerCase().contains(query);
        final matchSystem = c.systemAffected.toLowerCase().contains(query);
        final matchUrl = c.url.toLowerCase().contains(query);
        final matchBrowser = c.browser.toLowerCase().contains(query);
        final matchCategory = c.category.toLowerCase().contains(query);
        if (!matchId && !matchTitle && !matchAssignee && !matchSystem && !matchUrl && !matchBrowser && !matchCategory) return false;
      }

      // Status filter
      if (filterStatus != null && c.status != filterStatus) {
        return false;
      }

      // Priority filter
      if (filterPriority != null && c.priority != filterPriority) {
        return false;
      }

      // Team filter
      if (filterTeam != null && c.team != filterTeam) {
        return false;
      }

      // Assignee filter
      if (filterAssignee != null && filterAssignee!.isNotEmpty && filterAssignee != 'ทั้งหมด') {
        if (c.assignee?.name != filterAssignee) return false;
      }

      // Date range filter
      if (filterDateRange != null && !_isWithinDateRange(parseDateToStandard(c.dateText), filterDateRange)) {
        return false;
      }

      return true;
    }).toList();
  }

  // Order filters state
  String orderSearchQuery = '';
  OrderCardType? filterOrderCardType;
  DeliveryType? filterOrderDeliveryType;
  OrderActivityStatus? filterOrderActivityStatus;
  CasePriority? filterOrderPriority;
  DateTimeRange? filterOrderDateRange;

  void setOrderFilters({
    String? query,
    OrderCardType? cardType,
    bool clearCardType = false,
    DeliveryType? deliveryType,
    bool clearDeliveryType = false,
    OrderActivityStatus? activityStatus,
    bool clearActivityStatus = false,
    CasePriority? priority,
    bool clearPriority = false,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
    bool clearAll = false,
  }) {
    if (clearAll) {
      orderSearchQuery = '';
      filterOrderCardType = null;
      filterOrderDeliveryType = null;
      filterOrderActivityStatus = null;
      filterOrderPriority = null;
      filterOrderDateRange = null;
    } else {
      if (query != null) orderSearchQuery = query;
      if (clearCardType) {
        filterOrderCardType = null;
      } else if (cardType != null) {
        filterOrderCardType = cardType;
      }
      if (clearDeliveryType) {
        filterOrderDeliveryType = null;
      } else if (deliveryType != null) {
        filterOrderDeliveryType = deliveryType;
      }
      if (clearActivityStatus) {
        filterOrderActivityStatus = null;
      } else if (activityStatus != null) {
        filterOrderActivityStatus = activityStatus;
      }
      if (clearPriority) {
        filterOrderPriority = null;
      } else if (priority != null) {
        filterOrderPriority = priority;
      }
      if (clearDateRange) {
        filterOrderDateRange = null;
      } else if (dateRange != null) {
        filterOrderDateRange = dateRange;
      }
    }
    notifyListeners();
  }

  // Filter getters with Order Access Control and Filters per Role
  List<OrderModel> get filteredOrders {
    return orders.where((o) {
      if (!OrderRolePermissionHelper.canAccessOrder(currentUser, o)) {
        return false;
      }

      // Search query
      if (orderSearchQuery.trim().isNotEmpty) {
        final q = orderSearchQuery.trim().toLowerCase();
        final matchId = o.id.toLowerCase().contains(q) ||
            o.allItems.any((item) => item.id.toLowerCase().contains(q));
        final matchCreateBy = o.createBy.toLowerCase().contains(q);
        final matchAssignee = o.assignee?.name.toLowerCase().contains(q) ?? false;
        final matchError = o.errorDetails?.toLowerCase().contains(q) ?? false;
        final matchBank = o.bankName?.toLowerCase().contains(q) ?? false;
        final matchPayment = o.paymentMethod?.toLowerCase().contains(q) ?? false;
        if (!matchId && !matchCreateBy && !matchAssignee && !matchError && !matchBank && !matchPayment) return false;
      }

      // Card Type filter
      if (filterOrderCardType != null && o.cardType != filterOrderCardType) {
        return false;
      }

      // Delivery Type filter
      if (filterOrderDeliveryType != null && o.deliveryType != filterOrderDeliveryType) {
        return false;
      }

      // Activity Status filter
      if (filterOrderActivityStatus != null && o.activityStatus != filterOrderActivityStatus) {
        return false;
      }

      // Priority filter
      if (filterOrderPriority != null && o.priority != filterOrderPriority) {
        return false;
      }

      // Date range filter
      if (filterOrderDateRange != null && !_isWithinDateRange(o.effectiveStandardDate, filterOrderDateRange)) {
        return false;
      }

      return true;
    }).toList();
  }

  // User-specific notification getters
  List<AppNotificationModel> get currentUserNotifications {
    if (dataMode == AppDataMode.real) {
      return notifications;
    }
    return notifications.where((n) {
      return n.targetUserId == currentUser.id;
    }).toList();
  }

  void _sendNotification({
    required NotificationModule module,
    required String referenceId,
    required UserModel? assignee,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    UserModel? oldAssignee,
  }) {
    if (oldAssignee != null && oldAssignee.id != currentUser.id && oldAssignee.id != assignee?.id) {
      notifications.insert(
        0,
        AppNotificationModel(
          id: 'notif-${DateTime.now().millisecondsSinceEpoch}-${oldAssignee.id}',
          title: title,
          subtitle: subtitle,
          timeAgo: 'เมื่อสักครู่',
          icon: icon,
          iconColor: iconColor,
          iconBg: iconBg,
          isRead: false,
          module: module,
          referenceId: referenceId,
          caseId: referenceId,
          targetUserId: oldAssignee.id,
          targetUserName: oldAssignee.name,
          actorUserId: currentUser.id,
        ),
      );
    }

    if (assignee != null && assignee.id != currentUser.id) {
      if (oldAssignee?.id != assignee.id) {
        notifications.insert(
          0,
          AppNotificationModel(
            id: 'notif-${DateTime.now().millisecondsSinceEpoch}-${assignee.id}',
            title: title,
            subtitle: subtitle,
            timeAgo: 'เมื่อสักครู่',
            icon: icon,
            iconColor: iconColor,
            iconBg: iconBg,
            isRead: false,
            module: module,
            referenceId: referenceId,
            caseId: referenceId,
            targetUserId: assignee.id,
            targetUserName: assignee.name,
            actorUserId: currentUser.id,
          ),
        );
      }
    } else if (assignee == null) {
      notifications.insert(
        0,
        AppNotificationModel(
          id: 'notif-${DateTime.now().millisecondsSinceEpoch}-${currentUser.id}',
          title: title,
          subtitle: subtitle,
          timeAgo: 'เมื่อสักครู่',
          icon: icon,
          iconColor: iconColor,
          iconBg: iconBg,
          isRead: false,
          module: module,
          referenceId: referenceId,
          caseId: referenceId,
          targetUserId: currentUser.id,
          targetUserName: currentUser.name,
          actorUserId: currentUser.id,
        ),
      );
    }
  }

  // Case Stats Getters
  int get openCount => cases.where((c) => c.status == CaseStatus.open).length;
  int get inProgressCount => cases.where((c) => c.status == CaseStatus.inProgress).length;
  int get doneCount => cases.where((c) => c.status == CaseStatus.done).length;
  int get closedCount => cases.where((c) => c.status == CaseStatus.closed).length;

  int get teamWebCount => cases.where((c) => c.team == TeamType.web).length;
  int get teamMobileCount => cases.where((c) => c.team == TeamType.mobile).length;
  int get teamBackendCount => cases.where((c) => c.team == TeamType.backend).length;
  int get teamInfraCount => cases.where((c) => c.team == TeamType.infra).length;
  int get teamOtherCount => cases.where((c) => c.team == TeamType.other).length;

  int get priorityHighCount => cases.where((c) => c.priority == CasePriority.high).length;
  int get priorityMediumCount => cases.where((c) => c.priority == CasePriority.medium).length;
  int get priorityLowCount => cases.where((c) => c.priority == CasePriority.low).length;
  int get priorityCriticalCount => cases.where((c) => c.priority == CasePriority.critical).length;

  // Order Stats Getters
  int get orderTotalCount => orders.length;
  int get orderDiffCount => orders.where((o) => o.cardType == OrderCardType.orderDiff).length;
  int get bankIssueCount => orders.where((o) => o.cardType == OrderCardType.bankIssue).length;
  int get orderCompletedCount => orders.where((o) => o.statusOrder == OrderStatus.completed).length;
  int get orderClosedCount => orders.where((o) => o.activityStatus == OrderActivityStatus.closed).length;
  int get orderPendingCount => orders.where((o) => o.statusOrder == OrderStatus.pending).length;
  int get orderWaitingPaymentCount => orders.where((o) => o.statusOrder == OrderStatus.waitingPayment).length;

  // User-Assigned Dashboard Order Getters
  List<OrderModel> get myOrders {
    return orders.where((o) => o.assignee != null && o.assignee == currentUser).toList();
  }

  int get myOrderTotalCount => myOrders.length;
  int get myOrderDiffCount => myOrders.where((o) => o.cardType == OrderCardType.orderDiff).length;
  int get myBankIssueCount => myOrders.where((o) => o.cardType == OrderCardType.bankIssue).length;
  int get myOrderClosedCount => myOrders.where((o) => o.activityStatus == OrderActivityStatus.closed).length;

  /// Groups orders into display cards by:
  ///   (calendar day [effectiveStandardDate], cardType [orderDiff vs bankIssue], assignee [user or UNASSIGNED])
  /// - Multiple orders on the same day for the same assignee & same cardType combine into 1 card.
  /// - Different assignees on the same day get separate cards.
  /// - Unassigned orders on the same day combine into 1 card per cardType (orderDiff / bankIssue).
  /// - Individual OrderModel records remain intact so tapping any order chip opens its own OrderDetailScreen.
  static List<OrderModel> groupOrdersIntoCards(List<OrderModel> sourceOrders) {
    final Map<String, List<OrderModel>> buckets = {};

    for (final order in sourceOrders) {
      final dateKey = order.effectiveStandardDate;
      final typeKey = order.cardType.name;
      final assigneeKey = order.assignee == null
          ? 'UNASSIGNED'
          : (order.assignee!.authUserId ?? order.assignee!.id);
      final groupKey = '$dateKey|$typeKey|$assigneeKey';
      buckets.putIfAbsent(groupKey, () => []).add(order);
    }

    final List<OrderModel> cards = [];
    for (final group in buckets.values) {
      final primary = group.first;
      final List<OrderItemModel> mergedItems = [];
      final Set<String> seenItemIds = {};

      for (final o in group) {
        for (final item in o.allItems) {
          final normId = item.id.trim().toLowerCase();
          if (normId.isNotEmpty && seenItemIds.add(normId)) {
            mergedItems.add(item);
          }
        }
      }

      cards.add(
        primary.copyWith(
          dateText: _formatGroupDayLabel(primary.effectiveStandardDate, primary.dateText),
          standardDate: primary.effectiveStandardDate,
          items: mergedItems,
        ),
      );
    }

    // Sort: newest day first -> assigned before unassigned -> orderDiff before bankIssue
    cards.sort((a, b) {
      final dateCmp = b.effectiveStandardDate.compareTo(a.effectiveStandardDate);
      if (dateCmp != 0) return dateCmp;

      final aUnassigned = a.assignee == null ? 1 : 0;
      final bUnassigned = b.assignee == null ? 1 : 0;
      if (aUnassigned != bUnassigned) return aUnassigned.compareTo(bUnassigned);

      if (a.cardType != b.cardType) {
        return a.cardType == OrderCardType.orderDiff ? -1 : 1;
      }

      final aName = a.assignee?.name.toLowerCase() ?? '';
      final bName = b.assignee?.name.toLowerCase() ?? '';
      return aName.compareTo(bName);
    });

    return cards;
  }

  static String _formatGroupDayLabel(String standardDate, String fallbackDateText) {
    try {
      final parts = standardDate.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);
        const thaiMonths = [
          '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
          'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
        ];
        if (month >= 1 && month <= 12) {
          return '$day ${thaiMonths[month]} ${year + 543}';
        }
      }
    } catch (_) {}
    return fallbackDateText;
  }

  List<OrderModel> get groupedOrders => groupOrdersIntoCards(
        orders.where((o) => OrderRolePermissionHelper.canAccessOrder(currentUser, o)).toList(),
      );

  List<OrderModel> get groupedFilteredOrders => groupOrdersIntoCards(filteredOrders);

  List<OrderModel> get groupedMyOrders => groupOrdersIntoCards(myOrders);

  int get groupedOrderDiffCount =>
      groupedOrders.where((o) => o.cardType == OrderCardType.orderDiff).length;

  int get groupedBankIssueCount =>
      groupedOrders.where((o) => o.cardType == OrderCardType.bankIssue).length;

  Future<void> createOrderCard({
    required OrderCardType cardType,
    required String orderNo,
    required DeliveryType deliveryType,
    required CasePriority priority,
    UserModel? assignee,
    required String createBy,
    String? importFile,
    List<AttachmentModel> attachments = const [],
    List<PendingFileAttachment>? pendingFiles,
    String? errorDetails,
    String? bankCode,
    String? bankName,
    String? paymentMethodCode,
    String? paymentMethod,
    double? amount,
    OrderStatus? statusOrder,
  }) async {
    final generated6Digit = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    final finalOrderNo = orderNo.trim().isNotEmpty ? orderNo.trim() : generated6Digit;

    if (dataMode == AppDataMode.real) {
      final created = await orderRepository.createOrder(
        orderNumber: finalOrderNo,
        cardType: cardType,
        deliveryType: deliveryType,
        priority: priority,
        assigneeId: assignee?.authUserId,
        errorDetails: errorDetails,
        bankCode: bankCode,
        bankName: bankName,
        paymentMethodCode: paymentMethodCode,
        paymentMethod: paymentMethod,
        amount: amount,
        statusOrder: statusOrder,
      );

      if (pendingFiles != null && pendingFiles.isNotEmpty && created.supabaseId != null) {
        final List<String> uploadErrors = [];
        for (final pf in pendingFiles) {
          final bytes = await pf.getBytes();
          if (bytes != null) {
            try {
              await orderRepository.uploadOrderAttachment(
                supabaseOrderId: created.supabaseId!,
                fileBytes: bytes,
                fileName: pf.name,
                fileType: pf.extension,
                fileSizeBytes: pf.sizeBytes,
                mimeType: pf.mimeType,
              );
            } catch (e) {
              uploadErrors.add('${pf.name}: ${e.toString().replaceAll('Exception: ', '')}');
            }
          }
        }
        await loadOrdersFromSupabase();
        if (uploadErrors.isNotEmpty) {
          throw Exception('สร้างออเดอร์สำเร็จ แต่อัปโหลดไฟล์แนบไม่ผ่าน:\n${uploadErrors.join('\n')}');
        }
        return;
      }

      await loadOrdersFromSupabase();
      return;
    }

    final initialLogs = [
      ActivityLogModel(
        id: 'ord-act-${DateTime.now().millisecondsSinceEpoch}',
        caseId: finalOrderNo,
        title: 'สร้างการ์ดออเดอร์ใหม่',
        authorName: createBy,
        dateText: 'วันนี้',
        icon: Icons.add_circle,
        iconColor: Colors.blue,
        iconBgColor: const Color(0xFFDBEAFE),
      ),
    ];

    List<AttachmentModel> finalAttachments = List.from(attachments);
    if (pendingFiles != null && pendingFiles.isNotEmpty) {
      for (var pf in pendingFiles) {
        finalAttachments.add(AttachmentModel(
          id: 'att-${DateTime.now().millisecondsSinceEpoch}-${pf.name.hashCode}',
          name: pf.name,
          size: pf.formattedSize,
          dateText: 'วันนี้',
          fileType: pf.extension,
          fileSizeBytes: pf.sizeBytes,
        ));
      }
    }

    if (finalAttachments.isEmpty && importFile != null && importFile.trim().isNotEmpty) {
      final ext = importFile.contains('.') ? importFile.split('.').last.toLowerCase() : 'xlsx';
      finalAttachments.add(AttachmentModel(
        id: 'att-${DateTime.now().millisecondsSinceEpoch}',
        name: importFile.trim(),
        size: '1.2 MB',
        dateText: 'วันนี้',
        fileType: ext,
      ));
    }

    final todayStr = 'วันนี้';
    final todayStandardDate = parseDateToStandard('วันนี้');
    final existingCardIndex = orders.indexWhere(
      (o) => o.cardType == cardType &&
             o.effectiveStandardDate == todayStandardDate &&
             o.assignee?.id == assignee?.id,
    );

    if (existingCardIndex != -1) {
      final existingCard = orders[existingCardIndex];
      final currentItems = List<OrderItemModel>.from(existingCard.allItems);

      if (!currentItems.any((item) => item.id.trim().toLowerCase() == finalOrderNo.toLowerCase())) {
        currentItems.add(OrderItemModel(id: finalOrderNo, deliveryType: deliveryType));
      }

      final updatedLogs = [...existingCard.activityLogs, ...initialLogs];
      final updatedAttachments = [...existingCard.attachments, ...finalAttachments];

      orders[existingCardIndex] = existingCard.copyWith(
        items: currentItems,
        activityLogs: updatedLogs,
        attachments: updatedAttachments,
      );
    } else {
      final newItem = OrderItemModel(id: finalOrderNo, deliveryType: deliveryType);
      final newOrder = OrderModel(
        id: finalOrderNo,
        cardType: cardType,
        deliveryType: deliveryType,
        priority: priority,
        assignee: assignee,
        createBy: createBy,
        dateText: todayStr,
        standardDate: todayStandardDate,
        importFile: importFile,
        attachments: finalAttachments,
        items: [newItem],
        errorDetails: errorDetails,
        bankCode: bankCode,
        bankName: bankName,
        paymentMethodCode: paymentMethodCode,
        paymentMethod: paymentMethod,
        amount: amount,
        statusOrder: statusOrder ?? OrderStatus.pending,
        activityLogs: initialLogs,
      );

      orders.insert(0, newOrder);
    }

    final orderMod = cardType == OrderCardType.orderDiff ? NotificationModule.orderDiff : NotificationModule.bankIssue;
    notifications.insert(
      0,
      AppNotificationModel(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}-${currentUser.id}',
        title: 'สร้างการ์ดออเดอร์สำเร็จ ($finalOrderNo)',
        subtitle: 'ประเภท: ${cardType.label}',
        timeAgo: 'เมื่อสักครู่',
        icon: Icons.check_circle_outline,
        iconColor: const Color(0xFF16A34A),
        iconBg: const Color(0xFFDCFCE7),
        isRead: false,
        module: orderMod,
        referenceId: finalOrderNo,
        caseId: finalOrderNo,
        targetUserId: currentUser.id,
        targetUserName: currentUser.name,
        actorUserId: currentUser.id,
      ),
    );

    _sendNotification(
      module: orderMod,
      referenceId: finalOrderNo,
      assignee: assignee,
      title: assignee != null ? 'คุณได้รับมอบหมายการ์ดออเดอร์ $finalOrderNo' : 'สร้างการ์ดออเดอร์ใหม่ $finalOrderNo',
      subtitle: 'โดย $createBy',
      icon: Icons.inventory_2_outlined,
      iconColor: cardType == OrderCardType.orderDiff ? const Color(0xFF2563EB) : const Color(0xFF9333EA),
      iconBg: cardType == OrderCardType.orderDiff ? const Color(0xFFDBEAFE) : const Color(0xFFF3E8FF),
    );

    notifyListeners();
  }

  int _findOrderIndex(String orderId) {
    return orders.indexWhere(
      (o) => o.supabaseId == orderId || o.id == orderId || o.allItems.any((item) => item.id == orderId),
    );
  }

  Future<void> updateOrderCard(OrderModel updatedOrder) async {
    if (dataMode == AppDataMode.real) {
      final supabaseId = updatedOrder.supabaseId ?? _findSupabaseOrderId(updatedOrder.id);
      if (supabaseId == null) {
        throw Exception('ไม่พบรหัสอ้างอิงออเดอร์ในฐานข้อมูล Supabase');
      }

      final updates = <String, dynamic>{
        'delivery_type': updatedOrder.deliveryType.name,
        'priority': updatedOrder.priority.name,
        'activity_status': updatedOrder.activityStatus.name,
        'description': updatedOrder.errorDetails,
        'assignee_id': updatedOrder.assignee?.authUserId,
        'bank_code': updatedOrder.bankCode,
        'bank_name': updatedOrder.bankName,
        'payment_method_code': updatedOrder.paymentMethodCode,
        'payment_method': updatedOrder.paymentMethod,
        'amount': updatedOrder.amount ?? 0,
        'status_order': updatedOrder.statusOrder?.code,
      };

      await orderRepository.updateOrder(
        supabaseId,
        updates,
        items: updatedOrder.items.isNotEmpty ? updatedOrder.items : null,
      );
      await loadOrdersFromSupabase();
      return;
    }

    final index = _findOrderIndex(updatedOrder.id);
    if (index != -1) {
      final parentId = orders[index].id;
      orders[index] = updatedOrder.copyWith(id: parentId);
      notifyListeners();
    }
  }

  Future<void> addOrderToCard(String cardId, String orderNo, DeliveryType deliveryType) async {
    final trimmedNo = orderNo.trim();
    if (trimmedNo.isEmpty) return;

    if (dataMode == AppDataMode.real) {
      final supabaseId = _findSupabaseOrderId(cardId);
      if (supabaseId != null) {
        await orderRepository.addOrderItem(supabaseId, trimmedNo, deliveryType);
        await loadOrdersFromSupabase();
      }
      return;
    }

    final index = _findOrderIndex(cardId);
    if (index != -1) {
      final order = orders[index];
      final currentItems = List<OrderItemModel>.from(order.allItems);
      if (!currentItems.any((item) => item.id.trim().toLowerCase() == trimmedNo.toLowerCase())) {
        currentItems.add(OrderItemModel(id: trimmedNo, deliveryType: deliveryType));
        orders[index] = order.copyWith(items: currentItems);

        final orderMod = order.cardType == OrderCardType.orderDiff ? NotificationModule.orderDiff : NotificationModule.bankIssue;
        _sendNotification(
          module: orderMod,
          referenceId: cardId,
          assignee: order.assignee,
          title: 'เพิ่ม Order No. ในการ์ด $cardId',
          subtitle: '${currentUser.name} เพิ่ม $trimmedNo (${deliveryType.label})',
          icon: Icons.playlist_add,
          iconColor: order.cardType == OrderCardType.orderDiff ? const Color(0xFF2563EB) : const Color(0xFF9333EA),
          iconBg: order.cardType == OrderCardType.orderDiff ? const Color(0xFFDBEAFE) : const Color(0xFFF3E8FF),
        );

        notifyListeners();
      }
    }
  }

  Future<void> deleteOrderCard(String orderId) async {
    if (dataMode == AppDataMode.real) {
      final supabaseId = _findSupabaseOrderId(orderId);
      if (supabaseId != null) {
        await orderRepository.softDeleteOrder(supabaseId);
        await loadOrdersFromSupabase();
      }
      return;
    }

    orders.removeWhere((o) => o.id == orderId || o.allItems.any((item) => item.id == orderId));
    notifyListeners();
  }

  Future<void> updateOrderActivityStatus(String orderId, OrderActivityStatus newStatus) async {
    final index = _findOrderIndex(orderId);
    if (index != -1) {
      final oldOrder = orders[index];
      if (!OrderRolePermissionHelper.canUpdateActivityStatus(currentUser, oldOrder)) {
        return;
      }

      if (dataMode == AppDataMode.real) {
        final supabaseId = oldOrder.supabaseId ?? _findSupabaseOrderId(orderId);
        if (supabaseId != null) {
          await orderRepository.updateOrder(supabaseId, {
            'activity_status': newStatus.name,
          });
          await loadOrdersFromSupabase();
        }
        return;
      }
      final timeStr = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());
      final newLog = ActivityLogModel(
        id: 'ord-act-${DateTime.now().millisecondsSinceEpoch}',
        caseId: orderId,
        title: 'เปลี่ยนสถานะกิจกรรม: ${oldOrder.activityStatus.label} → ${newStatus.label}',
        authorName: currentUser.name,
        dateText: timeStr,
        icon: Icons.sync,
        iconColor: Colors.teal,
        iconBgColor: const Color(0xFFCCFBF1),
      );

      final updatedLogs = List<ActivityLogModel>.from(oldOrder.activityLogs)..add(newLog);

      orders[index] = oldOrder.copyWith(
        activityStatus: newStatus,
        activityLogs: updatedLogs,
      );

      final orderMod = oldOrder.cardType == OrderCardType.orderDiff ? NotificationModule.orderDiff : NotificationModule.bankIssue;
      _sendNotification(
        module: orderMod,
        referenceId: orderId,
        assignee: oldOrder.assignee,
        title: 'อัปเดตสถานะออเดอร์ $orderId',
        subtitle: '${currentUser.name}: ${oldOrder.activityStatus.label} → ${newStatus.label}',
        icon: Icons.sync,
        iconColor: const Color(0xFF0D9488),
        iconBg: const Color(0xFFCCFBF1),
      );

      notifyListeners();
    }
  }

  Future<void> addOrderComment(
    String orderId,
    String content, {
    List<PendingFileAttachment>? pendingFiles,
  }) async {
    final index = _findOrderIndex(orderId);
    if (index == -1) return;

    final oldOrder = orders[index];

    if (dataMode == AppDataMode.real) {
      final supabaseId = oldOrder.supabaseId ?? _findSupabaseOrderId(orderId);
      if (supabaseId == null) {
        throw Exception('ไม่พบรหัสอ้างอิงออเดอร์ในฐานข้อมูล Supabase');
      }

      final List<String> uploadedPaths = [];
      if (pendingFiles != null && pendingFiles.isNotEmpty) {
        for (final pf in pendingFiles) {
          final bytes = await pf.getBytes();
          if (bytes != null) {
            final att = await orderRepository.uploadOrderAttachment(
              supabaseOrderId: supabaseId,
              fileBytes: bytes,
              fileName: pf.name,
              fileType: pf.extension,
              fileSizeBytes: pf.sizeBytes,
              mimeType: pf.mimeType,
            );
            if (att.storagePath != null && att.storagePath!.isNotEmpty) {
              uploadedPaths.add(att.storagePath!);
            }
          }
        }
      }

      String finalContent = content.trim();
      if (finalContent.isEmpty && uploadedPaths.isNotEmpty) {
        finalContent = '[ไฟล์แนบ ${uploadedPaths.length} รายการ]';
      }
      if (uploadedPaths.isNotEmpty) {
        final tags = uploadedPaths.map((p) => '[attachment:$p]').join('\n');
        finalContent = '$finalContent\n$tags';
      }
      if (finalContent.trim().isEmpty) return;

      await orderRepository.addComment(supabaseId, finalContent);
      await loadOrdersFromSupabase();
      return;
    }

    final List<FileAttachmentModel> uploadedAttachments = [];

    if (pendingFiles != null && pendingFiles.isNotEmpty) {
      final tempCommentId = 'ord-c-${DateTime.now().millisecondsSinceEpoch}';
      for (var pf in pendingFiles) {
        final fileBytes = await pf.getBytes();
        if (fileBytes != null) {
          try {
            final fileModel = await StorageService.uploadFile(
              itemId: orderId,
              isCase: false,
              commentId: tempCommentId,
              bytes: fileBytes,
              fileName: pf.name,
              sizeBytes: pf.sizeBytes,
            );
            uploadedAttachments.add(fileModel);
          } catch (e) {
            debugPrint('[AppState.addOrderComment] Storage upload error: $e');
            uploadedAttachments.add(FileAttachmentModel(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              fileName: pf.name,
              fileSize: pf.formattedSize,
              fileSizeBytes: pf.sizeBytes,
              fileType: pf.extension,
              bytes: fileBytes,
            ));
          }
        } else {
          uploadedAttachments.add(FileAttachmentModel(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            fileName: pf.name,
            fileSize: pf.formattedSize,
            fileSizeBytes: pf.sizeBytes,
            fileType: pf.extension,
          ));
        }
      }
    }

    final timeStr = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());
    final displayContent = content.trim().isEmpty && uploadedAttachments.isNotEmpty
        ? '[ไฟล์แนบ ${uploadedAttachments.length} รายการ]'
        : content.trim();

    final newComment = CommentModel(
      id: 'ord-c-${DateTime.now().millisecondsSinceEpoch}',
      caseId: orderId,
      author: currentUser,
      content: displayContent,
      dateText: timeStr,
      attachedFiles: uploadedAttachments,
      attachedImageUrl: uploadedAttachments.any((f) => f.isImage)
          ? uploadedAttachments.firstWhere((f) => f.isImage).url
          : null,
    );

    final newLog = ActivityLogModel(
      id: 'ord-act-${DateTime.now().millisecondsSinceEpoch}',
      caseId: orderId,
      title: 'เพิ่มความคิดเห็น${uploadedAttachments.isNotEmpty ? " พร้อมไฟล์แนบ (${uploadedAttachments.length})" : ""}',
      authorName: currentUser.name,
      dateText: timeStr,
      icon: Icons.chat_bubble,
      iconColor: Colors.blue,
      iconBgColor: const Color(0xFFDBEAFE),
    );

    final updatedComments = List<CommentModel>.from(oldOrder.comments)..add(newComment);
    final updatedLogs = List<ActivityLogModel>.from(oldOrder.activityLogs)..add(newLog);

    orders[index] = oldOrder.copyWith(
      comments: updatedComments,
      activityLogs: updatedLogs,
    );

    final orderMod = oldOrder.cardType == OrderCardType.orderDiff ? NotificationModule.orderDiff : NotificationModule.bankIssue;
    _sendNotification(
      module: orderMod,
      referenceId: orderId,
      assignee: oldOrder.assignee,
      title: 'มี Comment ใหม่ในออเดอร์ $orderId',
      subtitle: '${currentUser.name}: ${displayContent.isEmpty ? "แนบไฟล์" : displayContent}',
      icon: Icons.chat_bubble_outline,
      iconColor: const Color(0xFF2563EB),
      iconBg: const Color(0xFFDBEAFE),
    );

    notifyListeners();
  }

  Future<void> editOrderComment(String orderId, String commentId, String newContent) async {
    if (dataMode == AppDataMode.real) {
      await orderRepository.editComment(commentId, newContent.trim());
      await loadOrdersFromSupabase();
      return;
    }

    final index = _findOrderIndex(orderId);
    if (index == -1) return;
    
    final oldOrder = orders[index];
    final commentIndex = oldOrder.comments.indexWhere((c) => c.id == commentId);
    if (commentIndex == -1) return;

    final comment = oldOrder.comments[commentIndex];
    if (!OrderRolePermissionHelper.canEditComment(currentUser, comment)) return;

    final updatedComments = List<CommentModel>.from(oldOrder.comments);
    updatedComments[commentIndex] = comment.copyWith(content: newContent);

    orders[index] = oldOrder.copyWith(comments: updatedComments);
    notifyListeners();
  }

  Future<void> deleteOrderComment(String orderId, String commentId) async {
    if (dataMode == AppDataMode.real) {
      await orderRepository.deleteComment(commentId);
      await loadOrdersFromSupabase();
      return;
    }

    final index = _findOrderIndex(orderId);
    if (index == -1) return;
    
    final oldOrder = orders[index];
    final commentIndex = oldOrder.comments.indexWhere((c) => c.id == commentId);
    if (commentIndex == -1) return;

    final comment = oldOrder.comments[commentIndex];
    if (!OrderRolePermissionHelper.canDeleteComment(currentUser, comment)) return;

    final updatedComments = List<CommentModel>.from(oldOrder.comments)..removeAt(commentIndex);

    orders[index] = oldOrder.copyWith(comments: updatedComments);
    notifyListeners();
  }

  // Unread count specifically for currentUser
  int get unreadNotificationCount {
    return currentUserNotifications.where((n) => !n.isRead).length;
  }

  // Actions
  void setFilters({
    String? query,
    CaseStatus? status,
    CasePriority? priority,
    TeamType? team,
    String? assignee,
    DateTimeRange? dateRange,
  }) {
    if (query != null) searchQuery = query;
    filterStatus = status;
    filterPriority = priority;
    filterTeam = team;
    filterAssignee = assignee;
    filterDateRange = dateRange;
    notifyListeners();
  }

  void clearFilters() {
    searchQuery = '';
    filterStatus = null;
    filterPriority = null;
    filterTeam = null;
    filterAssignee = null;
    filterDateRange = null;
    notifyListeners();
  }

  Future<void> createCase({
    required String title,
    required TeamType team,
    required String category,
    UserModel? assignee,
    required CasePriority priority,
    required String systemAffected,
    required String environment,
    required String url,
    required String browser,
    String? description,
    List<String>? images,
    List<CaseFileAttachment>? files,
    List<PendingFileAttachment>? pendingFiles,
  }) async {
    if (currentUser.roleEnum == UserRole.user) {
      if (assignee != null) {
        throw Exception('Role User ไม่อนุญาตให้กำหนด Assignee ตอนสร้างเคส');
      }
    }

    if (dataMode == AppDataMode.real) {
      debugPrint('[AppState.createCase] Real mode start for title: $title, team: ${team.name}');
      try {
        final teamCode = team.name.toLowerCase();
        debugPrint('[AppState.createCase] Searching team UUID for code: $teamCode');
        final teamUuid = await _getTeamUuid(team);
        if (teamUuid == null) {
          throw Exception('ไม่พบข้อมูลทีม (${team.label}) ในระบบฐานข้อมูล (Code: $teamCode)');
        }
        debugPrint('[AppState.createCase] Team UUID found: $teamUuid. Starting Supabase insert...');

        final createdCase = await caseRepository.createCase(
          title: title,
          details: description,
          priority: priority,
          status: CaseStatus.open,
          teamId: teamUuid,
          category: category,
          assigneeId: assignee?.authUserId,
          systemAffected: systemAffected,
          environment: environment,
          url: url,
          browser: browser,
        );

        if (pendingFiles != null && pendingFiles.isNotEmpty && createdCase.supabaseId != null) {
          final List<String> uploadErrors = [];
          for (var pf in pendingFiles) {
            final fileBytes = await pf.getBytes();
            if (fileBytes != null) {
              try {
                await caseRepository.uploadAttachment(
                  supabaseCaseId: createdCase.supabaseId!,
                  fileBytes: fileBytes,
                  fileName: pf.name,
                  fileSize: pf.formattedSize,
                  fileType: pf.extension,
                );
              } catch (e) {
                debugPrint('[AppState.createCase] Attachment upload warning: $e');
                uploadErrors.add('${pf.name}: ${e.toString().replaceAll('Exception: ', '')}');
              }
            } else {
              uploadErrors.add('${pf.name}: ไม่สามารถอ่านข้อมูลไฟล์ไบต์ได้');
            }
          }

          if (uploadErrors.isNotEmpty) {
            throw Exception('สร้างเคสสำเร็จ แต่อัปโหลดไฟล์แนบไม่ผ่าน:\n${uploadErrors.join('\n')}');
          }
        }

        debugPrint('[AppState.createCase] Insert successful. Refreshing cases...');

        await loadCasesFromSupabase();
        debugPrint('[AppState.createCase] Refresh cases successful.');
      } catch (e, stack) {
        debugPrint('[AppState.createCase] ERROR: $e\n$stack');
        rethrow;
      }
      return;
    }

    final nextNum = cases.length + 1;
    final id = 'DEV-${nextNum.toString().padLeft(3, '0')}';

    final List<CaseFileAttachment> finalFiles = List.from(files ?? []);
    final List<String> finalImages = List.from(images ?? []);
    if (pendingFiles != null && pendingFiles.isNotEmpty) {
      for (var pf in pendingFiles) {
        if (pf.isImage) {
          finalImages.add('https://picsum.photos/400/300');
        }
        finalFiles.add(CaseFileAttachment(
          fileName: pf.name,
          fileSize: pf.formattedSize,
          fileType: pf.extension,
          fileSizeBytes: pf.sizeBytes,
        ));
      }
    }

    final newCase = CaseModel(
      id: id,
      title: title,
      priority: priority,
      status: CaseStatus.open,
      team: team,
      category: category,
      assignee: assignee,
      dateText: 'วันนี้',
      systemAffected: systemAffected,
      environment: environment,
      url: url,
      browser: browser,
      createdById: currentUser.id,
      attachedImages: finalImages,
      attachedFiles: finalFiles,
      comments: [],
      activityLogs: [
        ActivityLogModel(
          id: 'act-${DateTime.now().millisecondsSinceEpoch}',
          caseId: id,
          title: 'สร้างเคส',
          authorName: currentUser.name,
          dateText: 'วันนี้',
          icon: Icons.add_circle,
          iconColor: Colors.blue,
          iconBgColor: const Color(0xFFDBEAFE),
        ),
      ],
    );

    cases.insert(0, newCase);

    notifications.insert(
      0,
      AppNotificationModel(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}-${currentUser.id}',
        title: 'สร้างเคสใหม่สำเร็จ ($id)',
        subtitle: '$title',
        timeAgo: 'เมื่อสักครู่',
        icon: Icons.check_circle_outline,
        iconColor: const Color(0xFF16A34A),
        iconBg: const Color(0xFFDCFCE7),
        isRead: false,
        module: NotificationModule.caseModule,
        referenceId: id,
        caseId: id,
        targetUserId: currentUser.id,
        targetUserName: currentUser.name,
        actorUserId: currentUser.id,
      ),
    );

    _sendNotification(
      module: NotificationModule.caseModule,
      referenceId: id,
      assignee: assignee,
      title: assignee != null ? 'คุณถูก Assign เคสใหม่ $id' : 'เคสใหม่ในทีม ${team.label} ($id)',
      subtitle: '$title โดย ${currentUser.name}',
      icon: Icons.add_circle_outline,
      iconColor: const Color(0xFF2563EB),
      iconBg: const Color(0xFFDBEAFE),
    );

    notifyListeners();
  }

  void updateCaseDetails({
    required String caseId,
    required String title,
    required TeamType team,
    required String category,
    UserModel? assignee,
    required CasePriority priority,
    required String systemAffected,
    required String environment,
    required String url,
    required String browser,
  }) async {
    if (dataMode == AppDataMode.real) {
      try {
        final supabaseId = _findSupabaseCaseId(caseId);
        final teamUuid = await _getTeamUuid(team);
        if (supabaseId != null && teamUuid != null) {
          await caseRepository.updateCase(supabaseId, {
            'title': title,
            'team_id': teamUuid,
            'category': category,
            'assignee_id': assignee?.authUserId,
            'priority': priority.name,
            'system_affected': systemAffected,
            'environment': environment,
            'url': url,
            'browser': browser,
          });
          await loadCasesFromSupabase();
        }
      } catch (_) {}
      return;
    }

    final index = cases.indexWhere((c) => c.id == caseId);
    if (index != -1) {
      final oldCase = cases[index];
      final updatedLogs = List<ActivityLogModel>.from(oldCase.activityLogs)
        ..add(ActivityLogModel(
          id: 'act-${DateTime.now().millisecondsSinceEpoch}',
          caseId: caseId,
          title: 'แก้ไขรายละเอียดเคส',
          authorName: currentUser.name,
          dateText: 'วันนี้',
          icon: Icons.edit,
          iconColor: Colors.blue,
          iconBgColor: const Color(0xFFDBEAFE),
        ));

      cases[index] = oldCase.copyWith(
        title: title,
        team: team,
        category: category,
        assignee: assignee,
        clearAssignee: assignee == null,
        priority: priority,
        systemAffected: systemAffected,
        environment: environment,
        url: url,
        browser: browser,
        activityLogs: updatedLogs,
      );

      notifyListeners();
    }
  }

  void updateCaseStatus(String caseId, CaseStatus newStatus) async {
    if (dataMode == AppDataMode.real) {
      try {
        final supabaseId = _findSupabaseCaseId(caseId);
        if (supabaseId != null) {
          await caseRepository.updateCase(supabaseId, {
            'status': newStatus.name,
          });
          await loadCasesFromSupabase();
        }
      } catch (_) {}
      return;
    }

    final index = cases.indexWhere((c) => c.id == caseId);
    if (index != -1) {
      final oldCase = cases[index];
      final oldStatusLabel = oldCase.status.label;

      final updatedLogs = List<ActivityLogModel>.from(oldCase.activityLogs);
      updatedLogs.add(
        ActivityLogModel(
          id: 'act-${DateTime.now().millisecondsSinceEpoch}',
          caseId: caseId,
          title: 'เปลี่ยนสถานะ: $oldStatusLabel → ${newStatus.label}',
          authorName: currentUser.name,
          dateText: 'วันนี้',
          icon: Icons.sync,
          iconColor: Colors.teal,
          iconBgColor: const Color(0xFFCCFBF1),
        ),
      );

      cases[index] = oldCase.copyWith(
        status: newStatus,
        activityLogs: updatedLogs,
      );

      _sendNotification(
        module: NotificationModule.caseModule,
        referenceId: caseId,
        assignee: oldCase.assignee,
        title: 'เปลี่ยนสถานะเคส $caseId',
        subtitle: '${currentUser.name}: $oldStatusLabel → ${newStatus.label}',
        icon: Icons.swap_horiz,
        iconColor: const Color(0xFFD97706),
        iconBg: const Color(0xFFFEF3C7),
      );

      notifyListeners();
    }
  }

  Future<void> addComment(
    String caseId,
    String content, {
    String? imagePath,
    List<PendingFileAttachment>? pendingFiles,
  }) async {
    final List<FileAttachmentModel> uploadedAttachments = [];
    final supabaseId = await _getOrFetchSupabaseCaseId(caseId);

    if (supabaseId == null || supabaseId.isEmpty) {
      throw Exception('ไม่พบรหัสอ้างอิงเคส ($caseId) ในระบบฐานข้อมูล Supabase');
    }

    if (pendingFiles != null && pendingFiles.isNotEmpty) {
      for (var pf in pendingFiles) {
        final fileBytes = await pf.getBytes();
        if (fileBytes != null) {
          try {
            final fileModel = await StorageService.uploadFile(
              itemId: supabaseId,
              isCase: true,
              commentId: 'attachment',
              bytes: fileBytes,
              fileName: pf.name,
              sizeBytes: pf.sizeBytes,
            );
            uploadedAttachments.add(fileModel);
          } catch (e) {
            debugPrint('[AppState.addComment] Upload error: $e');
            uploadedAttachments.add(FileAttachmentModel(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              fileName: pf.name,
              fileSize: pf.formattedSize,
              fileSizeBytes: pf.sizeBytes,
              fileType: pf.extension,
              bytes: fileBytes,
            ));
          }
        } else {
          uploadedAttachments.add(FileAttachmentModel(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            fileName: pf.name,
            fileSize: pf.formattedSize,
            fileSizeBytes: pf.sizeBytes,
            fileType: pf.extension,
          ));
        }
      }
    }

    final displayContent = content.trim().isEmpty && uploadedAttachments.isNotEmpty
        ? '[ไฟล์แนบ ${uploadedAttachments.length} รายการ]'
        : content.trim();

    if (dataMode == AppDataMode.real) {
      try {
        String finalContent = displayContent;
        if (uploadedAttachments.isNotEmpty) {
          final attTags = uploadedAttachments
              .where((a) => a.storagePath != null && a.storagePath!.isNotEmpty)
              .map((a) => '[attachment:${a.storagePath}]')
              .join('\n');
          if (attTags.isNotEmpty) {
            finalContent = '$finalContent\n$attTags';
          }
        }

        final firstAttachmentPath = uploadedAttachments.isNotEmpty
            ? uploadedAttachments.first.storagePath
            : imagePath;

        final newComment = await caseRepository.addComment(supabaseId, finalContent, attachedImagePath: firstAttachmentPath);

        // Update local state in memory
        final index = cases.indexWhere((c) => c.supabaseId == supabaseId || c.id == caseId);
        if (index != -1) {
          final oldCase = cases[index];
          final updatedComments = List<CommentModel>.from(oldCase.comments);
          final existingIdx = updatedComments.indexWhere((c) => c.id == newComment.id);
          if (existingIdx != -1) {
            updatedComments[existingIdx] = newComment;
          } else {
            updatedComments.add(newComment);
          }
          cases[index] = oldCase.copyWith(comments: updatedComments);
          notifyListeners();
        }

        await loadCasesFromSupabase();
      } catch (e) {
        debugPrint('[AppState.addComment] Supabase error: $e');
        rethrow;
      }
      return;
    }

    final index = cases.indexWhere((c) => c.id == caseId);
    if (index != -1) {
      final oldCase = cases[index];

      final newComment = CommentModel(
        id: 'c-${DateTime.now().millisecondsSinceEpoch}',
        caseId: caseId,
        author: currentUser,
        content: displayContent,
        dateText: 'วันนี้',
        attachedImageUrl: imagePath ?? (uploadedAttachments.any((f) => f.isImage) ? uploadedAttachments.firstWhere((f) => f.isImage).url : null),
        attachedFiles: uploadedAttachments,
      );

      final updatedComments = List<CommentModel>.from(oldCase.comments)..add(newComment);
      final updatedLogs = List<ActivityLogModel>.from(oldCase.activityLogs)..add(
        ActivityLogModel(
          id: 'act-${DateTime.now().millisecondsSinceEpoch}',
          caseId: caseId,
          title: 'เพิ่มความคิดเห็น${uploadedAttachments.isNotEmpty ? " พร้อมไฟล์แนบ (${uploadedAttachments.length})" : ""}',
          authorName: currentUser.name,
          dateText: 'วันนี้',
          icon: Icons.chat_bubble,
          iconColor: Colors.blue,
          iconBgColor: const Color(0xFFDBEAFE),
        ),
      );

      cases[index] = oldCase.copyWith(
        comments: updatedComments,
        activityLogs: updatedLogs,
      );

      _sendNotification(
        module: NotificationModule.caseModule,
        referenceId: caseId,
        assignee: oldCase.assignee,
        title: 'มี Comment ใหม่ในเคส $caseId',
        subtitle: '${currentUser.name}: $content',
        icon: Icons.chat_bubble_outline,
        iconColor: const Color(0xFFDC2626),
        iconBg: const Color(0xFFFEE2E2),
      );

      notifyListeners();
    }
  }

  void toggleLikeComment(String caseId, String commentId) async {
    if (dataMode == AppDataMode.real) {
      try {
        await caseRepository.toggleLikeComment(commentId);
        await loadCasesFromSupabase();
      } catch (_) {}
      return;
    }

    final caseIndex = cases.indexWhere((c) => c.id == caseId);
    if (caseIndex != -1) {
      final caseObj = cases[caseIndex];
      final commentIndex = caseObj.comments.indexWhere((cm) => cm.id == commentId);
      if (commentIndex != -1) {
        final comment = caseObj.comments[commentIndex];
        final isLiked = !comment.isLiked;
        final likes = isLiked ? comment.likes + 1 : comment.likes - 1;

        final updatedComments = List<CommentModel>.from(caseObj.comments);
        updatedComments[commentIndex] = comment.copyWith(
          likes: likes,
          isLiked: isLiked,
        );

        cases[caseIndex] = caseObj.copyWith(comments: updatedComments);

        if (isLiked && comment.author.id != currentUser.id) {
          _sendNotification(
            module: NotificationModule.caseModule,
            referenceId: caseId,
            assignee: comment.author,
            title: 'มีผู้ถูกใจความคิดเห็นของคุณในเคส $caseId',
            subtitle: '${currentUser.name} ถูกใจความคิดเห็น: "${comment.content}"',
            icon: Icons.thumb_up,
            iconColor: AppColors.primary,
            iconBg: const Color(0xFFDBEAFE),
          );
        }

        notifyListeners();
      }
    }
  }

  Future<void> editCaseComment(String caseId, String commentId, String newContent) async {
    if (currentUser == null) return;
    
    if (dataMode == AppDataMode.real) {
      try {
        await caseRepository.editComment(commentId, newContent);
        await loadCasesFromSupabase();
      } catch (e) {
        debugPrint('[AppState.editCaseComment] Supabase error: $e');
        rethrow;
      }
      return;
    }

    final index = cases.indexWhere((c) => c.id == caseId);
    if (index == -1) return;

    final oldCase = cases[index];
    final commentIndex = oldCase.comments.indexWhere((c) => c.id == commentId);
    if (commentIndex == -1) return;

    final comment = oldCase.comments[commentIndex];
    if (!RolePermissionHelper.canEditComment(currentUser!, comment)) return;

    final updatedComments = List<CommentModel>.from(oldCase.comments);
    updatedComments[commentIndex] = comment.copyWith(content: newContent);

    cases[index] = oldCase.copyWith(comments: updatedComments);
    notifyListeners();
  }

  Future<void> deleteCaseComment(String caseId, String commentId) async {
    if (currentUser == null) return;

    if (dataMode == AppDataMode.real) {
      try {
        await caseRepository.deleteComment(commentId);
        await loadCasesFromSupabase();
      } catch (e) {
        debugPrint('[AppState.deleteCaseComment] Supabase error: $e');
        rethrow;
      }
      return;
    }

    final index = cases.indexWhere((c) => c.id == caseId);
    if (index == -1) return;

    final oldCase = cases[index];
    final commentIndex = oldCase.comments.indexWhere((c) => c.id == commentId);
    if (commentIndex == -1) return;

    final comment = oldCase.comments[commentIndex];
    if (!RolePermissionHelper.canDeleteComment(currentUser!, comment)) return;

    final updatedComments = List<CommentModel>.from(oldCase.comments)..removeAt(commentIndex);

    cases[index] = oldCase.copyWith(comments: updatedComments);
    notifyListeners();
  }

  void deleteCase(String caseId) async {
    if (dataMode == AppDataMode.real) {
      try {
        final supabaseId = _findSupabaseCaseId(caseId);
        if (supabaseId != null) {
          await caseRepository.deleteCase(supabaseId);
          await loadCasesFromSupabase();
        }
      } catch (_) {}
      return;
    }

    cases.removeWhere((c) => c.id == caseId);
    notifyListeners();
  }

  Future<void> reassignOrderCard(String orderId, UserModel? newAssignee) async {
    if (dataMode == AppDataMode.real) {
      final supabaseId = _findSupabaseOrderId(orderId);
      if (supabaseId != null) {
        await orderRepository.updateOrder(supabaseId, {
          'assignee_id': newAssignee?.authUserId,
        });
        await loadOrdersFromSupabase();
      }
      return;
    }

    final index = _findOrderIndex(orderId);
    if (index != -1) {
      final oldOrder = orders[index];
      final assigneeLabel = newAssignee != null ? newAssignee.name : 'ยังไม่ระบุผู้รับผิดชอบ';
      final timeStr = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());
      final newLog = ActivityLogModel(
        id: 'ord-act-${DateTime.now().millisecondsSinceEpoch}',
        caseId: orderId,
        title: 'เปลี่ยนผู้รับผิดชอบเป็น $assigneeLabel',
        authorName: currentUser.name,
        dateText: timeStr,
        icon: Icons.person_add,
        iconColor: Colors.indigo,
        iconBgColor: const Color(0xFFE0E7FF),
      );

      final updatedLogs = List<ActivityLogModel>.from(oldOrder.activityLogs)..add(newLog);

      orders[index] = oldOrder.copyWith(
        assignee: newAssignee,
        clearAssignee: newAssignee == null,
        activityLogs: updatedLogs,
      );

      final orderMod = oldOrder.cardType == OrderCardType.orderDiff ? NotificationModule.orderDiff : NotificationModule.bankIssue;
      _sendNotification(
        module: orderMod,
        referenceId: orderId,
        assignee: newAssignee,
        oldAssignee: oldOrder.assignee,
        title: 'เปลี่ยนผู้รับผิดชอบออเดอร์ $orderId',
        subtitle: 'เปลี่ยนเป็น $assigneeLabel โดย ${currentUser.name}',
        icon: Icons.person_add_outlined,
        iconColor: const Color(0xFF4338CA),
        iconBg: const Color(0xFFE0E7FF),
      );

      notifyListeners();
    }
  }

  Future<void> uploadOrderAttachment({
    required String orderId,
    required Uint8List fileBytes,
    required String fileName,
    required String fileSize,
    required String fileType,
    int? fileSizeBytes,
    String? mimeType,
  }) async {
    if (dataMode == AppDataMode.real) {
      final supabaseId = _findSupabaseOrderId(orderId);
      if (supabaseId == null) {
        throw Exception('ไม่พบรหัสอ้างอิงออเดอร์ในฐานข้อมูล Supabase');
      }
      await orderRepository.uploadOrderAttachment(
        supabaseOrderId: supabaseId,
        fileBytes: fileBytes,
        fileName: fileName,
        fileType: fileType,
        fileSizeBytes: fileSizeBytes ?? fileBytes.length,
        mimeType: mimeType,
      );
      await loadOrdersFromSupabase();
      return;
    }

    addOrderAttachment(orderId, fileName, fileSize, fileType);
  }

  void addOrderAttachment(
    String orderId,
    String fileName,
    String size,
    String fileType, {
    String? storagePath,
    String? url,
  }) {
    final index = _findOrderIndex(orderId);
    if (index != -1) {
      final oldOrder = orders[index];
      final timeStr = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());
      final newAttachment = AttachmentModel(
        id: 'att-${DateTime.now().millisecondsSinceEpoch}',
        name: fileName,
        size: size,
        dateText: timeStr,
        fileType: fileType,
        storagePath: storagePath,
        url: url,
      );
      final newLog = ActivityLogModel(
        id: 'ord-act-${DateTime.now().millisecondsSinceEpoch}',
        caseId: orderId,
        title: 'แนบไฟล์: $fileName',
        authorName: currentUser.name,
        dateText: timeStr,
        icon: Icons.attach_file,
        iconColor: Colors.blue,
        iconBgColor: const Color(0xFFDBEAFE),
      );

      final updatedAttachments = List<AttachmentModel>.from(oldOrder.attachments)..add(newAttachment);
      final updatedLogs = List<ActivityLogModel>.from(oldOrder.activityLogs)..add(newLog);

      orders[index] = oldOrder.copyWith(
        attachments: updatedAttachments,
        activityLogs: updatedLogs,
      );

      if (oldOrder.assignee != null && oldOrder.assignee!.id != currentUser.id) {
        notifications.insert(
          0,
          AppNotificationModel(
            id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
            title: 'มีการแนบไฟล์ใหม่ในออเดอร์ $orderId',
            subtitle: '${currentUser.name}: $fileName',
            timeAgo: 'เมื่อสักครู่',
            icon: Icons.attach_file,
            iconColor: const Color(0xFF2563EB),
            iconBg: const Color(0xFFDBEAFE),
            isRead: false,
            caseId: orderId,
            targetUserId: oldOrder.assignee!.id,
            targetUserName: oldOrder.assignee!.name,
          ),
        );
      }

      notifyListeners();
    }
  }

  Future<void> deleteOrderAttachment(String orderId, String attachmentId) async {
    final index = _findOrderIndex(orderId);
    if (index == -1) return;

    final oldOrder = orders[index];
    final attToRemove = oldOrder.attachments.firstWhere(
      (a) => a.id == attachmentId,
      orElse: () => const AttachmentModel(id: '', name: 'ไฟล์', size: '', dateText: '', fileType: ''),
    );

    if (dataMode == AppDataMode.real) {
      await orderRepository.deleteOrderAttachment(
        attachmentId,
        storagePath: attToRemove.storagePath,
      );
      await loadOrdersFromSupabase();
      return;
    }

    final timeStr = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());

    final newLog = ActivityLogModel(
      id: 'ord-act-${DateTime.now().millisecondsSinceEpoch}',
      caseId: orderId,
      title: 'ลบไฟล์แนบ: ${attToRemove.name}',
      authorName: currentUser.name,
      dateText: timeStr,
      icon: Icons.delete_outline,
      iconColor: Colors.red,
      iconBgColor: const Color(0xFFFEE2E2),
    );

    final updatedAttachments = oldOrder.attachments.where((a) => a.id != attachmentId).toList();
    final updatedLogs = List<ActivityLogModel>.from(oldOrder.activityLogs)..add(newLog);

    orders[index] = oldOrder.copyWith(
      attachments: updatedAttachments,
      activityLogs: updatedLogs,
    );
    notifyListeners();
  }

  void reassignCase(String caseId, UserModel? newAssignee) async {
    if (dataMode == AppDataMode.real) {
      try {
        final supabaseId = _findSupabaseCaseId(caseId);
        if (supabaseId != null) {
          await caseRepository.updateCase(supabaseId, {
            'assignee_id': newAssignee?.authUserId,
          });
          await loadCasesFromSupabase();
        }
      } catch (_) {}
      return;
    }

    final index = cases.indexWhere((c) => c.id == caseId);
    if (index != -1) {
      final oldCase = cases[index];
      final assigneeLabel = newAssignee != null ? newAssignee.name : 'ไม่ระบุผู้รับผิดชอบ';
      final updatedLogs = List<ActivityLogModel>.from(oldCase.activityLogs)
        ..add(ActivityLogModel(
          id: 'act-${DateTime.now().millisecondsSinceEpoch}',
          caseId: caseId,
          title: 'เปลี่ยนผู้รับผิดชอบเป็น $assigneeLabel',
          authorName: currentUser.name,
          dateText: 'วันนี้',
          icon: Icons.person_add,
          iconColor: Colors.indigo,
          iconBgColor: const Color(0xFFE0E7FF),
        ));

      cases[index] = oldCase.copyWith(
        assignee: newAssignee,
        clearAssignee: newAssignee == null,
        activityLogs: updatedLogs,
      );

      _sendNotification(
        module: NotificationModule.caseModule,
        referenceId: caseId,
        assignee: newAssignee,
        oldAssignee: oldCase.assignee,
        title: 'เปลี่ยนผู้รับผิดชอบเคส $caseId',
        subtitle: 'เปลี่ยนเป็น $assigneeLabel โดย ${currentUser.name}',
        icon: Icons.person_add_outlined,
        iconColor: const Color(0xFF2563EB),
        iconBg: const Color(0xFFDBEAFE),
      );

      notifyListeners();
    }
  }

  void changeCaseTeam(String caseId, TeamType newTeam) async {
    if (dataMode == AppDataMode.real) {
      try {
        final supabaseId = _findSupabaseCaseId(caseId);
        final teamUuid = await _getTeamUuid(newTeam);
        if (supabaseId != null && teamUuid != null) {
          await caseRepository.updateCase(supabaseId, {
            'team_id': teamUuid,
          });
          await loadCasesFromSupabase();
        }
      } catch (_) {}
      return;
    }

    final index = cases.indexWhere((c) => c.id == caseId);
    if (index != -1) {
      final oldCase = cases[index];
      final updatedLogs = List<ActivityLogModel>.from(oldCase.activityLogs)
        ..add(ActivityLogModel(
          id: 'act-${DateTime.now().millisecondsSinceEpoch}',
          caseId: caseId,
          title: 'เปลี่ยนทีมเป็น ${newTeam.label}',
          authorName: currentUser.name,
          dateText: 'วันนี้',
          icon: Icons.groups,
          iconColor: Colors.purple,
          iconBgColor: const Color(0xFFF3E8FF),
        ));

      cases[index] = oldCase.copyWith(
        team: newTeam,
        activityLogs: updatedLogs,
      );
      notifyListeners();
    }
  }

  void changeCasePriority(String caseId, CasePriority newPriority) async {
    if (dataMode == AppDataMode.real) {
      try {
        final supabaseId = _findSupabaseCaseId(caseId);
        if (supabaseId != null) {
          await caseRepository.updateCase(supabaseId, {
            'priority': newPriority.name,
          });
          await loadCasesFromSupabase();
        }
      } catch (_) {}
      return;
    }

    final index = cases.indexWhere((c) => c.id == caseId);
    if (index != -1) {
      final oldCase = cases[index];
      final updatedLogs = List<ActivityLogModel>.from(oldCase.activityLogs)
        ..add(ActivityLogModel(
          id: 'act-${DateTime.now().millisecondsSinceEpoch}',
          caseId: caseId,
          title: 'เปลี่ยน Priority เป็น ${newPriority.label}',
          authorName: currentUser.name,
          dateText: 'วันนี้',
          icon: Icons.flag,
          iconColor: Colors.orange,
          iconBgColor: const Color(0xFFFFEDD5),
        ));

      cases[index] = oldCase.copyWith(
        priority: newPriority,
        activityLogs: updatedLogs,
      );
      notifyListeners();
    }
  }

  Future<void> markNotificationRead(String notifId) async {
    final index = notifications.indexWhere((n) => n.id == notifId);
    if (index != -1 && !notifications[index].isRead) {
      notifications[index] = notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
    if (dataMode == AppDataMode.real) {
      await notificationRepository.markAsRead(notifId);
    }
  }

  Future<void> markAllNotificationsRead() async {
    final myNotifIds = currentUserNotifications.map((n) => n.id).toSet();
    notifications = notifications.map((n) {
      if (myNotifIds.contains(n.id)) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
    notifyListeners();
    if (dataMode == AppDataMode.real) {
      await notificationRepository.markAllAsRead();
    }
  }

  Future<void> updateUserProfile({
    required String name,
    required String phoneNumber,
  }) async {
    final trimmedName = name.trim();
    final trimmedPhone = phoneNumber.trim();

    if (dataMode == AppDataMode.real) {
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser == null) {
        throw Exception('ไม่พบ session ผู้ใช้ กรุณาเข้าสู่ระบบใหม่');
      }
      await Supabase.instance.client.from('profiles').update({
        'full_name': trimmedName,
        'phone_number': trimmedPhone,
      }).eq('id', authUser.id);
    }

    final avatarLetter = trimmedName.isNotEmpty ? trimmedName.substring(0, 1).toUpperCase() : 'U';
    currentUser = currentUser.copyWith(
      name: trimmedName,
      phoneNumber: trimmedPhone,
      avatarUrl: avatarLetter,
    );

    final idx = registeredUsers.indexWhere((u) => u == currentUser);
    if (idx != -1) {
      registeredUsers[idx] = currentUser;
    }

    notifyListeners();
  }

  Future<void> logout() async {
    final token = NotificationService.cachedToken;
    if (dataMode == AppDataMode.real && token != null && token.isNotEmpty) {
      await notificationRepository.removeDeviceToken(token);
    }
    NotificationService.onTokenRefreshed = null;
    await _stopNotificationsRealtime();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('[AppState.logout] signOut warning: $e');
    }
    dataMode = AppDataMode.initializing;
    isLoggedIn = false;
    selectedNavIndex = 0; // Reset tab to Dashboard
    currentUser = const UserModel(
      id: '',
      name: '',
      role: 'user',
      email: '',
      avatarUrl: 'U',
    );
    cases = [];
    orders = [];
    notifications = [];
    registeredUsers = [];
    notifyListeners();
  }
}
