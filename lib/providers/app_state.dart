import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_models.dart';
import '../models/role_permission.dart';
import '../theme/app_theme.dart';

class AppState extends ChangeNotifier {
  // Pre-configured registered users list
  final List<UserModel> registeredUsers = [
    const UserModel(
      id: 'EMP-001',
      name: 'Patis',
      role: 'Developer',
      email: 'patis@company.com',
      password: '123456',
      avatarUrl: 'P',
      team: TeamType.web,
      phoneNumber: '081-234-5678',
      position: 'Senior Frontend Developer',
    ),
    const UserModel(
      id: 'EMP-002',
      name: 'Mook',
      role: 'User',
      email: 'mook@company.com',
      password: '123456',
      avatarUrl: 'M',
      team: TeamType.web,
      phoneNumber: '089-876-5432',
      position: 'Product Specialist',
    ),
    const UserModel(
      id: 'EMP-003',
      name: 'John',
      role: 'Team Lead',
      email: 'john@company.com',
      password: '123456',
      avatarUrl: 'J',
      team: TeamType.web,
      phoneNumber: '082-111-2222',
      position: 'Web Development Lead',
    ),
    const UserModel(
      id: 'EMP-004',
      name: 'Admin',
      role: 'Admin',
      email: 'admin@company.com',
      password: '123456',
      avatarUrl: 'A',
      team: TeamType.infra,
      phoneNumber: '080-999-8888',
      position: 'System Administrator',
    ),
  ];

  // Active logged-in user
  late UserModel currentUser;

  // Convenient shortcuts
  UserModel get mookUser => registeredUsers.firstWhere((u) => u.name == 'Mook', orElse: () => registeredUsers[1]);
  UserModel get johnUser => registeredUsers.firstWhere((u) => u.name == 'John', orElse: () => registeredUsers[2]);

  // Authentication state
  bool isLoggedIn = false;

  // Selected bottom nav index (0: Dashboard, 1: Case List, 2: Notifications, 3: Profile)
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

  AppState() {
    currentUser = registeredUsers.first; // Default to Patis
    _initData();
  }

  // Authenticators
  bool loginWithCredentials(String email, String password) {
    final matchIndex = registeredUsers.indexWhere(
      (u) => u.email.trim().toLowerCase() == email.trim().toLowerCase() && u.password == password.trim(),
    );

    if (matchIndex != -1) {
      currentUser = registeredUsers[matchIndex];
      isLoggedIn = true;
      selectedNavIndex = 0; // Reset tab to Dashboard
      notifyListeners();
      return true;
    }
    return false;
  }

  bool registerUser({
    required String name,
    required String role,
    required String email,
    required String password,
    TeamType? team,
  }) {
    // Check if email already exists
    final exists = registeredUsers.any(
      (u) => u.email.trim().toLowerCase() == email.trim().toLowerCase(),
    );

    if (exists) return false;

    final avatarLetter = name.trim().isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : 'U';
    final newUser = UserModel(
      id: 'EMP-00${registeredUsers.length + 1}',
      name: name.trim(),
      role: role.trim(),
      email: email.trim().toLowerCase(),
      password: password.trim(),
      avatarUrl: avatarLetter,
      team: team ?? TeamType.web,
      phoneNumber: '081-000-0000',
      position: role.trim(),
    );

    registeredUsers.add(newUser);
    currentUser = newUser;
    isLoggedIn = true;
    selectedNavIndex = 0; // Reset tab to Dashboard
    notifyListeners();
    return true;
  }

  void quickDemoLogin(UserModel user) {
    currentUser = user;
    isLoggedIn = true;
    selectedNavIndex = 0; // Reset tab to Dashboard
    notifyListeners();
  }

