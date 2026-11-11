import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../models/role_permission.dart';
import '../providers/app_state.dart';
import '../widgets/status_badge.dart';
import '../widgets/priority_badge.dart';
import '../screens/case_detail_screen.dart';
import '../screens/edit_case_screen.dart';

class CaseCard extends StatelessWidget {
  final CaseModel item;
  final VoidCallback? onTap;

  const CaseCard({
    super.key,
    required this.item,
    this.onTap,
  });

  void _handleOverflowSelection(BuildContext context, AppState appState, String key) {
    switch (key) {
      case 'detail':
      case 'history':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CaseDetailScreen(caseId: item.id),
          ),
        );
        break;

      case 'comment':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CaseDetailScreen(caseId: item.id),
          ),
        );
        break;

      case 'copy_id':
        Clipboard.setData(ClipboardData(text: item.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('คัดลอกรหัสเคส ${item.id} แล้ว'),
            backgroundColor: Colors.blue,
          ),
        );
        break;

      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EditCaseScreen(caseObj: item),
          ),
        );
        break;

      case 'attachments':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('จัดการไฟล์แนบของเคส ${item.id}'),
          ),
        );
        break;

      case 'status':
        _showStatusSheet(context, appState);
        break;

      case 'assignee':
        _showReassignSheet(context, appState);
        break;

      case 'team':
        _showChangeTeamSheet(context, appState);
        break;

      case 'priority':
        _showChangePrioritySheet(context, appState);
        break;

      case 'close':
        appState.updateCaseStatus(item.id, CaseStatus.closed);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ปิดเคสเรียบร้อยแล้ว'),
            backgroundColor: Colors.red,
          ),
        );
        break;

      case 'reopen':
        appState.updateCaseStatus(item.id, CaseStatus.open);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เปิดเคสใหม่อีกครั้งแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
        break;

      case 'delete':
        _showDeleteConfirmDialog(context, appState);
        break;
    }
  }

  void _showStatusSheet(BuildContext context, AppState appState) {
    final allowedStatuses = RolePermissionHelper.getAllowedStatuses(appState.currentUser.roleEnum, item.status);
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
              'เปลี่ยนสถานะเคส',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allowedStatuses.map((status) {
                final isCurrent = item.status == status;
                return ChoiceChip(
                  showCheckmark: false,
                  label: Text(status.label),
                  selected: isCurrent,
                  onSelected: (selected) {
                    if (selected) {
                      appState.updateCaseStatus(item.id, status);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('อัปเดตสถานะเป็น ${status.label} แล้ว')),
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

  void _showReassignSheet(BuildContext context, AppState appState) {
    final teamMembers = appState.registeredUsers.where((u) => u.team == item.team).toList();

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
              'เปลี่ยนผู้รับผิดชอบ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(Icons.person_off_outlined, color: Colors.white, size: 18),
              ),
              title: const Text('ยังไม่ระบุผู้รับผิดชอบ (Unassigned)'),
              trailing: item.assignee == null ? const Icon(Icons.check, color: Colors.blue) : null,
              onTap: () {
                appState.reassignCase(item.id, null);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('เปลี่ยนเป็นยังไม่ระบุผู้รับผิดชอบแล้ว')),
                );
              },
            ),
            const Divider(height: 1),
            ...teamMembers.map((u) {
              final isCurrent = item.assignee?.id == u.id;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF1D61E7),
                  child: Text(u.avatarUrl, style: const TextStyle(color: Colors.white)),
                ),
                title: Text(u.name),
                subtitle: Text('${u.role} • ${u.email}'),
                trailing: isCurrent ? const Icon(Icons.check, color: Colors.blue) : null,
                onTap: () {
                  appState.reassignCase(item.id, u);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('มอบหมายงานให้ ${u.name} แล้ว')),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showChangeTeamSheet(BuildContext context, AppState appState) {
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
                final isCurrent = item.team == t;
                return ChoiceChip(
                  label: Text(t.label),
                  selected: isCurrent,
                  onSelected: (selected) {
                    if (selected) {
                      appState.changeCaseTeam(item.id, t);
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

  void _showChangePrioritySheet(BuildContext context, AppState appState) {
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
                final isCurrent = item.priority == p;
                return ChoiceChip(
                  label: Text(p.label),
                  selected: isCurrent,
                  onSelected: (selected) {
                    if (selected) {
                      appState.changeCasePriority(item.id, p);
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

  void _showDeleteConfirmDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบเคส'),
        content: Text('คุณต้องการลบเคส ${item.id} ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.deleteCase(item.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ลบเคส ${item.id} เรียบร้อยแล้ว'),
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
    final overflowItems = RolePermissionHelper.getOverflowMenuItems(appState.currentUser, item);

    return InkWell(
      onTap: onTap ??
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CaseDetailScreen(caseId: item.id),
              ),
            );
          },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: ID, Priority, Overflow Menu
            Row(
              children: [
                Text(
                  item.id,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 8),
                PriorityBadge(priority: item.priority),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF64748B)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (key) => _handleOverflowSelection(context, appState, key),
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
              ],
            ),
            const SizedBox(height: 6),
            // Title
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Subtitle / Team & Category
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: item.team.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${item.team.label} • ${item.category}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Footer: Status Badge, Assignee Avatar, Date
            Row(
              children: [
                StatusBadge(status: item.status),
                const Spacer(),
                // Assignee Avatar
                CircleAvatar(
                  radius: 10,
                  backgroundColor: item.assignee != null ? const Color(0xFF1D61E7) : Colors.grey.shade400,
                  child: item.assignee != null
                      ? Text(
                          item.assignee!.avatarUrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : const Icon(Icons.person_outline, color: Colors.white, size: 12),
                ),
                const SizedBox(width: 5),
                Text(
                  item.assignee != null ? item.assignee!.name : 'ยังไม่ระบุผู้รับผิดชอบ',
                  style: TextStyle(
                    fontSize: 12,
                    color: item.assignee != null ? const Color(0xFF475569) : Colors.grey.shade600,
                    fontStyle: item.assignee == null ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  item.dateText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
