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
import '../widgets/order_diff_card.dart';
import '../widgets/bank_issue_card.dart';
import 'order_detail_screen.dart';

enum ReportExportTarget {
  cases('เคส (Cases)', Icons.assignment_outlined),
  orders('ออเดอร์ (Orders)', Icons.shopping_bag_outlined),
  all('ทั้งหมด', Icons.layers_outlined);

  final String label;
  final IconData icon;
  const ReportExportTarget(this.label, this.icon);
}

class ReportsExportScreen extends StatefulWidget {
  final ReportExportTarget initialTarget;

  const ReportsExportScreen({
    super.key,
    this.initialTarget = ReportExportTarget.cases,
  });

  @override
  State<ReportsExportScreen> createState() => _ReportsExportScreenState();
}

class _ReportsExportScreenState extends State<ReportsExportScreen> {
  late ReportExportTarget _exportTarget;
  late DateTimeRange _dateRange;
  bool _filterByDate = false;

  // Case filters
  CaseStatus? _selectedStatus;

  // Order filters
  OrderCardType? _selectedOrderCardType;
  OrderActivityStatus? _selectedOrderActivityStatus;

  // Shared filter
  CasePriority? _selectedPriority;

  bool _isGeneratingPdf = false;

  @override
  void initState() {
    super.initState();
    _exportTarget = widget.initialTarget;
    _resetToDefaultFilters(useSetState: false);
  }