  void _initData() {
    // Standard Comments & Activity Logs for DEV-001
    final dev001Logs = [
      const ActivityLogModel(
        id: 'act-101',
        caseId: 'DEV-001',
        title: 'สร้างเคส',
        authorName: 'Patis',
        dateText: '13 ก.ย. 2566 09:15',
        icon: Icons.add_circle,
        iconColor: Colors.blue,
        iconBgColor: Color(0xFFDBEAFE),
      ),
      const ActivityLogModel(
        id: 'act-102',
        caseId: 'DEV-001',
        title: 'มอบหมายให้ Patis',
        authorName: 'John',
        dateText: '13 ก.ย. 2566 09:30',
        icon: Icons.person_add,
        iconColor: Colors.indigo,
        iconBgColor: Color(0xFFE0E7FF),
      ),
      const ActivityLogModel(
        id: 'act-103',
        caseId: 'DEV-001',
        title: 'เปลี่ยนสถานะ: Open → In Progress',
        authorName: 'Patis',
        dateText: '13 ก.ย. 2566 10:00',
        icon: Icons.sync,
        iconColor: Colors.teal,
        iconBgColor: Color(0xFFCCFBF1),
      ),
      const ActivityLogModel(
        id: 'act-104',
        caseId: 'DEV-001',
        title: 'เพิ่มความคิดเห็น',
        authorName: 'Mook',
        dateText: '13 ก.ย. 2566 11:30',
        icon: Icons.chat_bubble,
        iconColor: Colors.blueAccent,
        iconBgColor: Color(0xFFE0F2FE),
      ),
    ];

    final dev001Comments = [
      CommentModel(
        id: 'c-101',
        caseId: 'DEV-001',
        author: mookUser,
        content: 'ผู้ใช้งานหลายรายแจ้งเข้ามาว่า เมื่อกดปุ่ม Login บนหน้าเว็บแล้วระบบเด้ง HTTP 500 Internal Server Error ครับ',
        dateText: '13 ก.ย. 2566 09:20',
        likes: 3,
        isLiked: true,
      ),
      CommentModel(
        id: 'c-102',
        caseId: 'DEV-001',
        author: registeredUsers.first, // Patis
        content: 'กำลังตรวจสอบการทำงานของ Auth Service ในคัสเตอร์ และจะอัปเดตการแก้ไขปัญหา CORS / Token ให้ทราบครับ',
        dateText: '13 ก.ย. 2566 10:05',
        likes: 1,
        isLiked: false,
      ),
      CommentModel(
        id: 'c-103',
        caseId: 'DEV-001',
        author: johnUser,
        content: 'เร่งดำเนินการแก้ไขหน่อยนะครับ มีผู้ใช้งานเข้ามารายงานปัญหานี้เพิ่มขึ้นครับ',
        dateText: '13 ก.ย. 2566 11:45',
        likes: 2,
        isLiked: false,
      ),
    ];

    // Standard Comments & Activity Logs for DEV-002
    final dev002Logs = [
      const ActivityLogModel(
        id: 'act-201',
        caseId: 'DEV-002',
        title: 'สร้างเคส',
        authorName: 'Mook',
        dateText: '14 ก.ย. 2566 08:30',
        icon: Icons.add_circle,
        iconColor: Colors.blue,
        iconBgColor: Color(0xFFDBEAFE),
      ),
      const ActivityLogModel(
        id: 'act-202',
        caseId: 'DEV-002',
        title: 'มอบหมายให้ John',
        authorName: 'Mook',
        dateText: '14 ก.ย. 2566 08:45',
        icon: Icons.person_add,
        iconColor: Colors.indigo,
        iconBgColor: Color(0xFFE0E7FF),
      ),
      const ActivityLogModel(
        id: 'act-203',
        caseId: 'DEV-002',
        title: 'เพิ่มความคิดเห็น',
        authorName: 'John',
        dateText: '14 ก.ย. 2566 10:20',
        icon: Icons.chat_bubble,
        iconColor: Colors.blueAccent,
        iconBgColor: Color(0xFFE0F2FE),
      ),
      const ActivityLogModel(
        id: 'act-204',
        caseId: 'DEV-002',
        title: 'แนบไฟล์ api_trace.log',
        authorName: 'Admin',
        dateText: '14 ก.ย. 2566 14:00',
        icon: Icons.attach_file,
        iconColor: Colors.green,
        iconBgColor: Color(0xFFDCFCE7),
      ),
    ];

    final dev002Comments = [
      CommentModel(
        id: 'c-201',
        caseId: 'DEV-002',
        author: mookUser,
        content: 'ระบบ API Gateway มีการรีสปอนส์ตอบกลับล่าช้า และส่งกลับ Connection Refused เป็นระยะบนสภาพแวดล้อม Staging ครับ',
        dateText: '14 ก.ย. 2566 08:35',
        likes: 1,
        isLiked: false,
      ),
      CommentModel(
        id: 'c-202',
        caseId: 'DEV-002',
        author: johnUser,
        content: 'ตรวจสอบพบว่า Connection Pool ใน Database เต็ม ได้ทำการขยายขนาด Max Connections และกำลังมอนิเตอร์ต่อครับ',
        dateText: '14 ก.ย. 2566 10:20',
        likes: 4,
        isLiked: true,
      ),
      CommentModel(
        id: 'c-203',
        caseId: 'DEV-002',
        author: registeredUsers[3], // Admin
        content: 'ทำการเพิ่มทรัพยากร RAM/CPU บน Pod เซิร์ฟเวอร์เรียบร้อยแล้วครับ',
        dateText: '14 ก.ย. 2566 14:15',
        likes: 2,
        isLiked: false,
      ),
    ];

    // Standard Activity Logs for DEV-003
    final dev003Logs = [
      const ActivityLogModel(
        id: 'act-1',
        caseId: 'DEV-003',
        title: 'สร้างเคส',
        authorName: 'Mook',
        dateText: '15 ก.ย. 2566 10:32',
        icon: Icons.add_circle,
        iconColor: Colors.blue,
        iconBgColor: Color(0xFFDBEAFE),
      ),
      const ActivityLogModel(
        id: 'act-2',
        caseId: 'DEV-003',
        title: 'มอบหมายให้ Patis',
        authorName: 'Mook',
        dateText: '15 ก.ย. 2566 09:45',
        icon: Icons.person_add,
        iconColor: Colors.indigo,
        iconBgColor: Color(0xFFE0E7FF),
      ),
      const ActivityLogModel(
        id: 'act-3',
        caseId: 'DEV-003',
        title: 'เปลี่ยนสถานะ: Open → In Progress',
        authorName: 'Patis',
        dateText: '15 ก.ย. 2566 11:20',
        icon: Icons.sync,
        iconColor: Colors.teal,
        iconBgColor: Color(0xFFCCFBF1),
      ),
      const ActivityLogModel(
        id: 'act-4',
        caseId: 'DEV-003',
        title: 'เพิ่มความคิดเห็น',
        authorName: 'Mook',
        dateText: '15 ก.ย. 2566 14:10',
        icon: Icons.chat_bubble,
        iconColor: Colors.blueAccent,
        iconBgColor: Color(0xFFE0F2FE),
      ),
      const ActivityLogModel(
        id: 'act-5',
        caseId: 'DEV-003',
        title: 'แนบไฟล์ error_screenshot.png',
        authorName: 'Patis',
        dateText: '15 ก.ย. 2566 16:20',
        icon: Icons.attach_file,
        iconColor: Colors.green,
        iconBgColor: Color(0xFFDCFCE7),
      ),
    ];

    // Standard Comments for DEV-003
    final dev003Comments = [
      CommentModel(
        id: 'c-1',
        caseId: 'DEV-003',
        author: mookUser,
        content: 'พบปัญหาหลังจากอัปเดตเวอร์ชันล่าสุดครับ แนบรูปภาพให้ด้วยครับ',
        dateText: '15 ก.ย. 2566 10:32',
        attachedImageUrl: 'img1',
        likes: 2,
        isLiked: true,
      ),
      CommentModel(
        id: 'c-2',
        caseId: 'DEV-003',
        author: registeredUsers.first,
        content: 'กำลังตรวจสอบปัญหา และจะอัปเดตให้ทราบครับ',
        dateText: '15 ก.ย. 2566 11:05',
        likes: 0,
        isLiked: false,
      ),
      CommentModel(
        id: 'c-3',
        caseId: 'DEV-003',
        author: johnUser,
        content: 'ตรวจสอบแล้ว พบว่าเกิดจาก API timeout กำลังแก้ไขอยู่นะครับ',
        dateText: '15 ก.ย. 2566 13:20',
        likes: 1,
        isLiked: false,
      ),
    ];

    // Standard Comments & Activity Logs for DEV-004
    final dev004Logs = [
      const ActivityLogModel(
        id: 'act-401',
        caseId: 'DEV-004',
        title: 'สร้างเคส',
        authorName: 'John',
        dateText: '12 ก.ย. 2566 11:10',
        icon: Icons.add_circle,
        iconColor: Colors.blue,
        iconBgColor: Color(0xFFDBEAFE),
      ),
      const ActivityLogModel(
        id: 'act-402',
        caseId: 'DEV-004',
        title: 'มอบหมายให้ Admin',
        authorName: 'John',
        dateText: '12 ก.ย. 2566 11:25',
        icon: Icons.person_add,
        iconColor: Colors.indigo,
        iconBgColor: Color(0xFFE0E7FF),
      ),
      const ActivityLogModel(
        id: 'act-403',
        caseId: 'DEV-004',
        title: 'เปลี่ยนสถานะ: Open → Pending',
        authorName: 'Admin',
        dateText: '12 ก.ย. 2566 13:00',
        icon: Icons.sync,
        iconColor: Colors.teal,
        iconBgColor: Color(0xFFCCFBF1),
      ),
      const ActivityLogModel(
        id: 'act-404',
        caseId: 'DEV-004',
        title: 'เพิ่มความคิดเห็น',
        authorName: 'Admin',
        dateText: '12 ก.ย. 2566 15:40',
        icon: Icons.chat_bubble,
        iconColor: Colors.blueAccent,
        iconBgColor: Color(0xFFE0F2FE),
      ),
    ];

    final dev004Comments = [
      CommentModel(
        id: 'c-401',
        caseId: 'DEV-004',
        author: johnUser,
        content: 'ลูกค้าชำระเงินผ่านช่องทาง Payment Gateway แล้วระบบหมุนค้างประมาณ 30 วินาที จนเด้งหน้า Timeout ครับ',
        dateText: '12 ก.ย. 2566 11:15',
        likes: 2,
        isLiked: true,
      ),
      CommentModel(
        id: 'c-402',
        caseId: 'DEV-004',
        author: registeredUsers[3], // Admin
        content: 'กำลังประสานงานกับทีม Payment Gateway ฝั่งธนาคารเพื่อตรวจสอบความเสถียรของ Webhook Callback อยู่ครับ',
        dateText: '12 ก.ย. 2566 13:05',
        likes: 3,
        isLiked: false,
      ),
    ];

    // Standard Comments & Activity Logs for DEV-005
    final dev005Logs = [
      const ActivityLogModel(
        id: 'act-501',
        caseId: 'DEV-005',
        title: 'สร้างเคส',
        authorName: 'Mook',
        dateText: '11 ก.ย. 2566 14:20',
        icon: Icons.add_circle,
        iconColor: Colors.blue,
        iconBgColor: Color(0xFFDBEAFE),
      ),
      const ActivityLogModel(
        id: 'act-502',
        caseId: 'DEV-005',
        title: 'มอบหมายให้ Patis',
        authorName: 'Mook',
        dateText: '11 ก.ย. 2566 14:35',
        icon: Icons.person_add,
        iconColor: Colors.indigo,
        iconBgColor: Color(0xFFE0E7FF),
      ),
      const ActivityLogModel(
        id: 'act-503',
        caseId: 'DEV-005',
        title: 'เพิ่มความคิดเห็น',
        authorName: 'Patis',
        dateText: '11 ก.ย. 2566 17:15',
        icon: Icons.chat_bubble,
        iconColor: Colors.blueAccent,
        iconBgColor: Color(0xFFE0F2FE),
      ),
    ];

    final dev005Comments = [
      CommentModel(
        id: 'c-501',
        caseId: 'DEV-005',
        author: mookUser,
        content: 'พบตัวอักษรตกขอบล้นหน้าจอ (RenderFlex Overflow) บนหน้าจอมือถือขนาดเล็ก เช่น iPhone SE และ Android จอเล็กครับ',
        dateText: '11 ก.ย. 2566 14:25',
        likes: 1,
        isLiked: false,
      ),
      CommentModel(
        id: 'c-502',
        caseId: 'DEV-005',
        author: registeredUsers.first, // Patis
        content: 'รับทราบครับ กำลังปรับโครงสร้าง Layout ให้ใช้ SingleChildScrollView และ FlexBox แบบ Responsive ครับ',
        dateText: '11 ก.ย. 2566 17:15',
        likes: 2,
        isLiked: true,
      ),
    ];

    // Standard Comments & Activity Logs for DEV-006 (Unassigned Case)
    final dev006Logs = [
      const ActivityLogModel(
        id: 'act-601',
        caseId: 'DEV-006',
        title: 'สร้างเคส',
        authorName: 'Mook',
        dateText: '10 ก.ย. 2566 16:10',
        icon: Icons.add_circle,
        iconColor: Colors.blue,
        iconBgColor: Color(0xFFDBEAFE),
      ),
      const ActivityLogModel(
        id: 'act-602',
        caseId: 'DEV-006',
        title: 'รอการมอบหมายผู้รับผิดชอบ',
        authorName: 'System',
        dateText: '10 ก.ย. 2566 16:10',
        icon: Icons.person_outline,
        iconColor: Colors.orange,
        iconBgColor: Color(0xFFFEF3C7),
      ),
    ];

    final dev006Comments = [
      CommentModel(
        id: 'c-601',
        caseId: 'DEV-006',
        author: mookUser,
        content: 'ระบบส่งอีเมลยืนยันการทำรายการหยุดทำงานกะทันหัน ผู้ใช้ไม่ได้รับ OTP ทางอีเมลครับ รบกวน Team Lead / Admin มอบหมายผู้รับผิดชอบด่วนครับ',
        dateText: '10 ก.ย. 2566 16:12',
        likes: 1,
        isLiked: false,
      ),
    ];

    cases = [
      CaseModel(
        id: 'DEV-003',
        title: 'หน้า Dashboard แสดงผลผิด',
        priority: CasePriority.low,
        status: CaseStatus.inProgress,
        team: TeamType.web,
        category: 'UI/UX',
        assignee: registeredUsers.first,
        dateText: '15 ก.ย. 2566',
        systemAffected: 'Web Application',
        environment: 'Production',
        url: 'https://app.company.com/dashboard',
        browser: 'Chrome (Version 128)',
        createdById: 'EMP-002',
        attachedImages: ['img1', 'img2', 'img3'],
        attachedFiles: const [
          CaseFileAttachment(fileName: 'error_screenshot.png', fileSize: '2.4 MB'),
          CaseFileAttachment(fileName: 'log.txt', fileSize: '120 KB'),
        ],
        comments: dev003Comments,
        activityLogs: dev003Logs,
      ),
      CaseModel(
        id: 'DEV-002',
        title: 'API Connection Error',
        priority: CasePriority.medium,
        status: CaseStatus.open,
        team: TeamType.backend,
        category: 'Technical',
        assignee: johnUser,
        dateText: '14 ก.ย. 2566',
        systemAffected: 'API Gateway',
        environment: 'Staging',
        url: 'https://api.company.com/v1',
        browser: 'N/A',
        createdById: 'EMP-002',
        comments: dev002Comments,
        activityLogs: dev002Logs,
      ),
      CaseModel(
        id: 'DEV-001',
        title: 'Login ไม่สามารถใช้งานได้',
        priority: CasePriority.high,
        status: CaseStatus.inProgress,
        team: TeamType.web,
        category: 'Bug',
        assignee: registeredUsers.first,
        dateText: '13 ก.ย. 2566',
        systemAffected: 'Auth System',
        environment: 'Production',
        url: 'https://app.company.com/login',
        browser: 'Chrome / Safari',
        createdById: 'EMP-001',
        comments: dev001Comments,
        activityLogs: dev001Logs,
      ),
      CaseModel(
        id: 'DEV-004',
        title: 'ระบบชำระเงินไทม์เอาต์',
        priority: CasePriority.medium,
        status: CaseStatus.pending,
        team: TeamType.infra,
        category: 'Performance',
        assignee: registeredUsers.last,
        dateText: '12 ก.ย. 2566',
        systemAffected: 'Payment Gateway',
        environment: 'Production',
        url: 'https://pay.company.com',
        browser: 'All Browsers',
        createdById: 'EMP-003',
        comments: dev004Comments,
        activityLogs: dev004Logs,
      ),
      CaseModel(
        id: 'DEV-005',
        title: 'หน้า Mobile แสดงผลผิด',
        priority: CasePriority.low,
        status: CaseStatus.open,
        team: TeamType.mobile,
        category: 'UI/UX',
        assignee: registeredUsers.first,
        dateText: '11 ก.ย. 2566',
        systemAffected: 'Mobile Application',
        createdById: 'EMP-002',
        environment: 'Production App',
        url: 'App v1.2.4 (Build 108) (iOS)',
        browser: 'iPhone 15 Pro (iOS 17.5)',
        comments: dev005Comments,
        activityLogs: dev005Logs,
      ),
      CaseModel(
        id: 'DEV-006',
        title: 'ระบบแจ้งเตือนอีเมลส่งไม่ออก',
        priority: CasePriority.critical,
        status: CaseStatus.open,
        team: TeamType.infra,
        category: 'Email Service',
        assignee: null,
        dateText: '10 ก.ย. 2566',
        systemAffected: 'SMTP Gateway / Notification Service',
        environment: 'Production',
        url: 'N/A',
        browser: 'N/A',
        createdById: 'EMP-002',
        comments: dev006Comments,
        activityLogs: dev006Logs,
      ),
      CaseModel(
        id: 'DEV-007',
        title: 'API Gateway Timeout ในช่วง Peak Hours',
        priority: CasePriority.critical,
        status: CaseStatus.inProgress,
        team: TeamType.backend,
        category: 'API Gateway',
        assignee: registeredUsers.first,
        dateText: '9 ก.ย. 2566',
        systemAffected: 'API Gateway / Microservices',
        environment: 'Production',
        url: 'https://api.company.com',
        browser: 'N/A',
        createdById: 'EMP-001',
      ),
      CaseModel(
        id: 'DEV-008',
        title: 'ไม่สามารถอัปโหลดรูปภาพโปรไฟล์ขนาดใหญ่ได้',
        priority: CasePriority.medium,
        status: CaseStatus.open,
        team: TeamType.web,
        category: 'Storage Service',
        assignee: registeredUsers[1],
        dateText: '8 ก.ย. 2566',
        systemAffected: 'User Profile / S3 Storage',
        environment: 'Production',
        url: 'https://app.company.com/profile',
        browser: 'Chrome (Version 128)',
        createdById: 'EMP-002',
      ),
      CaseModel(
        id: 'DEV-009',
        title: 'Push Notification แจ้งเตือนดีเลย์บน Android',
        priority: CasePriority.high,
        status: CaseStatus.assigned,
        team: TeamType.mobile,
        category: 'Notification',
        assignee: registeredUsers[2],
        dateText: '7 ก.ย. 2566',
        systemAffected: 'FCM / Mobile App',
        environment: 'Production App',
        url: 'App v1.2.5 (Android)',
        browser: 'Samsung Galaxy S24',
        createdById: 'EMP-003',
      ),
      CaseModel(
        id: 'DEV-010',
        title: 'ฐานข้อมูล CPU Spike เกิน 90%',
        priority: CasePriority.critical,
        status: CaseStatus.pending,
        team: TeamType.infra,
        category: 'Database',
        assignee: registeredUsers.last,
        dateText: '6 ก.ย. 2566',
        systemAffected: 'PostgreSQL Cluster',
        environment: 'Production',
        url: 'internal.db.company.com',
        browser: 'N/A',
        createdById: 'EMP-004',
      ),
      CaseModel(
        id: 'DEV-011',
        title: 'หน้าแดชบอร์ดโหลดข้อมูลช้าในหน้ารายงานยอดขาย',
        priority: CasePriority.low,
        status: CaseStatus.done,
        team: TeamType.web,
        category: 'Reporting',
        assignee: registeredUsers.first,
        dateText: '5 ก.ย. 2566',
        systemAffected: 'Sales Analytics Service',
        environment: 'Production',
        url: 'https://app.company.com/reports',
        browser: 'Firefox / Chrome',
        createdById: 'EMP-001',
      ),
    ];

    // Orders Initial Mock Data (Order Diff & Bank Issue Cards)
    orders = [
      OrderModel(
        id: '849201',
        cardType: OrderCardType.orderDiff,
        deliveryType: DeliveryType.express,
        priority: CasePriority.high,
        assignee: registeredUsers.first,
        createBy: 'Narin S.',
        dateText: '12 ต.ค. 2569',
        attachments: const [
          AttachmentModel(
            id: 'att-1',
            name: 'order_diff_20251012.xlsx',
            size: '2.4 MB',
            dateText: '12 ต.ค. 2569',
            fileType: 'xlsx',
          ),
        ],
        errorDetails: 'Product not found\nไม่พบสินค้าตามรหัสที่ระบุ',
        comments: [
          CommentModel(
            id: 'c-1',
            caseId: '849201',
            author: const UserModel(id: 'EMP-050', name: 'Jakkapat T.', role: 'Team Backend', email: 'jakkapat@company.com', password: '', avatarUrl: 'JT'),
            content: 'ตรวจสอบแล้ว เป็นปัญหายังจากรหัสสินค้า ไม่ได้อยู่ในระบบ',
            dateText: '12 ต.ค. 2569 15:20',
          ),
          CommentModel(
            id: 'c-2',
            caseId: '849201',
            author: const UserModel(id: 'EMP-051', name: 'Narin S.', role: 'Team Lead', email: 'narin@company.com', password: '', avatarUrl: 'NS'),
            content: 'รับทราบครับ ให้ทีมแก้ไขและอัปเดตสถานะเมื่อเสร็จสิ้น',
            dateText: '12 ต.ค. 2569 16:05',
          ),
          CommentModel(
            id: 'c-3',
            caseId: '849201',
            author: const UserModel(id: 'EMP-052', name: 'Krit P.', role: 'Developer', email: 'krit@company.com', password: '', avatarUrl: 'KP'),
            content: 'แก้ไขเรียบร้อยแล้ว กำลังทดสอบครับ',
            dateText: '12 ต.ค. 2569 17:30',
          ),
        ],
        activityLogs: [
          const ActivityLogModel(
            id: 'act-1',
            caseId: '849201',
            title: 'สร้างการ์ดออเดอร์',
            authorName: 'Narin S.',
            dateText: '12 ต.ค. 2569 14:32',
            icon: Icons.add_circle,
            iconColor: Colors.blue,
            iconBgColor: Color(0xFFDBEAFE),
          ),
        ],
      ),
      OrderModel(
        id: '392810',
        cardType: OrderCardType.bankIssue,
        deliveryType: DeliveryType.sameday,
        priority: CasePriority.critical,
        assignee: registeredUsers.last,
        createBy: 'John',
        dateText: '30 ต.ค. 2569',
        attachments: const [
          AttachmentModel(
            id: 'att-2',
            name: 'transfer_slip.png',
            size: '1.1 MB',
            dateText: '30 ต.ค. 2569',
            fileType: 'png',
          ),
        ],
        bankName: 'SCB',
        paymentMethod: 'QR Code',
        amount: 2500.0,
        statusOrder: OrderStatus.waitingPayment, // M
      ),
      OrderModel(
        id: '738201',
        cardType: OrderCardType.orderDiff,
        deliveryType: DeliveryType.nextday,
        priority: CasePriority.medium,
        assignee: null,
        createBy: 'Mook',
        dateText: '29 ต.ค. 2569',
        attachments: const [
          AttachmentModel(
            id: 'att-3',
            name: 'log_error.txt',
            size: '45 KB',
            dateText: '29 ต.ค. 2569',
            fileType: 'txt',
          ),
        ],
        errorDetails: 'ERR_WEIGHT_OVERFLOW - น้ำหนักเกินพิกัดขนส่ง',
      ),
      OrderModel(
        id: '592810',
        cardType: OrderCardType.bankIssue,
        deliveryType: DeliveryType.normal,
        priority: CasePriority.low,
        assignee: registeredUsers[2],
        createBy: 'Mook',
        dateText: '28 ต.ค. 2569',
        importFile: 'slip_kbank.pdf',
        bankName: 'KBank',
        paymentMethod: 'Mobile Banking',
        amount: 1200.0,
        statusOrder: OrderStatus.completed, // C
      ),
      OrderModel(
        id: '619283',
        cardType: OrderCardType.bankIssue,
        deliveryType: DeliveryType.express,
        priority: CasePriority.high,
        assignee: registeredUsers.first,
        createBy: 'John',
        dateText: '27 ต.ค. 2569',
        importFile: 'wreath_temple_slip.jpg',
        bankName: 'BBL',
        paymentMethod: 'Transfer',
        amount: 4500.0,
        statusOrder: OrderStatus.wreathTemple, // W
      ),
      // 5 New Order Diff Cards
      OrderModel(
        id: '6200078',
        cardType: OrderCardType.orderDiff,
        deliveryType: DeliveryType.express,
        priority: CasePriority.high,
        assignee: registeredUsers.first,
        createBy: 'Patis',
        dateText: '26 ต.ค. 2569',
        errorDetails: 'ERR_SKU_NOT_FOUND - รหัสสินค้าไม่ตรงกับฐานข้อมูลสต็อก',
        activityStatus: OrderActivityStatus.inProgress,
      ),
      OrderModel(
        id: '6200079',
        cardType: OrderCardType.orderDiff,
        deliveryType: DeliveryType.sameday,
        priority: CasePriority.medium,
        assignee: null,
        createBy: 'Mook',
        dateText: '25 ต.ค. 2569',
        errorDetails: 'ERR_STOCK_OUT - สินค้าในคลังหมดขณะทำการแพ็ค',
        activityStatus: OrderActivityStatus.newOrder,
      ),
      OrderModel(
        id: '6200080',
        cardType: OrderCardType.orderDiff,
        deliveryType: DeliveryType.nextday,
        priority: CasePriority.low,
        assignee: registeredUsers[1],
        createBy: 'John',
        dateText: '24 ต.ค. 2569',
        errorDetails: 'ERR_PRICE_MISMATCH - ราคาสินค้าไม่ตรงกับโปรโมชั่น',
        activityStatus: OrderActivityStatus.resolved,
      ),
      OrderModel(
        id: '6200081',
        cardType: OrderCardType.orderDiff,
        deliveryType: DeliveryType.normal,
        priority: CasePriority.critical,
        assignee: registeredUsers[2],
        createBy: 'Mook',
        dateText: '23 ต.ค. 2569',
        errorDetails: 'ERR_ADDRESS_INVALID - ที่อยู่จัดส่งไม่ครบถ้วน / ไม่มีรหัสไปรษณีย์',
        activityStatus: OrderActivityStatus.investigating,
      ),
      OrderModel(
        id: '6200082',
        cardType: OrderCardType.orderDiff,
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        assignee: registeredUsers.first,
        createBy: 'Narin S.',
        dateText: '22 ต.ค. 2569',
        errorDetails: 'ERR_QUANTITY_LIMIT - จำนวนสั่งซื้อเกินโควต้าสูงสุดต่อคน',
        activityStatus: OrderActivityStatus.closed,
      ),
      // 5 New Bank Issue Cards
      OrderModel(
        id: '7300011',
        cardType: OrderCardType.bankIssue,
        deliveryType: DeliveryType.sameday,
        priority: CasePriority.critical,
        assignee: registeredUsers[1],
        createBy: 'John',
        dateText: '26 ต.ค. 2569',
        bankName: 'KBank',
        paymentMethod: 'QR Code',
        amount: 3400.0,
        statusOrder: OrderStatus.waitingPayment, // M
        activityStatus: OrderActivityStatus.inProgress,
      ),
      OrderModel(
        id: '7300012',
        cardType: OrderCardType.bankIssue,
        deliveryType: DeliveryType.express,
        priority: CasePriority.high,
        assignee: registeredUsers.first,
        createBy: 'Patis',
        dateText: '25 ต.ค. 2569',
        bankName: 'SCB',
        paymentMethod: 'Mobile Banking',
        amount: 1850.0,
        statusOrder: OrderStatus.completed, // C
        activityStatus: OrderActivityStatus.resolved,
      ),
      OrderModel(
        id: '7300013',
        cardType: OrderCardType.bankIssue,
        deliveryType: DeliveryType.nextday,
        priority: CasePriority.medium,
        assignee: null,
        createBy: 'Mook',
        dateText: '24 ต.ค. 2569',
        bankName: 'BBL',
        paymentMethod: 'Transfer',
        amount: 5200.0,
        statusOrder: OrderStatus.pending, // P
        activityStatus: OrderActivityStatus.newOrder,
      ),
      OrderModel(
        id: '7300014',
        cardType: OrderCardType.bankIssue,
        deliveryType: DeliveryType.normal,
        priority: CasePriority.low,
        assignee: registeredUsers[2],
        createBy: 'John',
        dateText: '23 ต.ค. 2569',
        bankName: 'KTB',
        paymentMethod: 'QR Code',
        amount: 990.0,
        statusOrder: OrderStatus.expired, // E
        activityStatus: OrderActivityStatus.closed,
      ),
      OrderModel(
        id: '7300015',
        cardType: OrderCardType.bankIssue,
        deliveryType: DeliveryType.express,
        priority: CasePriority.critical,
        assignee: registeredUsers.first,
        createBy: 'Mook',
        dateText: '22 ต.ค. 2569',
        bankName: 'Krungsri',
        paymentMethod: 'Transfer',
        amount: 3100.0,
        statusOrder: OrderStatus.wreathTemple, // W
        activityStatus: OrderActivityStatus.investigating,
      ),
    ];

    notifications = [
      AppNotificationModel(
        id: 'notif-1',
        title: 'มีคน Assign งานในเคส DEV-003',
        subtitle: 'Mook มอบหมายให้คุณ',
        timeAgo: '2 ชม. ที่ผ่านมา',
        icon: Icons.person_add,
        iconColor: const Color(0xFF2563EB),
        iconBg: const Color(0xFFDBEAFE),
        isRead: false,
        module: NotificationModule.caseModule,
        referenceId: 'DEV-003',
        caseId: 'DEV-003',
        targetUserId: 'EMP-001', // Patis
        targetUserName: 'Patis',
      ),
      AppNotificationModel(
        id: 'notif-2',
        title: 'มี Comment ใหม่ในเคส DEV-002',
        subtitle: 'John: ขอข้อมูลเพิ่มเติม',
        timeAgo: '4 ชม. ที่ผ่านมา',
        icon: Icons.chat_bubble_outline,
        iconColor: const Color(0xFFDC2626),
        iconBg: const Color(0xFFFEE2E2),
        isRead: false,
        module: NotificationModule.caseModule,
        referenceId: 'DEV-002',
        caseId: 'DEV-002',
        targetUserId: 'EMP-003', // John
        targetUserName: 'John',
      ),
      AppNotificationModel(
        id: 'notif-3',
        title: 'คุณถูก Mention ในเคส DEV-001',
        subtitle: '@Patis ช่วยดูหน่อยครับ',
        timeAgo: '5 ชม. ที่ผ่านมา',
        icon: Icons.alternate_email,
        iconColor: const Color(0xFFEA580C),
        iconBg: const Color(0xFFFFEDD5),
        isRead: false,
        module: NotificationModule.caseModule,
        referenceId: 'DEV-001',
        caseId: 'DEV-001',
        targetUserId: 'EMP-001', // Patis
        targetUserName: 'Patis',
      ),
      AppNotificationModel(
        id: 'notif-4',
        title: 'เคส DEV-004 ถูกปิด',
        subtitle: 'โดย Admin',
        timeAgo: '1 วันที่ผ่านมา',
        icon: Icons.check_circle_outline,
        iconColor: const Color(0xFF16A34A),
        iconBg: const Color(0xFFDCFCE7),
        isRead: true,
        module: NotificationModule.caseModule,
        referenceId: 'DEV-004',
        caseId: 'DEV-004',
        targetUserId: 'EMP-004', // Admin
        targetUserName: 'Admin',
      ),
      AppNotificationModel(
        id: 'notif-5',
        title: 'มี Comment ใหม่ในเคส DEV-005',
        subtitle: 'Mook: แก้ไขแล้วครับ',
        timeAgo: '2 วันที่ผ่านมา',
        icon: Icons.chat_bubble_outline,
        iconColor: const Color(0xFFDC2626),
        iconBg: const Color(0xFFFEE2E2),
        isRead: true,
        module: NotificationModule.caseModule,
        referenceId: 'DEV-005',
        caseId: 'DEV-005',
        targetUserId: 'EMP-002', // Mook
        targetUserName: 'Mook',
      ),
      AppNotificationModel(
        id: 'notif-6',
        title: 'มีการเปลี่ยนแปลงสถานะในเคส DEV-003',
        subtitle: 'Patis: In Progress → Testing',
        timeAgo: '3 วันที่ผ่านมา',
        icon: Icons.swap_horiz,
        iconColor: const Color(0xFFD97706),
        iconBg: const Color(0xFFFEF3C7),
        isRead: true,
        module: NotificationModule.caseModule,
        referenceId: 'DEV-003',
        caseId: 'DEV-003',
        targetUserId: 'EMP-001', // Patis
        targetUserName: 'Patis',
      ),
      AppNotificationModel(
        id: 'notif-7',
        title: 'สร้างการ์ดออเดอร์สำเร็จ (849201)',
        subtitle: 'ประเภท: Order Card (Order Diff)',
        timeAgo: '1 วันที่ผ่านมา',
        icon: Icons.inventory_2_outlined,
        iconColor: const Color(0xFF2563EB),
        iconBg: const Color(0xFFDBEAFE),
        isRead: false,
        module: NotificationModule.orderDiff,
        referenceId: '849201',
        caseId: '849201',
        targetUserId: 'EMP-001', // Patis
        targetUserName: 'Patis',
      ),
      AppNotificationModel(
        id: 'notif-8',
        title: 'คุณได้รับมอบหมายออเดอร์ (392810)',
        subtitle: 'Bank Issue Card โดย John',
        timeAgo: '2 วันที่ผ่านมา',
        icon: Icons.account_balance_outlined,
        iconColor: const Color(0xFF9333EA),
        iconBg: const Color(0xFFF3E8FF),
        isRead: false,
        module: NotificationModule.bankIssue,
        referenceId: '392810',
        caseId: '392810',
        targetUserId: 'EMP-001', // Patis
        targetUserName: 'Patis',
      ),
    ];
  }

