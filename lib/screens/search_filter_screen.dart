import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';

class SearchFilterScreen extends StatefulWidget {
  const SearchFilterScreen({super.key});

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  final TextEditingController _searchController = TextEditingController();
  CaseStatus? _tempStatus;
  CasePriority? _tempPriority;
  TeamType? _tempTeam;
  String? _tempAssignee = 'ทั้งหมด';
  DateTimeRange? _tempDateRange;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _searchController.text = appState.searchQuery;
    _tempStatus = appState.filterStatus;
    _tempPriority = appState.filterPriority;
    _tempTeam = appState.filterTeam;
    _tempAssignee = appState.filterAssignee ?? 'ทั้งหมด';
    _tempDateRange = appState.filterDateRange;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearAll() {
    setState(() {
      _searchController.clear();
      _tempStatus = null;
      _tempPriority = null;
      _tempTeam = null;
      _tempAssignee = 'ทั้งหมด';
      _tempDateRange = null;
    });
    Provider.of<AppState>(context, listen: false).clearFilters();
  }

  void _applyFilter() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setFilters(
      query: _searchController.text.trim(),
      status: _tempStatus,
      priority: _tempPriority,
      team: _tempTeam,
      assignee: _tempAssignee,
      dateRange: _tempDateRange,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final assigneeNames = <String>{
      ...appState.registeredUsers.map((u) => u.name.trim()).where((n) => n.isNotEmpty),
      ...appState.cases
          .map((c) => c.assignee?.name.trim() ?? '')
          .where((n) => n.isNotEmpty),
    }.toList()
      ..sort();
    final assigneeOptions = ['ทั้งหมด', ...assigneeNames];
    final safeAssigneeValue = assigneeOptions.contains(_tempAssignee) ? _tempAssignee : 'ทั้งหมด';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ค้นหา / กรองข้อมูล',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input Field
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'ค้นหาเลขเคส, ชื่อเคส, ผู้รับผิดชอบ...',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 20),

            // Status Section
            _buildSectionHeader('Status'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip(
                  label: 'ทั้งหมด',
                  isSelected: _tempStatus == null,
                  onTap: () => setState(() => _tempStatus = null),
                ),
                ...CaseStatus.values.map(
                  (s) => _buildChoiceChip(
                    label: s.label,
                    isSelected: _tempStatus == s,
                    onTap: () => setState(() => _tempStatus = s),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Priority Section
            _buildSectionHeader('Priority'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip(
                  label: 'ทั้งหมด',
                  isSelected: _tempPriority == null,
                  onTap: () => setState(() => _tempPriority = null),
                ),
                ...CasePriority.values.map(
                  (p) => _buildChoiceChip(
                    label: p.label,
                    isSelected: _tempPriority == p,
                    color: p.color,
                    bgColor: p.backgroundColor,
                    onTap: () => setState(() => _tempPriority = p),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Team Section
            _buildSectionHeader('ทีม'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip(
                  label: 'ทั้งหมด',
                  isSelected: _tempTeam == null,
                  onTap: () => setState(() => _tempTeam = null),
                ),
                ...TeamType.values.map(
                  (t) => _buildChoiceChip(
                    label: t.label,
                    isSelected: _tempTeam == t,
                    onTap: () => setState(() => _tempTeam = t),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Assignee Section
            _buildSectionHeader('ผู้รับผิดชอบ'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: safeAssigneeValue,
                  items: assigneeOptions
                      .map((name) => DropdownMenuItem(value: name, child: Text(name)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _tempAssignee = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Date Range Section
            _buildSectionHeader('ช่วงวันที่'),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _tempDateRange = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _tempDateRange == null
                            ? 'เริ่มต้น - สิ้นสุด'
                            : '${_tempDateRange!.start.day}/${_tempDateRange!.start.month}/${_tempDateRange!.start.year} - ${_tempDateRange!.end.day}/${_tempDateRange!.end.month}/${_tempDateRange!.end.year}',
                        style: TextStyle(
                          fontSize: 13,
                          color: _tempDateRange == null ? AppColors.textMuted : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.date_range, size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Bottom Buttons Row
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _clearAll,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('รีเซ็ต'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _applyFilter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('ใช้ตัวกรอง'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? color,
    Color? bgColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (bgColor ?? AppColors.primary)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: isSelected && bgColor != null ? Border.all(color: color ?? AppColors.primary) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? (color ?? Colors.white) : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
