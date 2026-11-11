import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../screens/case_detail_screen.dart';

class KanbanBoardWidget extends StatelessWidget {
  final List<CaseModel> cases;

  const KanbanBoardWidget({
    super.key,
    required this.cases,
  });

  @override
  Widget build(BuildContext context) {
    // Group cases into 3 Kanban columns
    final openCases = cases.where((c) => c.status == CaseStatus.open || c.status == CaseStatus.assigned).toList();
    final inProgressCases = cases.where((c) => c.status == CaseStatus.inProgress || c.status == CaseStatus.pending || c.status == CaseStatus.waiting || c.status == CaseStatus.testing).toList();
    final doneCases = cases.where((c) => c.status == CaseStatus.done || c.status == CaseStatus.closed).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column 1: Open / Assigned
          _buildKanbanColumn(
            context,
            title: 'Open / Assigned',
            count: openCases.length,
            headerColor: const Color(0xFF2563EB),
            headerBgColor: const Color(0xFFEFF6FF),
            cases: openCases,
          ),
          const SizedBox(width: 12),

          // Column 2: In Progress / Testing
          _buildKanbanColumn(
            context,
            title: 'In Progress / Testing',
            count: inProgressCases.length,
            headerColor: const Color(0xFFD97706),
            headerBgColor: const Color(0xFFFEF3C7),
            cases: inProgressCases,
          ),
          const SizedBox(width: 12),

          // Column 3: Done / Closed
          _buildKanbanColumn(
            context,
            title: 'Done / Closed',
            count: doneCases.length,
            headerColor: const Color(0xFF16A34A),
            headerBgColor: const Color(0xFFDCFCE7),
            cases: doneCases,
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanColumn(
    BuildContext context, {
    required String title,
    required int count,
    required Color headerColor,
    required Color headerBgColor,
    required List<CaseModel> cases,
  }) {
    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: headerColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: headerBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: headerColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Column Cards Area
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 520),
            child: cases.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    child: const Center(
                      child: Text(
                        'ไม่มีเคสในคอลัมน์นี้',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(10),
                    itemCount: cases.length,
                    itemBuilder: (ctx, index) {
                      return _buildKanbanCard(context, cases[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanCard(BuildContext context, CaseModel caseObj) {
    final appState = Provider.of<AppState>(context, listen: false);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CaseDetailScreen(caseId: caseObj.id),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Case ID & Priority Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      caseObj.id,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    _buildPriorityBadge(caseObj.priority),
                  ],
                ),
                const SizedBox(height: 6),

                // Case Title
                Text(
                  caseObj.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Team & Category Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        caseObj.team.label,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        caseObj.category,
                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16, color: AppColors.cardBorder),

                // Bottom Row: Assignee Avatar & Quick Status Change Popup
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: caseObj.assignee != null ? AppColors.primary : Colors.grey.shade400,
                          child: Text(
                            caseObj.assignee != null ? caseObj.assignee!.avatarUrl : '?',
                            style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 110),
                          child: Text(
                            caseObj.assignee != null ? caseObj.assignee!.name : 'ยังไม่ระบุ',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Quick Status Change Popup Button
                    PopupMenuButton<CaseStatus>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.swap_horiz, size: 18, color: AppColors.textMuted),
                      tooltip: 'เปลี่ยนสถานะ',
                      onSelected: (newStatus) {
                        appState.updateCaseStatus(caseObj.id, newStatus);
                      },
                      itemBuilder: (context) {
                        return CaseStatus.values.map((st) {
                          return PopupMenuItem<CaseStatus>(
                            value: st,
                            child: Row(
                              children: [
                                Icon(
                                  st == caseObj.status ? Icons.check_circle : Icons.circle_outlined,
                                  size: 16,
                                  color: st == caseObj.status ? AppColors.primary : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(st.label, style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(CasePriority priority) {
    Color bg;
    Color text;

    switch (priority) {
      case CasePriority.critical:
        bg = const Color(0xFFFEE2E2);
        text = const Color(0xFFDC2626);
        break;
      case CasePriority.high:
        bg = const Color(0xFFFFEDD5);
        text = const Color(0xFFEA580C);
        break;
      case CasePriority.medium:
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFD97706);
        break;
      case CasePriority.low:
        bg = const Color(0xFFF1F5F9);
        text = const Color(0xFF64748B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        priority.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }
}