  // Set active tab index
  void setNavIndex(int index) {
    selectedNavIndex = index;
    notifyListeners();
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
        final matchId = o.id.toLowerCase().contains(q);
        final matchCreateBy = o.createBy.toLowerCase().contains(q);
        final matchError = o.errorDetails?.toLowerCase().contains(q) ?? false;
        final matchBank = o.bankName?.toLowerCase().contains(q) ?? false;
        final matchPayment = o.paymentMethod?.toLowerCase().contains(q) ?? false;
        if (!matchId && !matchCreateBy && !matchError && !matchBank && !matchPayment) return false;
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

      return true;
    }).toList();
  }

  // User-specific notification getters
  List<AppNotificationModel> get currentUserNotifications {
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
    return orders.where((o) => o.assignee != null && o.assignee?.id == currentUser.id).toList();
  }

  int get myOrderTotalCount => myOrders.length;
  int get myOrderDiffCount => myOrders.where((o) => o.cardType == OrderCardType.orderDiff).length;
  int get myBankIssueCount => myOrders.where((o) => o.cardType == OrderCardType.bankIssue).length;
  int get myOrderClosedCount => myOrders.where((o) => o.activityStatus == OrderActivityStatus.closed).length;

  void createOrderCard({
    required OrderCardType cardType,
    required String orderNo,
    required DeliveryType deliveryType,
    required CasePriority priority,
    UserModel? assignee,
    required String createBy,
    String? importFile,
    List<AttachmentModel> attachments = const [],
    String? errorDetails,
    String? bankCode,
    String? bankName,
    String? paymentMethodCode,
    String? paymentMethod,
    double? amount,
    OrderStatus? statusOrder,
  }) {
    final generated6Digit = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    final finalOrderNo = orderNo.trim().isNotEmpty ? orderNo.trim() : generated6Digit;

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
    return orders.indexWhere((o) => o.id == orderId || o.allItems.any((item) => item.id == orderId));
  }

  void updateOrderCard(OrderModel updatedOrder) {
    final index = _findOrderIndex(updatedOrder.id);
    if (index != -1) {
      final parentId = orders[index].id;
      orders[index] = updatedOrder.copyWith(id: parentId);
      notifyListeners();
    }
  }

  void addOrderToCard(String cardId, String orderNo, DeliveryType deliveryType) {
    final index = _findOrderIndex(cardId);
    if (index != -1) {
      final order = orders[index];
      final currentItems = List<OrderItemModel>.from(order.allItems);
      final trimmedNo = orderNo.trim();
      if (trimmedNo.isNotEmpty) {
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
  }

  void deleteOrderCard(String orderId) {
    orders.removeWhere((o) => o.id == orderId || o.allItems.any((item) => item.id == orderId));
    notifyListeners();
  }

  void updateOrderActivityStatus(String orderId, OrderActivityStatus newStatus) {
    final index = _findOrderIndex(orderId);
    if (index != -1) {
      final oldOrder = orders[index];
      if (!OrderRolePermissionHelper.canUpdateActivityStatus(currentUser, oldOrder)) {
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

  void addOrderComment(String orderId, String content) {
    final index = _findOrderIndex(orderId);
    if (index != -1) {
      final oldOrder = orders[index];
      final timeStr = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());
      final newComment = CommentModel(
        id: 'ord-c-${DateTime.now().millisecondsSinceEpoch}',
        caseId: orderId,
        author: currentUser,
        content: content,
        dateText: timeStr,
      );
      final newLog = ActivityLogModel(
        id: 'ord-act-${DateTime.now().millisecondsSinceEpoch}',
        caseId: orderId,
        title: 'เพิ่มความคิดเห็น',
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
        subtitle: '${currentUser.name}: $content',
        icon: Icons.chat_bubble_outline,
        iconColor: const Color(0xFF2563EB),
        iconBg: const Color(0xFFDBEAFE),
      );

      notifyListeners();
    }
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

  void createCase({
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
  }) {
    final nextNum = cases.length + 1;
    final id = 'DEV-${nextNum.toString().padLeft(3, '0')}';

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
      attachedImages: images ?? [],
      attachedFiles: files ?? [],
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
  }) {
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

  void updateCaseStatus(String caseId, CaseStatus newStatus) {
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

  void addComment(String caseId, String content, {String? imagePath}) {
    final index = cases.indexWhere((c) => c.id == caseId);
    if (index != -1) {
      final oldCase = cases[index];

      final newComment = CommentModel(
        id: 'c-${DateTime.now().millisecondsSinceEpoch}',
        caseId: caseId,
        author: currentUser,
        content: content,
        dateText: 'วันนี้',
        attachedImageUrl: imagePath,
      );

      final updatedComments = List<CommentModel>.from(oldCase.comments)..add(newComment);
      final updatedLogs = List<ActivityLogModel>.from(oldCase.activityLogs)..add(
        ActivityLogModel(
          id: 'act-${DateTime.now().millisecondsSinceEpoch}',
          caseId: caseId,
          title: 'เพิ่มความคิดเห็น',
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

  void toggleLikeComment(String caseId, String commentId) {
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

  void deleteCase(String caseId) {
    cases.removeWhere((c) => c.id == caseId);
    notifyListeners();
  }

  void reassignOrderCard(String orderId, UserModel? newAssignee) {
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

  void addOrderAttachment(String orderId, String fileName, String size, String fileType) {
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

  void deleteOrderAttachment(String orderId, String attachmentId) {
    final index = _findOrderIndex(orderId);
    if (index != -1) {
      final oldOrder = orders[index];
      final timeStr = DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());
      final attToRemove = oldOrder.attachments.firstWhere(
        (a) => a.id == attachmentId,
        orElse: () => const AttachmentModel(id: '', name: 'ไฟล์', size: '', dateText: '', fileType: ''),
      );

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
  }

  void reassignCase(String caseId, UserModel? newAssignee) {
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

  void changeCaseTeam(String caseId, TeamType newTeam) {
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

  void changeCasePriority(String caseId, CasePriority newPriority) {
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

  void markNotificationRead(String notifId) {
    final index = notifications.indexWhere((n) => n.id == notifId);
    if (index != -1) {
      notifications[index] = notifications[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void markAllNotificationsRead() {
    final myNotifIds = currentUserNotifications.map((n) => n.id).toSet();
    notifications = notifications.map((n) {
      if (myNotifIds.contains(n.id)) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
    notifyListeners();
  }

  void updateUserProfile({
    required String name,
    required String phoneNumber,
  }) {
    final avatarLetter = name.trim().isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : 'U';
    currentUser = currentUser.copyWith(
      name: name.trim(),
      phoneNumber: phoneNumber.trim(),
      avatarUrl: avatarLetter,
    );

    final idx = registeredUsers.indexWhere((u) => u.id == currentUser.id);
    if (idx != -1) {
      registeredUsers[idx] = currentUser;
    }

    notifyListeners();
  }

  void logout() {
    isLoggedIn = false;
    selectedNavIndex = 0; // Reset tab to Dashboard
    notifyListeners();
  }

  void login() {
    isLoggedIn = true;
    selectedNavIndex = 0; // Reset tab to Dashboard
    notifyListeners();
  }
}
