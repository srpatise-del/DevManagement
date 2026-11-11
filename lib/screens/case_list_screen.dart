import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../services/export_service.dart';
import '../widgets/case_card.dart';
import '../widgets/kanban_board_widget.dart';
import 'create_case_screen.dart';
import 'search_filter_screen.dart';

class CaseListScreen extends StatefulWidget {
  const CaseListScreen({super.key});

  @override
  State<CaseListScreen> createState() => _CaseListScreenState();
}

class _CaseListScreenState extends State<CaseListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isKanbanView = false;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _searchController.text = appState.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final casesList = appState.filteredCases;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Case Management',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isKanbanView ? Icons.view_list_rounded : Icons.view_kanban_outlined,
              color: AppColors.primary,
            ),
            tooltip: _isKanbanView ? 'สลับไปมุมมองรายการ (List View)' : 'สลับไปมุมมองคันบังบอร์ด (Kanban Board)',
            onPressed: () {
              setState(() {
                _isKanbanView = !_isKanbanView;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_for_offline_outlined, color: AppColors.primary),
            tooltip: 'ส่งออกไฟล์ CSV (Excel)',
            onPressed: () {
              ExportService.exportCasesToCsv(context, casesList);
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.primary),
            tooltip: 'ตัวกรองค้นหา',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SearchFilterScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar & Filter Header Area
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Column(
              children: [
                // Search Input Field
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    appState.setFilters(query: val);
                  },
                  decoration: InputDecoration(
                    hintText: 'ค้นหาเลขเคส, ชื่อเคส, ผู้รับผิดชอบ...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              appState.setFilters(query: '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 12),

                // Status Quick Filter Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'ทั้งหมด',
                        isSelected: appState.filterStatus == null,
                        onTap: () => appState.setFilters(status: null),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Open',
                        isSelected: appState.filterStatus == CaseStatus.open,
                        onTap: () => appState.setFilters(status: CaseStatus.open),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Assigned',
                        isSelected: appState.filterStatus == CaseStatus.assigned,
                        onTap: () => appState.setFilters(status: CaseStatus.assigned),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'In Progress',
                        isSelected: appState.filterStatus == CaseStatus.inProgress,
                        onTap: () => appState.setFilters(status: CaseStatus.inProgress),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Dropdowns row (Team & Priority)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<TeamType?>(
                            isExpanded: true,
                            value: appState.filterTeam,
                            hint: const Text('ทีมทั้งหมด', style: TextStyle(fontSize: 12)),
                            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('ทีมทั้งหมด', style: TextStyle(fontSize: 12)),
                              ),
                              ...TeamType.values.map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t.label, style: const TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                            onChanged: (val) => appState.setFilters(team: val),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<CasePriority?>(
                            isExpanded: true,
                            value: appState.filterPriority,
                            hint: const Text('Priority ทั้งหมด', style: TextStyle(fontSize: 12)),
                            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Priority ทั้งหมด', style: TextStyle(fontSize: 12)),
                              ),
                              ...CasePriority.values.map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p.label, style: const TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                            onChanged: (val) => appState.setFilters(priority: val),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Cases View Mode (List View vs Kanban Board View)
          Expanded(
            child: _isKanbanView
                ? KanbanBoardWidget(cases: casesList)
                : casesList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'ไม่พบเคสที่ค้นหา',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: casesList.length,
                        itemBuilder: (context, index) {
                          final item = casesList[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: CaseCard(item: item),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateCaseScreen(),
            ),
          );
        },
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
