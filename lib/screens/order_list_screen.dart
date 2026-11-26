import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../widgets/order_diff_card.dart';
import '../widgets/bank_issue_card.dart';
import '../widgets/order_kanban_board.dart';
import 'create_order_card_screen.dart';
import 'order_detail_screen.dart';
import 'search_order_filter_screen.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isKanbanView = false;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _searchController.text = appState.orderSearchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final role = appState.currentUser.roleEnum;
    final canCreateOrder = OrderRolePermissionHelper.hasPermission(role, OrderPermission.createOrder);

    final rawFilteredOrders = appState.filteredOrders;
    final ordersList = appState.groupedFilteredOrders;
    final hasActiveFilters = appState.orderSearchQuery.isNotEmpty ||
        appState.filterOrderCardType != null ||
        appState.filterOrderDeliveryType != null ||
        appState.filterOrderActivityStatus != null ||
        appState.filterOrderPriority != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Order Management',
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
            tooltip: _isKanbanView ? 'สลับไปมุมมองรายการ' : 'สลับไปมุมมอง Kanban',
            onPressed: () => setState(() => _isKanbanView = !_isKanbanView),
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.primary),
            tooltip: 'ตัวกรองค้นหา',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchOrderFilterScreen()),
              );
            },
          ),
          if (hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off, color: Colors.red),
              tooltip: 'ล้างตัวกรองทั้งหมด',
              onPressed: () {
                _searchController.clear();
                appState.setOrderFilters(clearAll: true);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: Column(
              children: [
                // Search Input Field
                TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    appState.setOrderFilters(query: val);
                  },
                  decoration: InputDecoration(
                    hintText: 'ค้นหา Order No., ธนาคาร, อาการ Error...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              appState.setOrderFilters(query: '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),

                // Card Type Quick Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'ทั้งหมด (${appState.groupedOrders.length})',
                        isSelected: appState.filterOrderCardType == null,
                        onTap: () => appState.setOrderFilters(clearCardType: true),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Order Diff (${appState.groupedOrderDiffCount})',
                        isSelected: appState.filterOrderCardType == OrderCardType.orderDiff,
                        onTap: () => appState.setOrderFilters(cardType: OrderCardType.orderDiff),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Bank Issue (${appState.groupedBankIssueCount})',
                        isSelected: appState.filterOrderCardType == OrderCardType.bankIssue,
                        onTap: () => appState.setOrderFilters(cardType: OrderCardType.bankIssue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // List vs Kanban view
          Expanded(
            child: _isKanbanView
                ? OrderKanbanBoard(orders: rawFilteredOrders)
                : ordersList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('ไม่พบรายการออเดอร์ตามเงื่อนไข', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: ordersList.length,
                        itemBuilder: (context, index) {
                          final item = ordersList[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
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
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: canCreateOrder
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateOrderCardScreen()),
                );
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
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
            fontSize: 12,
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
