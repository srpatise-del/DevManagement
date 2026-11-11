import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../models/role_permission.dart';
import '../widgets/status_badge.dart';
import '../widgets/priority_badge.dart';
import 'comment_screen.dart';
import 'activity_log_screen.dart';
import 'edit_case_screen.dart';

class CaseDetailScreen extends StatefulWidget {
  final String caseId;

  const CaseDetailScreen({super.key, required this.caseId});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleOverflowSelection(BuildContext context, AppState appState, CaseModel caseObj, String key) {
    switch (key) {
      case 'detail':
      case 'history':
        _tabController.animateTo(2); // Switch to Activity Log tab
        break;

      case 'comment':
        _tabController.animateTo(1); // Switch to Comments tab
        break;

      case 'copy_id':
        Clipboard.setData(ClipboardData(text: caseObj.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('คัดลอกรหัสเคส ${caseObj.id} แล้ว'),
            backgroundColor: Colors.blue,
          ),
        );
        break;

      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditCaseScreen(caseObj: caseObj),
          ),
        );
        break;

      case 'attachments':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('จัดการไฟล์แนบของเคส ${caseObj.id}'),
          ),
        );
        break;

      case 'status':
        _showStatusUpdateSheet(context, caseObj);
        break;

      case 'assignee':
        _showReassignSheet(context, appState, caseObj);
        break;

      case 'team':
        _showChangeTeamSheet(context, appState, caseObj);
        break;

      case 'priority':
        _showChangePrioritySheet(context, appState, caseObj);
        break;

      case 'close':
        appState.updateCaseStatus(caseObj.id, CaseStatus.closed);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ปิดเคสเรียบร้อยแล้ว'),
            backgroundColor: Colors.red,
          ),
        );
        break;

      case 'reopen':
        appState.updateCaseStatus(caseObj.id, CaseStatus.open);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เปิดเคสใหม่อีกครั้งแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
        break;

      case 'delete':
        _showDeleteConfirmDialog(context, appState, caseObj);
        break;
    }
  }

  void _showStatusUpdateSheet(BuildContext context, CaseModel caseObj) {
    final appState = Provider.of<AppState>(context, listen: false);
    final allowedStatuses = RolePermissionHelper.getAllowedStatuses(appState.currentUser.roleEnum, caseObj.status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final screenHeight = MediaQuery.of(context).size.height;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'อัปเดตสถานะเคส',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: allowedStatuses.map((status) {
                      final isCurrent = caseObj.status == status;
                      return ChoiceChip(
                        showCheckmark: false,
                        label: Text(status.label),
                        selected: isCurrent,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isCurrent ? Colors.white : AppColors.textPrimary,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            appState.updateCaseStatus(caseObj.id, status);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('อัปเดตสถานะเป็น ${status.label} แล้ว'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReassignSheet(BuildContext context, AppState appState, CaseModel caseObj) {
    UserModel? selectedAssignee = caseObj.assignee;
    String searchQuery = '';
    final teamMembers = appState.registeredUsers.where((u) => u.team == caseObj.team).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final screenHeight = MediaQuery.of(context).size.height;
            final filteredUsers = teamMembers.where((u) {
              if (searchQuery.trim().isEmpty) return true;
              return u.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                  u.role.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return Container(
              constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'เปลี่ยนผู้รับผิดชอบ',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: TextField(
                      onChanged: (val) {
                        setStateModal(() {
                          searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'ค้นหาชื่อผู้ใช้งาน...',
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.cardBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.cardBorder),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Scrollable List Area
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Unassigned Option
                        ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          leading: const CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: Icon(Icons.person_off_outlined, color: Colors.white, size: 18),
                          ),
                          title: const Text('ยังไม่ระบุผู้รับผิดชอบ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text('Unassigned', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          trailing: selectedAssignee == null ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                          onTap: () {
                            setStateModal(() {
                              selectedAssignee = null;
                            });
                          },
                        ),
                        const Divider(height: 16),

                        // Users List
                        if (filteredUsers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text('ไม่พบผู้ใช้งาน', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                            ),
                          )
                        else
                          ...filteredUsers.map((u) {
                            final isSelected = selectedAssignee?.id == u.id;
                            return ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Text(u.avatarUrl, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(u.role, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                              onTap: () {
                                setStateModal(() {
                                  selectedAssignee = u;
                                });
                              },
                            );
                          }),
                      ],
                    ),
                  ),

                  // Pinned Bottom Confirmation Button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.cardBorder)),
                    ),
                    child: SafeArea(
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            appState.reassignCase(caseObj.id, selectedAssignee);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(selectedAssignee != null ? 'มอบหมายงานให้ ${selectedAssignee!.name} แล้ว' : 'เปลี่ยนเป็นยังไม่ระบุผู้รับผิดชอบแล้ว'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'ยืนยันผู้รับผิดชอบ',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showChangeTeamSheet(BuildContext context, AppState appState, CaseModel caseObj) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'เปลี่ยนทีม',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TeamType.values.map((t) {
                final isCurrent = caseObj.team == t;
                return ChoiceChip(
                  label: Text(t.label),
                  selected: isCurrent,
                  onSelected: (selected) {
                    if (selected) {
                      appState.changeCaseTeam(caseObj.id, t);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('เปลี่ยนทีมเป็น ${t.label} แล้ว')),
                      );
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePrioritySheet(BuildContext context, AppState appState, CaseModel caseObj) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'เปลี่ยน Priority',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CasePriority.values.map((p) {
                final isCurrent = caseObj.priority == p;
                return ChoiceChip(
                  label: Text(p.label),
                  selected: isCurrent,
                  onSelected: (selected) {
                    if (selected) {
                      appState.changeCasePriority(caseObj.id, p);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('เปลี่ยน Priority เป็น ${p.label} แล้ว')),
                      );
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, AppState appState, CaseModel caseObj) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบเคส'),
        content: Text('คุณต้องการลบเคส ${caseObj.id} ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.deleteCase(caseObj.id);
              Navigator.pop(context); // Close detail screen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ลบเคส ${caseObj.id} เรียบร้อยแล้ว'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('ลบเคส', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final caseObj = appState.cases.firstWhere(
      (c) => c.id == widget.caseId,
      orElse: () => appState.cases.first,
    );

    final canChangeStatus = RolePermissionHelper.hasPermission(appState.currentUser.roleEnum, Permission.changeStatus);
    final overflowItems = RolePermissionHelper.getOverflowMenuItems(appState.currentUser, caseObj);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          caseObj.id,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditCaseScreen(caseObj: caseObj),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEFF6FF),
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                label: const Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            onSelected: (key) => _handleOverflowSelection(context, appState, caseObj, key),
            itemBuilder: (context) => overflowItems.map((m) {
              return PopupMenuItem<String>(
                value: m.key,
                child: Row(
                  children: [
                    Icon(m.icon, size: 16, color: m.iconColor ?? Colors.grey.shade700),
                    const SizedBox(width: 8),
                    Text(
                      m.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: m.iconColor ?? const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Header Card
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caseObj.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // Badges row
                Row(
                  children: [
                    PriorityBadge(priority: caseObj.priority),
                    const SizedBox(width: 8),
                    StatusBadge(status: caseObj.status),
                  ],
                ),
                const SizedBox(height: 14),

                // Info Cards Grid Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.group_outlined, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ทีม', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                Text(
                                  caseObj.team.label,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: caseObj.assignee != null ? AppColors.primary : Colors.grey.shade400,
                              child: caseObj.assignee != null
                                  ? Text(
                                      caseObj.assignee!.avatarUrl,
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    )
                                  : const Icon(Icons.person_outline, color: Colors.white, size: 14),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('ผู้รับผิดชอบ', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                Text(
                                  caseObj.assignee != null ? caseObj.assignee!.name : 'ยังไม่ระบุผู้รับผิดชอบ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: caseObj.assignee != null ? AppColors.textPrimary : Colors.grey.shade600,
                                    fontStyle: caseObj.assignee == null ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Tab Bar
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: [
                    const Tab(text: 'รายละเอียด'),
                    Tab(text: 'ความคิดเห็น (${caseObj.comments.length})'),
                    const Tab(text: 'Activity Log'),
                  ],
                ),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Details View
                _buildDetailsTab(caseObj),
                // Tab 2: Comments View
                CommentTabWidget(caseId: caseObj.id),
                // Tab 3: Activity Log View
                ActivityLogTabWidget(caseId: caseObj.id),
              ],
            ),
          ),

          // Bottom Action Button
          if (canChangeStatus)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.cardBorder)),
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showStatusUpdateSheet(context, caseObj),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'อัปเดตสถานะ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(CaseModel caseObj) {
    final isMobileApp = caseObj.systemAffected.toLowerCase().contains('mobile') ||
        caseObj.team == TeamType.mobile ||
        caseObj.url.toLowerCase().contains('app ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Card Container
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: [
                _buildDetailRow('ระบบที่มีปัญหา', caseObj.systemAffected),
                const Divider(height: 20),
                _buildDetailRow('Environment', caseObj.environment),
                const Divider(height: 20),
                if (isMobileApp) ...[
                  _buildDetailRow('เวอร์ชันแอป', caseObj.url),
                  const Divider(height: 20),
                  _buildDetailRow('อุปกรณ์ & OS', caseObj.browser),
                ] else ...[
                  _buildDetailRow('URL', caseObj.url, isLink: caseObj.url.startsWith('http')),
                  const Divider(height: 20),
                  _buildDetailRow('Browser / Device', caseObj.browser),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Attached Images Section
          const Text(
            'รูปภาพแนบ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMockImageThumb('Dashboard Error 1'),
              const SizedBox(width: 8),
              _buildMockImageThumb('Console Log'),
              const SizedBox(width: 8),
              _buildMockImageThumbOverlay('+2'),
            ],
          ),
          const SizedBox(height: 20),

          // Attached Files Section
          const Text(
            'ไฟล์แนบ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          if (caseObj.attachedFiles.isEmpty)
            _buildFileCard('error_screenshot.png', '2.4 MB')
          else
            ...caseObj.attachedFiles.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildFileCard(f.fileName, f.fileSize),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isLink = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isLink ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMockImageThumb(String label) {
    return Expanded(
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(8),
          image: const DecorationImage(
            image: NetworkImage('https://picsum.photos/200'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildMockImageThumbOverlay(String label) {
    return Expanded(
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileCard(String name, String size) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.insert_drive_file, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  size,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('กำลังดาวน์โหลดไฟล์ $name...')),
              );
            },
          ),
        ],
      ),
    );
  }
}