  void _resetToDefaultFilters({bool useSetState = true}) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);

    void apply() {
      _dateRange = DateTimeRange(start: firstDay, end: lastDay);
      _filterByDate = false;
      _selectedStatus = null;
      _selectedOrderCardType = null;
      _selectedOrderActivityStatus = null;
      _selectedPriority = null;
    }

    if (useSetState) {
      setState(apply);
    } else {
      apply();
    }
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
        _filterByDate = true;
      });
    }
  }

  bool _isWithinDateRange(String standardDateStr) {
    if (!_filterByDate) return true;
    final dt = DateTime.tryParse(standardDateStr);
    if (dt == null) return true;
    final dayOnly = DateTime(dt.year, dt.month, dt.day);
    final startOnly = DateTime(_dateRange.start.year, _dateRange.start.month, _dateRange.start.day);
    final endOnly = DateTime(_dateRange.end.year, _dateRange.end.month, _dateRange.end.day);
    return !dayOnly.isBefore(startOnly) && !dayOnly.isAfter(endOnly);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;

    // 1. Filter Cases by RBAC + active filters
    final userCases = appState.cases.where((c) => RolePermissionHelper.canAccessCase(user, c)).toList();
    final filteredCases = userCases.where((c) {
      if (!_isWithinDateRange(parseDateToStandard(c.dateText))) {
        return false;
      }
      if (_exportTarget == ReportExportTarget.cases &&
          _selectedStatus != null &&
          c.status != _selectedStatus) {
        return false;
      }
      if (_selectedPriority != null && c.priority != _selectedPriority) {
        return false;
      }
      return true;
    }).toList();

    // 2. Filter Orders by RBAC + active filters
    final userOrders = appState.orders.where((o) => OrderRolePermissionHelper.canAccessOrder(user, o)).toList();
    final filteredOrders = userOrders.where((o) {
      if (!_isWithinDateRange(o.effectiveStandardDate)) {
        return false;
      }
      if (_exportTarget == ReportExportTarget.orders &&
          _selectedOrderCardType != null &&
          o.cardType != _selectedOrderCardType) {
        return false;
      }
      if (_exportTarget == ReportExportTarget.orders &&
          _selectedOrderActivityStatus != null &&
          o.activityStatus != _selectedOrderActivityStatus) {
        return false;
      }
      if (_selectedPriority != null && o.priority != _selectedPriority) {
        return false;
      }
      return true;
    }).toList();

    final groupedOrdersPreview = AppState.groupOrdersIntoCards(filteredOrders);

    // 3. Summary Counts
    final totalCases = filteredCases.length;
    final openCases = filteredCases.where((c) => c.status == CaseStatus.open || c.status == CaseStatus.assigned).length;
    final inProgressCases = filteredCases
        .where((c) =>
            c.status == CaseStatus.inProgress ||
            c.status == CaseStatus.waiting ||
            c.status == CaseStatus.testing ||
            c.status == CaseStatus.pending)
        .length;
    final resolvedCases = filteredCases.where((c) => c.status == CaseStatus.done || c.status == CaseStatus.closed).length;

    final totalOrders = filteredOrders.length;
    final orderDiffCount = filteredOrders.where((o) => o.cardType == OrderCardType.orderDiff).length;
    final bankIssueCount = filteredOrders.where((o) => o.cardType == OrderCardType.bankIssue).length;
    final doneOrders = filteredOrders
        .where((o) => o.activityStatus == OrderActivityStatus.resolved || o.activityStatus == OrderActivityStatus.closed)
        .length;
    final bankTotalAmount = filteredOrders
        .where((o) => o.cardType == OrderCardType.bankIssue)
        .fold<double>(0.0, (sum, o) => sum + (o.amount ?? 0.0));

    final dateFormat = DateFormat('dd/MM/yyyy');
    final amountFormat = NumberFormat('#,##0.00');

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
            // Section 0: Export Data Target Selector (Cases / Orders / All)
            _buildSectionHeader('เลือกข้อมูลที่ต้องการ Export'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: ReportExportTarget.values.map((target) {
                  final isSelected = _exportTarget == target;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _exportTarget = target),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              target.icon,
                              size: 16,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                target.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Section 1: Summary Cards Grid
            _buildSectionHeader('สรุปสถิติรายงาน (Report Summary)'),
            const SizedBox(height: 10),
            if (_exportTarget == ReportExportTarget.cases) ...[
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
            ] else if (_exportTarget == ReportExportTarget.orders) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Total Orders',
                      value: '$totalOrders',
                      icon: Icons.shopping_bag_outlined,
                      iconColor: const Color(0xFF2563EB),
                      iconBg: const Color(0xFFEFF6FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Order Diff',
                      value: '$orderDiffCount',
                      icon: Icons.inventory_2_outlined,
                      iconColor: const Color(0xFF0284C7),
                      iconBg: const Color(0xFFE0F2FE),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Bank Issue',
                      value: '$bankIssueCount',
                      icon: Icons.account_balance_outlined,
                      iconColor: const Color(0xFF9333EA),
                      iconBg: const Color(0xFFF3E8FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Complete / Closed',
                      value: '$doneOrders',
                      icon: Icons.check_circle_outline,
                      iconColor: AppColors.doneText,
                      iconBg: AppColors.doneBg,
                    ),
                  ),
                ],
              ),
              if (bankIssueCount > 0) ...[
                const SizedBox(height: 10),
                _buildSummaryCard(
                  title: 'ยอดรวม Bank Issue (THB)',
                  value: '฿${amountFormat.format(bankTotalAmount)}',
                  icon: Icons.payments_outlined,
                  iconColor: const Color(0xFF16A34A),
                  iconBg: const Color(0xFFDCFCE7),
                ),
              ],
            ] else ...[
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
                      title: 'Resolved Cases',
                      value: '$resolvedCases',
                      icon: Icons.check_circle_outline,
                      iconColor: AppColors.doneText,
                      iconBg: AppColors.doneBg,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Total Orders',
                      value: '$totalOrders',
                      icon: Icons.shopping_bag_outlined,
                      iconColor: const Color(0xFF7C3AED),
                      iconBg: const Color(0xFFF3E8FF),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Orders เสร็จสิ้น',
                      value: '$doneOrders',
                      icon: Icons.task_alt,
                      iconColor: const Color(0xFF0D9488),
                      iconBg: const Color(0xFFCCFBF1),
                    ),
                  ),
                ],
              ),
            ],
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ช่วงวันที่รายงาน', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          Text(
                            _filterByDate ? 'กำลังกรองตามช่วงวันที่' : 'แสดงทุกช่วงเวลา (กดเพื่อเลือกช่วงวันที่)',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: _selectDateRange,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _filterByDate ? AppColors.primary : AppColors.cardBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
                        label: Text(
                          _filterByDate
                              ? '${dateFormat.format(_dateRange.start)} - ${dateFormat.format(_dateRange.end)}'
                              : 'ทุกช่วงเวลา',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.cardBorder),

                  // Mode-specific filter dropdowns
                  if (_exportTarget == ReportExportTarget.cases)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('สถานะเคส', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<CaseStatus?>(
                                value: _selectedStatus,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('ทุกสถานะ', style: TextStyle(fontSize: 12))),
                                  ...CaseStatus.values.map(
                                    (s) => DropdownMenuItem(value: s, child: Text(s.label, style: const TextStyle(fontSize: 12))),
                                  ),
                                ],
                                onChanged: (val) => setState(() => _selectedStatus = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: _buildPriorityDropdown()),
                      ],
                    )
                  else if (_exportTarget == ReportExportTarget.orders) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ประเภทการ์ด', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<OrderCardType?>(
                                value: _selectedOrderCardType,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('ทุกประเภท', style: TextStyle(fontSize: 12))),
                                  ...OrderCardType.values.map(
                                    (t) => DropdownMenuItem(value: t, child: Text(t.label, style: const TextStyle(fontSize: 12))),
                                  ),
                                ],
                                onChanged: (val) => setState(() => _selectedOrderCardType = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('สถานะออเดอร์', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<OrderActivityStatus?>(
                                value: _selectedOrderActivityStatus,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('ทุกสถานะ', style: TextStyle(fontSize: 12))),
                                  ...OrderActivityStatus.values.map(
                                    (s) => DropdownMenuItem(value: s, child: Text(s.label, style: const TextStyle(fontSize: 12))),
                                  ),
                                ],
                                onChanged: (val) => setState(() => _selectedOrderActivityStatus = val),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildPriorityDropdown(),
                  ] else
                    _buildPriorityDropdown(),

                  const SizedBox(height: 10),

                  // Reset Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _resetToDefaultFilters,
                      icon: const Icon(Icons.refresh, size: 16, color: AppColors.textMuted),
                      label: const Text('ล้างตัวกรองทั้งหมด', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 3: Export Action Buttons
            _buildSectionHeader('ส่งออกเอกสารรายงาน (${_exportTarget.label})'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGeneratingPdf
                        ? null
                        : () async {
                            setState(() => _isGeneratingPdf = true);
                            if (_exportTarget == ReportExportTarget.cases) {
                              await PdfReportService.generateAndPreviewPdf(
                                context,
                                cases: filteredCases,
                                dateRange: _dateRange,
                                selectedStatus: _selectedStatus,
                                selectedPriority: _selectedPriority,
                                userRoleLabel: user.roleEnum.label,
                                filterByDate: _filterByDate,
                              );
                            } else if (_exportTarget == ReportExportTarget.orders) {
                              await PdfReportService.generateOrdersPdf(
                                context,
                                orders: filteredOrders,
                                dateRange: _dateRange,
                                selectedCardType: _selectedOrderCardType,
                                selectedActivityStatus: _selectedOrderActivityStatus,
                                selectedPriority: _selectedPriority,
                                userRoleLabel: user.roleEnum.label,
                                filterByDate: _filterByDate,
                              );
                            } else {
                              await PdfReportService.generateCombinedPdf(
                                context,
                                cases: filteredCases,
                                orders: filteredOrders,
                                dateRange: _dateRange,
                                selectedPriority: _selectedPriority,
                                userRoleLabel: user.roleEnum.label,
                                filterByDate: _filterByDate,
                              );
                            }
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
                      if (_exportTarget == ReportExportTarget.cases) {
                        ExportService.exportCasesToCsv(context, filteredCases);
                      } else if (_exportTarget == ReportExportTarget.orders) {
                        ExportService.exportOrdersToCsv(context, filteredOrders);
                      } else {
                        ExportService.exportCombinedToCsv(
                          context,
                          cases: filteredCases,
                          orders: filteredOrders,
                        );
                      }
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

            // Section 4: Filtered Preview List
            if (_exportTarget == ReportExportTarget.cases || _exportTarget == ReportExportTarget.all) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('รายการเคสตามตัวกรอง (${filteredCases.length})'),
                  const Text('แสดงตามสิทธิ์ RBAC', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 10),
              if (filteredCases.isEmpty)
                _buildEmptyBox('ไม่พบเคสในช่วงเวลาและเงื่อนไขที่เลือก')
              else
                ...filteredCases.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: CaseCard(item: item),
                  ),
                ),
              if (_exportTarget == ReportExportTarget.all) const SizedBox(height: 16),
            ],

            if (_exportTarget == ReportExportTarget.orders || _exportTarget == ReportExportTarget.all) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader('รายการออเดอร์ตามตัวกรอง (${filteredOrders.length})'),
                  const Text('แสดงตามสิทธิ์ RBAC', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 10),
              if (groupedOrdersPreview.isEmpty)
                _buildEmptyBox('ไม่พบออเดอร์ในช่วงเวลาและเงื่อนไขที่เลือก')
              else
                ...groupedOrdersPreview.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: item.cardType == OrderCardType.orderDiff
                        ? OrderDiffCard(
                            item: item,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: item.id)),
                            ),
                          )
                        : BankIssueCard(
                            item: item,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: item.id)),
                            ),
                          ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityDropdown() {
    return Column(
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
            const DropdownMenuItem(value: null, child: Text('ทุกระดับ', style: TextStyle(fontSize: 12))),
            ...CasePriority.values.map(
              (p) => DropdownMenuItem(value: p, child: Text(p.label, style: const TextStyle(fontSize: 12))),
            ),
          ],
          onChanged: (val) => setState(() => _selectedPriority = val),
        ),
      ],
    );
  }

  Widget _buildEmptyBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 42, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
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
