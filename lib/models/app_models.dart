import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'role_permission.dart';

class AppConfig {
  static const String version = '1.0.12';
}

enum CaseStatus {
  open('Open'),
  assigned('Assigned'),
  inProgress('In Progress'),
  pending('Pending'),
  waiting('Waiting'),
  testing('Testing'),
  done('Done'),
  closed('Closed');

  final String label;
  const CaseStatus(this.label);

  Color get color {
    switch (this) {
      case CaseStatus.open:
        return AppColors.openText;
      case CaseStatus.assigned:
        return AppColors.assignedText;
      case CaseStatus.inProgress:
        return AppColors.inProgressText;
      case CaseStatus.pending:
      case CaseStatus.waiting:
        return AppColors.pendingText;
      case CaseStatus.testing:
        return Colors.purple;
      case CaseStatus.done:
        return AppColors.doneText;
      case CaseStatus.closed:
        return AppColors.closedText;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case CaseStatus.open:
        return AppColors.openBg;
      case CaseStatus.assigned:
        return AppColors.assignedBg;
      case CaseStatus.inProgress:
        return AppColors.inProgressBg;
      case CaseStatus.pending:
      case CaseStatus.waiting:
        return AppColors.pendingBg;
      case CaseStatus.testing:
        return const Color(0xFFF3E8FF);
      case CaseStatus.done:
        return AppColors.doneBg;
      case CaseStatus.closed:
        return AppColors.closedBg;
    }
  }
}

enum CasePriority {
  low('Low'),
  medium('Medium'),
  high('High'),
  critical('Critical');

  final String label;
  const CasePriority(this.label);

  Color get color {
    switch (this) {
      case CasePriority.low:
        return AppColors.priorityLowText;
      case CasePriority.medium:
        return AppColors.priorityMediumText;
      case CasePriority.high:
        return AppColors.priorityHighText;
      case CasePriority.critical:
        return AppColors.priorityCriticalText;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case CasePriority.low:
        return AppColors.priorityLowBg;
      case CasePriority.medium:
        return AppColors.priorityMediumBg;
      case CasePriority.high:
        return AppColors.priorityHighBg;
      case CasePriority.critical:
        return AppColors.priorityCriticalBg;
    }
  }
}

enum TeamType {
  web('Web Team'),
  mobile('Mobile Team'),
  backend('Backend Team'),
  infra('Infra'),
  other('Other');

  final String label;
  const TeamType(this.label);

  Color get color {
    switch (this) {
      case TeamType.web:
        return AppColors.teamWeb;
      case TeamType.mobile:
        return AppColors.teamMobile;
      case TeamType.backend:
        return AppColors.teamBackend;
      case TeamType.infra:
        return AppColors.teamInfra;
      case TeamType.other:
        return AppColors.teamOther;
    }
  }
}

class UserModel {
  final String id;
  final String name;
  final String role;
  final String email;
  final String password;
  final String avatarUrl;
  final TeamType? team;
  final String? phoneNumber;
  final String? position;

  const UserModel({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    required this.password,
    required this.avatarUrl,
    this.team,
    this.phoneNumber,
    this.position,
  });

  UserRole get roleEnum => UserRole.fromString(role);

