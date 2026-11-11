import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../models/role_permission.dart';
import '../services/export_service.dart';
import '../services/pdf_report_service.dart';
import '../widgets/case_card.dart';

class ReportsExportScreen extends StatefulWidget {
  const ReportsExportScreen({super.key});

  @override
  State<ReportsExportScreen> createState() => _ReportsExportScreenState();
}

class _ReportsExportScreenState extends State<ReportsExportScreen> {
  late DateTimeRange _dateRange;
  CaseStatus? _selectedStatus;
  CasePriority? _selectedPriority;
  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _resetToDefaultFilters();
  }

  void _resetToDefaultFilters() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    setState(() {
      _dateRange = DateTimeRange(start: firstDay, end: lastDay);
      _selectedStatus = null;
      _selectedPriority = null;
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;

    // 1. Filter cases according to RBAC permissions first
    final userCases = appState.cases.where((c) => RolePermissionHelper.canAccessCase(user, c)).toList();

    // 2. Filter cases by Date Range, Status, and Priority
    final filteredCases = userCases.where((c) {
      // Status Filter
      if (_selectedStatus != null && c.status != _selectedStatus) {
        return false;
      }

      // Priority Filter
      if (_selectedPriority != null && c.priority != _selectedPriority) {
        return false;
      }

      return true;
    }).toList();

    // 3. Summary Counts
    final totalCases = filteredCases.length;
    final openCases = filteredCases.where((c) => c.status == CaseStatus.open || c.status == CaseStatus.assigned).length;
    final inProgressCases = filteredCases.where((c) => c.status == CaseStatus.inProgress || c.status == CaseStatus.waiting || c.status == CaseStatus.testing || c.status == CaseStatus.pending).length;
    final resolvedCases = filteredCases.where((c) => c.status == CaseStatus.done || c.status == CaseStatus.closed).length;

    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reports & Export',
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
            // Section 1: Summary Cards Grid
            _buildSectionHeader('สรุปสถิติรายงาน (Report Summary)'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Total Cases',
                    value: '$totalCases',
                    icon: Icons.assignment_outlined,
                    iconColor: const Color(0xFF2563EB),
                    iconBg: const Color(0xFFEFF6FF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Open',
                    value: '$openCases',
                    icon: Icons.error_outline,
                    iconColor: AppColors.openText,
                    iconBg: AppColors.openBg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: 'In Progress',
                    value: '$inProgressCases',
                    icon: Icons.sync,
                    iconColor: AppColors.inProgressText,
                    iconBg: AppColors.inProgressBg,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Resolved',
                    value: '$resolvedCases',
                    icon: Icons.check_circle_outline,
                    iconColor: AppColors.doneText,
                    iconBg: AppColors.doneBg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 2: Filters Card
            _buildSectionHeader('ตัวกรองรายงาน (Report Filters)'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Range Selector Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ช่วงวันที่รายงาน', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          Text('ค่าเริ่มต้น: เดือนปัจจุบัน', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: _selectDateRange,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.cardBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
                        label: Text(
                          '${dateFormat.format(_dateRange.start)} - ${dateFormat.format(_dateRange.end)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.cardBorder),

                  // Dropdowns Row (Status & Priority)
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('สถานะ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<CaseStatus?>(
                              value: _selectedStatus,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('ทุกสถานะ', style: TextStyle(fontSize: 12)),
                                ),
                                ...CaseStatus.values.map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.label, style: const TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ],
                              onChanged: (val) => setState(() => _selectedStatus = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Priority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<CasePriority?>(
                              value: _selectedPriority,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('ทุกระดับ', style: TextStyle(fontSize: 12)),
                                ),
                                ...CasePriority.values.map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p.label, style: const TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ],
                              onChanged: (val) => setState(() => _selectedPriority = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Reset Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _resetToDefaultFilters,
                      icon: const Icon(Icons.refresh, size: 16, color: AppColors.textMuted),
                      label: const Text('Reset Filters (เดือนปัจจุบัน)', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 3: Export Action Buttons
            _buildSectionHeader('ส่งออกเอกสารรายงาน (Export Actions)'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGeneratingPdf
                        ? null
                        : () async {
                            setState(() => _isGeneratingPdf = true);
                            await PdfReportService.generateAndPreviewPdf(
                              context,
                              cases: filteredCases,
                              dateRange: _dateRange,
                              selectedStatus: _selectedStatus,
                              selectedPriority: _selectedPriority,
                              userRoleLabel: user.roleEnum.label,
                            );
                            if (mounted) {
                              setState(() => _isGeneratingPdf = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isGeneratingPdf
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.white),
                    label: const Text('Export PDF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ExportService.exportCasesToCsv(context, filteredCases);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.grid_on_outlined, size: 18, color: AppColors.primary),
                    label: const Text('Export CSV', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 4: Filtered Cases Table / List View
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('รายการเคสตามตัวกรอง (${filteredCases.length})'),
                const Text('แสดงตามสิทธิ์ RBAC', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 10),
            if (filteredCases.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      'ไม่พบเคสในช่วงเวลาและเงื่อนไขที่เลือก',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
            else
              ...filteredCases.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CaseCard(item: item),
                ),
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
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
