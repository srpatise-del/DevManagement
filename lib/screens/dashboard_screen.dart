import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/donut_chart.dart';
import '../widgets/bar_chart.dart';
import '../widgets/case_card.dart';
import '../widgets/order_diff_card.dart';
import '../widgets/bank_issue_card.dart';
import '../models/app_models.dart';
import 'reports_export_screen.dart';
import 'order_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Mode selection: 'orders' or 'cases'
  String _selectedViewMode = 'orders';

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final isOrderMode = _selectedViewMode == 'orders';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'DevCase',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          // Notification Bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none, color: AppColors.textPrimary, size: 26),
                onPressed: () {
                  appState.setNavIndex(3); // Go to Notifications tab
                },
              ),
              if (appState.unreadNotificationCount > 0)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${appState.unreadNotificationCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // User Avatar
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 4),
            child: InkWell(
              onTap: () {
                appState.setNavIndex(4); // Go to Profile tab
              },
              borderRadius: BorderRadius.circular(18),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Text(
                  user.avatarUrl,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Header & Top-Right View Switcher (Orders vs Cases)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'สวัสดี, ${user.name}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('👋', style: TextStyle(fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.role,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                // Top-Right Selector Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedViewMode,
                      isDense: true,
                      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary, size: 20),
                      items: const [
                        DropdownMenuItem(
                          value: 'orders',
                          child: Row(
                            children: [
                              Icon(Icons.shopping_bag_outlined, size: 16, color: AppColors.primary),
                              SizedBox(width: 6),
                              Text(
                                'ออเดอร์',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'cases',
                          child: Row(
                            children: [
                              Icon(Icons.assignment_outlined, size: 16, color: AppColors.primary),
                              SizedBox(width: 6),
                              Text(
                                'เคส',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedViewMode = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content Area based on Selection
            if (isOrderMode) ...[
              // Order Stat Summary Cards (2x2 Grid)
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'All Order',
                      count: appState.orderTotalCount,
                      badgeColor: const Color(0xFFFEF3C7),
                      textColor: const Color(0xFFD97706),
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Closed',
                      count: appState.orderClosedCount,
                      badgeColor: AppColors.closedBg,
                      textColor: AppColors.closedText,
                      icon: Icons.cancel_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Order Diff',
                      count: appState.orderDiffCount,
                      badgeColor: const Color(0xFFDBEAFE),
                      textColor: const Color(0xFF2563EB),
                      icon: Icons.error_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Bank Issue',
                      count: appState.bankIssueCount,
                      badgeColor: const Color(0xFFF3E8FF),
                      textColor: const Color(0xFF9333EA),
                      icon: Icons.account_balance_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Recent Orders Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ออเดอร์ล่าสุด',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const OrderListScreen()),
                      );
                    },
                    child: const Text(
                      'ดูทั้งหมด',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ...appState.orders.take(4).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: item.cardType == OrderCardType.orderDiff
                      ? OrderDiffCard(item: item)
                      : BankIssueCard(item: item),
                ),
              ),
            ] else ...[
              // Original Cases Dashboard View
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Open',
                      count: appState.openCount,
                      badgeColor: AppColors.openBg,
                      textColor: AppColors.openText,
                      icon: Icons.error_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      title: 'In Progress',
                      count: appState.inProgressCount,
                      badgeColor: AppColors.inProgressBg,
                      textColor: AppColors.inProgressText,
                      icon: Icons.sync,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Done วันนี้',
                      count: appState.doneCount,
                      badgeColor: AppColors.doneBg,
                      textColor: AppColors.doneText,
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Closed',
                      count: appState.closedCount,
                      badgeColor: AppColors.closedBg,
                      textColor: AppColors.closedText,
                      icon: Icons.cancel_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Team Donut Chart
              DonutChartWidget(
                data: [
                  TeamChartData('Web Team', appState.teamWebCount, AppColors.teamWeb),
                  TeamChartData('Mobile Team', appState.teamMobileCount, AppColors.teamMobile),
                  TeamChartData('Backend Team', appState.teamBackendCount, AppColors.teamBackend),
                  TeamChartData('Infra', appState.teamInfraCount, AppColors.teamInfra),
                ],
              ),
              const SizedBox(height: 20),
              // Priority Bar Chart
              PriorityBarChartWidget(
                data: [
                  PriorityBarData(CasePriority.high, appState.priorityHighCount),
                  PriorityBarData(CasePriority.medium, appState.priorityMediumCount),
                  PriorityBarData(CasePriority.low, appState.priorityLowCount),
                  PriorityBarData(CasePriority.critical, appState.priorityCriticalCount),
                ],
              ),
              const SizedBox(height: 20),

              // Reports & Export Entry Card
              _buildReportsExportCard(context),
              const SizedBox(height: 20),

              // Recent Cases Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'เคสล่าสุด',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      appState.setNavIndex(1); // Go to Case List tab
                    },
                    child: const Text(
                      'ดูทั้งหมด',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Recent Cases List
              ...appState.cases.take(3).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CaseCard(item: item),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required Color badgeColor,
    required Color textColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: textColor),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsExportCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ReportsExportScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.bar_chart_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reports & Export',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'สรุปและส่งออกรายงานเคส',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