  UserModel copyWith({
    String? name,
    String? role,
    String? email,
    String? password,
    String? avatarUrl,
    TeamType? team,
    String? phoneNumber,
    String? position,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      email: email ?? this.email,
      password: password ?? this.password,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      team: team ?? this.team,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      position: position ?? this.position,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CommentModel {
  final String id;
  final String caseId;
  final UserModel author;
  final String content;
  final String dateText;
  final String? attachedImageUrl;
  final int likes;
  final bool isLiked;

  CommentModel({
    required this.id,
    required this.caseId,
    required this.author,
    required this.content,
    required this.dateText,
    this.attachedImageUrl,
    this.likes = 0,
    this.isLiked = false,
  });

  CommentModel copyWith({
    int? likes,
    bool? isLiked,
  }) {
    return CommentModel(
      id: id,
      caseId: caseId,
      author: author,
      content: content,
      dateText: dateText,
      attachedImageUrl: attachedImageUrl,
      likes: likes ?? this.likes,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

class ActivityLogModel {
  final String id;
  final String caseId;
  final String title;
  final String authorName;
  final String dateText;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const ActivityLogModel({
    required this.id,
    required this.caseId,
    required this.title,
    required this.authorName,
    required this.dateText,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });
}

class CaseFileAttachment {
  final String fileName;
  final String fileSize;

  const CaseFileAttachment({
    required this.fileName,
    required this.fileSize,
  });
}

class CaseModel {
  final String id;
  final String title;
  final CasePriority priority;
  final CaseStatus status;
  final TeamType team;
  final String category;
  final UserModel? assignee;
  final String dateText;
  final String systemAffected;
  final String environment;
  final String url;
  final String browser;
  final String createdById;
  final List<String> attachedImages;
  final List<CaseFileAttachment> attachedFiles;
  final List<CommentModel> comments;
  final List<ActivityLogModel> activityLogs;

  CaseModel({
    required this.id,
    required this.title,
    required this.priority,
    required this.status,
    required this.team,
    required this.category,
    this.assignee,
    required this.dateText,
    required this.systemAffected,
    required this.environment,
    required this.url,
    required this.browser,
    this.createdById = 'EMP-002', // Default to Mook if unspecified
    this.attachedImages = const [],
    this.attachedFiles = const [],
    this.comments = const [],
    this.activityLogs = const [],
  });

  CaseModel copyWith({
    String? title,
    CasePriority? priority,
    CaseStatus? status,
    TeamType? team,
    String? category,
    UserModel? assignee,
    bool clearAssignee = false,
    String? dateText,
    String? systemAffected,
    String? environment,
    String? url,
    String? browser,
    String? createdById,
    List<String>? attachedImages,
    List<CaseFileAttachment>? attachedFiles,
    List<CommentModel>? comments,
    List<ActivityLogModel>? activityLogs,
  }) {
    return CaseModel(
      id: id,
      title: title ?? this.title,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      team: team ?? this.team,
      category: category ?? this.category,
      assignee: clearAssignee ? null : (assignee ?? this.assignee),
      dateText: dateText ?? this.dateText,
      systemAffected: systemAffected ?? this.systemAffected,
      environment: environment ?? this.environment,
      url: url ?? this.url,
      browser: browser ?? this.browser,
      createdById: createdById ?? this.createdById,
      attachedImages: attachedImages ?? this.attachedImages,
      attachedFiles: attachedFiles ?? this.attachedFiles,
      comments: comments ?? this.comments,
      activityLogs: activityLogs ?? this.activityLogs,
    );
  }
}

enum NotificationModule {
  caseModule('Case Management'),
  orderDiff('Order Diff'),
  bankIssue('Bank Issue');

  final String label;
  const NotificationModule(this.label);
}

class AppNotificationModel {
  final String id;
  final String title;
  final String subtitle;
  final String timeAgo;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final bool isRead;
  final NotificationModule module;
  final String? referenceId;
  final String? caseId;
  final String? targetUserId;
  final String? targetUserName;
  final String? actorUserId;

  AppNotificationModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timeAgo,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.isRead = false,
    this.module = NotificationModule.caseModule,
    this.referenceId,
    this.caseId,
    this.targetUserId,
    this.targetUserName,
    this.actorUserId,
  });

  AppNotificationModel copyWith({
    bool? isRead,
    String? targetUserId,
    String? targetUserName,
  }) {
    return AppNotificationModel(
      id: id,
      title: title,
      subtitle: subtitle,
      timeAgo: timeAgo,
      icon: icon,
      iconColor: iconColor,
      iconBg: iconBg,
      isRead: isRead ?? this.isRead,
      module: module,
      referenceId: referenceId,
      caseId: caseId ?? this.caseId,
      targetUserId: targetUserId ?? this.targetUserId,
      targetUserName: targetUserName ?? this.targetUserName,
      actorUserId: actorUserId,
    );
  }
}

enum DeliveryType {
  express('Express'),
  sameday('Sameday'),
  nextday('Nextday'),
  normal('Normal');

  final String label;
  const DeliveryType(this.label);
}

enum OrderStatus {
  completed('C', 'สำเร็จแล้ว', Color(0xFF16A34A), Color(0xFFDCFCE7)),
  pending('P', 'กด Add ตะกร้ายังไม่ชำระ', Color(0xFF0284C7), Color(0xFFE0F2FE)),
  waitingPayment('M', 'รอชำระเงิน', Color(0xFFD97706), Color(0xFFFEF3C7)),
  expired('E', 'หมดอายุ', Color(0xFF64748B), Color(0xFFF1F5F9)),
  cancelled('X', 'ยกเลิก', Color(0xFFDC2626), Color(0xFFFEE2E2)),
  wreathTemple('W', 'ตะกร้าพวงหรีด รอชำระ (จัดส่งวัด)', Color(0xFF9333EA), Color(0xFFF3E8FF));

  final String code;
  final String label;
  final Color color;
  final Color backgroundColor;

  const OrderStatus(this.code, this.label, this.color, this.backgroundColor);

  static OrderStatus fromCode(String code) {
    return OrderStatus.values.firstWhere(
      (s) => s.code.toUpperCase() == code.toUpperCase(),
      orElse: () => OrderStatus.pending,

    );
  }
}

enum OrderCardType {
  orderDiff('Order Diff Card'),
  bankIssue('Bank Issue Card');

  final String label;
  const OrderCardType(this.label);
}

enum OrderActivityStatus {
  newOrder('New', Color(0xFF0284C7), Color(0xFFE0F2FE)),
  inProgress('In Progress', Color(0xFF2563EB), Color(0xFFDBEAFE)),
  investigating('Editing', Color(0xFFD97706), Color(0xFFFEF3C7)),
  resolved('Complete', Color(0xFF16A34A), Color(0xFFDCFCE7)),
  closed('Closed', Color(0xFF475569), Color(0xFFF1F5F9));

  final String label;
  final Color color;
  final Color backgroundColor;

  const OrderActivityStatus(this.label, this.color, this.backgroundColor);
}

class AttachmentModel {
  final String id;
  final String name;
  final String size;
  final String dateText;
  final String fileType; // 'xlsx', 'pdf', 'png', 'txt'

  const AttachmentModel({
    required this.id,
    required this.name,
    required this.size,
    required this.dateText,
    required this.fileType,
  });
}

class OrderItemModel {
  final String id; // Order No.
  final DeliveryType deliveryType;

  const OrderItemModel({
    required this.id,
    required this.deliveryType,
  });

  OrderItemModel copyWith({
    String? id,
    DeliveryType? deliveryType,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      deliveryType: deliveryType ?? this.deliveryType,
    );
  }
}

String parseDateToStandard(String dateText) {
  if (dateText == 'วันนี้') {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
  try {
    final thaiMonths = {
      'ม.ค.': '01', 'ก.พ.': '02', 'มี.ค.': '03', 'เม.ย.': '04',
      'พ.ค.': '05', 'มิ.ย.': '06', 'ก.ค.': '07', 'ส.ค.': '08',
      'ก.ย.': '09', 'ต.ค.': '10', 'พ.ย.': '11', 'ธ.ค.': '12',
    };
    for (var entry in thaiMonths.entries) {
      if (dateText.contains(entry.key)) {
        final parts = dateText.split(' ');
        if (parts.length >= 3) {
          final day = parts[0].trim().padLeft(2, '0');
          final month = entry.value;
          var yearStr = parts[2].trim();
          int? year = int.tryParse(yearStr);
          if (year != null && year > 2400) {
            year -= 543;
          }
          if (year != null) {
            return '$year-$month-$day';
          }
        }
      }
    }
  } catch (_) {}
  return dateText;
}

class BankInfo {
  final String code;
  final String name;
  const BankInfo({required this.code, required this.name});
}

const List<BankInfo> kBankList = [
  BankInfo(code: 'KBANK', name: 'ธนาคารกสิกรไทย (KBank)'),
  BankInfo(code: 'SCB', name: 'ธนาคารไทยพาณิชย์ (SCB)'),
  BankInfo(code: 'BBL', name: 'ธนาคารกรุงเทพ (BBL)'),
  BankInfo(code: 'KTB', name: 'ธนาคารกรุงไทย (KTB)'),
  BankInfo(code: 'BAY', name: 'ธนาคารกรุงศรีอยุธยา (Krungsri)'),
  BankInfo(code: 'TTB', name: 'ธนาคารทหารไทยธนชาต (ttb)'),
  BankInfo(code: 'GSB', name: 'ธนาคารออมสิน (GSB)'),
  BankInfo(code: 'GHB', name: 'ธนาคารอาคารสงเคราะห์ (GHB)'),
  BankInfo(code: 'CIMB', name: 'ธนาคารซีไอเอ็มบี ไทย'),
  BankInfo(code: 'UOB', name: 'ธนาคารยูโอบี'),
  BankInfo(code: 'KKP', name: 'ธนาคารเกียรตินาคินภัทร'),
  BankInfo(code: 'LH', name: 'ธนาคารแลนด์ แอนด์ เฮ้าส์'),
  BankInfo(code: 'TCRB', name: 'ธนาคารไทยเครดิต'),
  BankInfo(code: 'BAAC', name: 'ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร'),
  BankInfo(code: 'IBANK', name: 'ธนาคารอิสลามแห่งประเทศไทย'),
  BankInfo(code: 'ICBC', name: 'ธนาคารไอซีบีซี (ไทย)'),
  BankInfo(code: 'OTHER', name: 'อื่น ๆ (Other)'),
];

class PaymentMethodInfo {
  final String code;
  final String name;
  const PaymentMethodInfo({required this.code, required this.name});
}

const List<PaymentMethodInfo> kPaymentMethodList = [
  PaymentMethodInfo(code: 'QR_PROMPTPAY', name: 'QR Code / PromptPay'),
  PaymentMethodInfo(code: 'BANK_TRANSFER', name: 'โอนเงินผ่านธนาคาร (Bank Transfer)'),
  PaymentMethodInfo(code: 'CREDIT_CARD', name: 'บัตรเครดิต (Credit Card)'),
  PaymentMethodInfo(code: 'DEBIT_CARD', name: 'บัตรเดบิต (Debit Card)'),
  PaymentMethodInfo(code: 'E_WALLET', name: 'กระเป๋าเงินอิเล็กทรอนิกส์ (E-Wallet)'),
  PaymentMethodInfo(code: 'OTHER', name: 'อื่น ๆ (Other)'),
];

class OrderModel {
  final String id; // Card ID / Main Order No.
  final OrderCardType cardType;
  final DeliveryType deliveryType; // Default delivery type for card
  final CasePriority priority;
  final OrderActivityStatus activityStatus;
  final UserModel? assignee;
  final String createBy;
  final String dateText;
  final String? standardDate;
  final String? importFile;
  final List<AttachmentModel> attachments;
  final List<OrderItemModel> items; // Multiple order items in this card group

  // Order Diff specific
  final String? errorDetails;

  // Bank Issue specific
  final String? bankCode;
  final String? bankName;
  final String? paymentMethodCode;
  final String? paymentMethod;
  final double? amount;
  final OrderStatus? statusOrder;

  final List<CommentModel> comments;
  final List<ActivityLogModel> activityLogs;

  OrderModel({
    required this.id,
    required this.cardType,
    required this.deliveryType,
    required this.priority,
    this.activityStatus = OrderActivityStatus.newOrder,
    this.assignee,
    required this.createBy,
    required this.dateText,
    this.standardDate,
    this.importFile,
    this.attachments = const [],
    this.items = const [],
    this.errorDetails,
    this.bankCode,
    this.bankName,
    this.paymentMethodCode,
    this.paymentMethod,
    this.amount,
    this.statusOrder,
    this.comments = const [],
    this.activityLogs = const [],
  });

  List<OrderItemModel> get allItems {
    if (items.isNotEmpty) return items;
    return [OrderItemModel(id: id, deliveryType: deliveryType)];
  }

  String get effectiveStandardDate {
    if (standardDate != null && standardDate!.isNotEmpty) {
      return standardDate!;
    }
    return parseDateToStandard(dateText);
  }

  String get displayBankName {
    if (bankCode == 'OTHER') {
      return bankName ?? 'อื่น ๆ (Other)';
    }
    if (bankCode != null && bankCode!.isNotEmpty) {
      final found = kBankList.firstWhere(
        (b) => b.code.toUpperCase() == bankCode!.toUpperCase(),
        orElse: () => BankInfo(code: bankCode!, name: bankName ?? bankCode!),
      );
      return found.name;
    }
    if (bankName != null && bankName!.isNotEmpty) {
      final found = kBankList.firstWhere(
        (b) => b.code.toLowerCase() == bankName!.toLowerCase() || b.name.toLowerCase().contains(bankName!.toLowerCase()),
        orElse: () => BankInfo(code: 'OTHER', name: bankName!),
      );
      return found.name;
    }
    return 'ธนาคารไทยพาณิชย์ (SCB)';
  }

  String get displayPaymentMethod {
    if (paymentMethodCode == 'OTHER') {
      return paymentMethod ?? 'อื่น ๆ (Other)';
    }
    if (paymentMethodCode != null && paymentMethodCode!.isNotEmpty) {
      final found = kPaymentMethodList.firstWhere(
        (p) => p.code.toUpperCase() == paymentMethodCode!.toUpperCase(),
        orElse: () => PaymentMethodInfo(code: paymentMethodCode!, name: paymentMethod ?? paymentMethodCode!),
      );
      return found.name;
    }
    if (paymentMethod != null && paymentMethod!.isNotEmpty) {
      final found = kPaymentMethodList.firstWhere(
        (p) => p.code.toLowerCase() == paymentMethod!.toLowerCase() || p.name.toLowerCase().contains(paymentMethod!.toLowerCase()),
        orElse: () => PaymentMethodInfo(code: 'OTHER', name: paymentMethod!),
      );
      return found.name;
    }
    return 'QR Code / PromptPay';
  }

  OrderModel copyWith({
    String? id,
    OrderCardType? cardType,
    DeliveryType? deliveryType,
    CasePriority? priority,
    OrderActivityStatus? activityStatus,
    UserModel? assignee,
    bool clearAssignee = false,
    String? createBy,
    String? dateText,
    String? standardDate,
    bool clearStandardDate = false,
    String? importFile,
    bool clearImportFile = false,
    List<AttachmentModel>? attachments,
    List<OrderItemModel>? items,
    String? errorDetails,
    String? bankCode,
    bool clearBankCode = false,
    String? bankName,
    bool clearBankName = false,
    String? paymentMethodCode,
    bool clearPaymentMethodCode = false,
    String? paymentMethod,
    bool clearPaymentMethod = false,
    double? amount,
    OrderStatus? statusOrder,
    List<CommentModel>? comments,
    List<ActivityLogModel>? activityLogs,
  }) {
    return OrderModel(
      id: id ?? this.id,
      cardType: cardType ?? this.cardType,
      deliveryType: deliveryType ?? this.deliveryType,
      priority: priority ?? this.priority,
      activityStatus: activityStatus ?? this.activityStatus,
      assignee: clearAssignee ? null : (assignee ?? this.assignee),
      createBy: createBy ?? this.createBy,
      dateText: dateText ?? this.dateText,
      standardDate: clearStandardDate ? null : (standardDate ?? this.standardDate),
      importFile: clearImportFile ? null : (importFile ?? this.importFile),
      attachments: attachments ?? this.attachments,
      items: items ?? this.items,
      errorDetails: errorDetails ?? this.errorDetails,
      bankCode: clearBankCode ? null : (bankCode ?? this.bankCode),
      bankName: clearBankName ? null : (bankName ?? this.bankName),
      paymentMethodCode: clearPaymentMethodCode ? null : (paymentMethodCode ?? this.paymentMethodCode),
      paymentMethod: clearPaymentMethod ? null : (paymentMethod ?? this.paymentMethod),
      amount: amount ?? this.amount,
      statusOrder: statusOrder ?? this.statusOrder,
      comments: comments ?? this.comments,
      activityLogs: activityLogs ?? this.activityLogs,
    );
  }
}

enum OrderPermission {
  createOrder,
  editOrder,
  deleteOrder,
  changeBankIssueStatus,
  addComment,
}

class OrderRolePermissionHelper {
  static bool hasPermission(UserRole role, OrderPermission permission) {
    switch (role) {
      case UserRole.admin:
      case UserRole.teamLead:
        return true;
      case UserRole.developer:
        return permission != OrderPermission.deleteOrder;
      case UserRole.user:
        return permission == OrderPermission.createOrder ||
            permission == OrderPermission.editOrder ||
            permission == OrderPermission.addComment;
    }
  }

  static bool canAccessOrder(UserModel user, OrderModel order) {
    final role = user.roleEnum;
    if (role == UserRole.admin || role == UserRole.teamLead || role == UserRole.developer) {
      return true;
    }
    return order.createBy.toLowerCase() == user.name.toLowerCase() || order.assignee?.id == user.id;
  }

  static bool canUpdateActivityStatus(UserModel user, OrderModel order) {
    final role = user.roleEnum;
    if (role == UserRole.admin || role == UserRole.teamLead) {
      return true;
    }
    if (role == UserRole.developer) {
      // Developer can only change activity status if assigned to them
      return order.assignee?.id == user.id;
    }
    return false;
  }
}



