import 'package:flutter/material.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import 'order_diff_card.dart';
import 'bank_issue_card.dart';
import '../screens/order_detail_screen.dart';

class OrderKanbanBoard extends StatelessWidget {
  final List<OrderModel> orders;

  const OrderKanbanBoard({
    super.key,
    required this.orders,
  });

  @override
  Widget build(BuildContext context) {
    final orderDiffs = orders.where((o) => o.cardType == OrderCardType.orderDiff).toList();
    final bankPending = orders.where((o) => o.cardType == OrderCardType.bankIssue && o.statusOrder != OrderStatus.completed).toList();
    final bankCompleted = orders.where((o) => o.cardType == OrderCardType.bankIssue && o.statusOrder == OrderStatus.completed).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildColumn(context, title: 'Order Diff Cards', count: orderDiffs.length, color: Colors.blue, items: orderDiffs),
          const SizedBox(width: 12),
          _buildColumn(context, title: 'Bank Issue (Pending/Wait)', count: bankPending.length, color: Colors.amber.shade800, items: bankPending),
          const SizedBox(width: 12),
          _buildColumn(context, title: 'Bank Issue (Completed)', count: bankCompleted.length, color: Colors.green, items: bankCompleted),
        ],
      ),
    );
  }

  Widget _buildColumn(
    BuildContext context, {
    required String title,
    required int count,
    required Color color,
    required List<OrderModel> items,
  }) {
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 500),
            child: items.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('ไม่มีรายการออเดอร์', style: TextStyle(fontSize: 12, color: AppColors.textMuted))),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(10),
                    itemCount: items.length,
                    itemBuilder: (ctx, index) {
                      final item = items[index];
                      return Padding(
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
