import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import 'edit_order_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _tabBarKey = GlobalKey();
  bool _isSticky = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _scrollToTabBar();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_tabBarKey.currentContext != null) {
      final box = _tabBarKey.currentContext!.findRenderObject() as RenderBox?;
      if (box != null) {
        final pos = box.localToGlobal(Offset.zero);
        final sticky = pos.dy <= 80;
        if (sticky != _isSticky) {
          setState(() {
            _isSticky = sticky;
          });
        }
      }
    }
  }

  void _scrollToTabBar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tabBarKey.currentContext != null) {
        final renderBox = _tabBarKey.currentContext!.findRenderObject() as RenderBox?;
        if (renderBox != null && _scrollController.hasClients) {
          try {
            final scrollableBox = _scrollController.position.context.storageContext.findRenderObject() as RenderBox?;
            if (scrollableBox != null) {
              final offset = renderBox.localToGlobal(Offset.zero, ancestor: scrollableBox).dy + _scrollController.offset;
              final targetOffset = (offset - 80).clamp(0.0, _scrollController.position.maxScrollExtent);
              _scrollController.animateTo(
                targetOffset,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          } catch (_) {
            Scrollable.ensureVisible(
              _tabBarKey.currentContext!,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: 0.0,
            );
          }
        }
      }
    });
  }

  void _sendComment(AppState appState, String orderId) {
    final text = _commentController.text.trim();
    if (text.isNotEmpty) {
      appState.addOrderComment(orderId, text);
      _commentController.clear();
    }
  }

  void _showDeleteConfirmDialog(BuildContext context, AppState appState, String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบการ์ดออเดอร์'),
        content: Text('คุณต้องการลบการ์ดออเดอร์ $orderId ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.deleteOrderCard(orderId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ลบการ์ดออเดอร์ $orderId เรียบร้อยแล้ว'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('ลบการ์ด', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showActivityStatusUpdateSheet(BuildContext context, AppState appState, OrderModel order) {
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
                        'อัปเดตสถานะ Activity',
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
                    children: OrderActivityStatus.values.map((status) {
                      final isCurrent = order.activityStatus == status;
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
                            appState.updateOrderActivityStatus(order.id, status);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('อัปเดตสถานะ Activity เป็น ${status.label} แล้ว'),
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

  void _showOrderReassignSheet(BuildContext context, AppState appState, OrderModel order) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'เปลี่ยนผู้รับผิดชอบออเดอร์',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.grey,
                child: Icon(Icons.person_off_outlined, color: Colors.white, size: 18),
              ),
              title: const Text('ยังไม่ระบุผู้รับผิดชอบ (Unassigned)'),
              trailing: order.assignee == null ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                appState.reassignOrderCard(order.id, null);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('เปลี่ยนเป็นยังไม่ระบุผู้รับผิดชอบแล้ว')),
                );
              },
            ),
            const Divider(height: 1),
            ...appState.registeredUsers.map((u) {
              final isCurrent = order.assignee?.id == u.id;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(u.avatarUrl, style: const TextStyle(color: Colors.white)),
                ),
                title: Text(u.name),
                subtitle: Text('${u.role} • ${u.email}'),
                trailing: isCurrent ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () {
                  appState.reassignOrderCard(order.id, u);
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

  void _showAddAttachmentSheet(BuildContext context, AppState appState, OrderModel order) {
    final TextEditingController fileNameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('แนบไฟล์หลักฐานใหม่', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('เลือกไฟล์ตัวอย่าง หรือระบุชื่อไฟล์:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSampleFileChip(appState, order, ctx, 'slip_payment_901.png', '1.2 MB', 'png'),
                  _buildSampleFileChip(appState, order, ctx, 'order_report_q4.xlsx', '3.1 MB', 'xlsx'),
                  _buildSampleFileChip(appState, order, ctx, 'error_stack_trace.txt', '120 KB', 'txt'),
                  _buildSampleFileChip(appState, order, ctx, 'tax_invoice.pdf', '850 KB', 'pdf'),
                ],
              ),
              const Divider(height: 24),
              TextField(
                controller: fileNameController,
                decoration: const InputDecoration(
                  hintText: 'หรือพิมพ์ชื่อไฟล์ที่ต้องการ (เช่น document.pdf)',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final name = fileNameController.text.trim();
                    if (name.isNotEmpty) {
                      final ext = name.split('.').last.toLowerCase();
                      appState.addOrderAttachment(order.id, name, '1.5 MB', ext);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('แนบไฟล์ $name สำเร็จแล้ว')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('อัปโหลดไฟล์', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSampleFileChip(AppState appState, OrderModel order, BuildContext ctx, String name, String size, String type) {
    return ActionChip(
      label: Text(name),
      avatar: const Icon(Icons.attach_file, size: 14),
      backgroundColor: const Color(0xFFF1F5F9),
      onPressed: () {
        appState.addOrderAttachment(order.id, name, size, type);
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('แนบไฟล์ $name สำเร็จแล้ว')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final order = appState.orders.firstWhere(
      (o) => o.id == widget.orderId || o.allItems.any((item) => item.id == widget.orderId),
      orElse: () => OrderModel(
        id: widget.orderId,
        cardType: OrderCardType.orderDiff,
        deliveryType: DeliveryType.express,
        priority: CasePriority.medium,
        createBy: 'Narin S.',
        dateText: '12 Oct 2025 14:32',
        errorDetails: 'Product not found\nไม่พบสินค้าตามรหัสที่ระบุ',
      ),
    );

    final isDiff = order.cardType == OrderCardType.orderDiff;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          order.cardType.label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditOrderScreen(orderObj: order)),
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
            onSelected: (key) {
              if (key == 'delete') {
                _showDeleteConfirmDialog(context, appState, order.id);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('ลบการ์ด', style: TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Card Header Section
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Order No. Label & Badges
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Order No.',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    order.cardType.label,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Order ID + Delivery Type
                        Text(
                          '${order.id} ${order.deliveryType.label}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Badges row (Activity Status under Order ID)
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (OrderRolePermissionHelper.canUpdateActivityStatus(appState.currentUser, order)) {
                                  _showActivityStatusUpdateSheet(context, appState, order);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('คุณไม่มีสิทธิ์เปลี่ยนสถานะออเดอร์นี้ (Developer เปลี่ยนได้เฉพาะออเดอร์ที่ได้รับมอบหมายเท่านั้น)'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: order.activityStatus.backgroundColor,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: order.activityStatus.color.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  order.activityStatus.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: order.activityStatus.color,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Info Row (Delivery Type | Date | Create By)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoColumn(Icons.local_shipping_outlined, 'Delivery Type', order.deliveryType.label),
                            _buildInfoColumn(Icons.calendar_today_outlined, 'Date', order.dateText),
                            _buildInfoColumn(Icons.person_outline, 'Create By', order.createBy),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Error Section (For Order Diff) or Bank Section (For Bank Issue)
                        if (isDiff) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                                    const SizedBox(width: 6),
                                    const Text('Error', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('404', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  order.errorDetails ?? 'Product not found\nไม่พบสินค้าตามรหัสที่ระบุ',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B), height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.account_balance_outlined, color: AppColors.primary, size: 18),
                                    SizedBox(width: 6),
                                    Text('Financial & Bank Issue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('ธนาคาร: ${order.displayBankName} • ช่องทาง: ${order.displayPaymentMethod}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                if (order.amount != null)
                                  Text('จำนวนเงิน: ฿${order.amount!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                if (order.statusOrder != null)
                                  Text('สถานะคำสั่งซื้อ: ${order.statusOrder!.code} - ${order.statusOrder!.label}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Assign & Priority Row
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _showOrderReassignSheet(context, appState, order),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text('Assign', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                          const SizedBox(width: 4),
                                          Icon(Icons.edit, size: 12, color: AppColors.primary.withValues(alpha: 0.8)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      const Text('Team Backend', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.person, size: 14, color: order.assignee != null ? AppColors.primary : Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            order.assignee?.name ?? 'ยังไม่ระบุ',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: order.assignee != null ? AppColors.textSecondary : AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Priority', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                  const SizedBox(height: 4),
                                  _buildPriorityBadge(order.priority),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Real Interactive Attachments Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.attach_file, size: 18, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text('ไฟล์แนบ (Attachments)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: () => _showAddAttachmentSheet(context, appState, order),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('แนบไฟล์', style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (order.attachments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text('ยังไม่มีไฟล์แนบ', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          )
                        else
                          ...order.attachments.map((att) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    att.fileType == 'xlsx' || att.fileType == 'xls'
                                        ? Icons.table_chart_outlined
                                        : att.fileType == 'pdf'
                                            ? Icons.picture_as_pdf_outlined
                                            : Icons.insert_drive_file_outlined,
                                    size: 20,
                                    color: att.fileType == 'xlsx'
                                        ? Colors.green
                                        : att.fileType == 'pdf'
                                            ? Colors.red
                                            : AppColors.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          att.name,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${att.size} • ${att.dateText}',
                                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.download, size: 18, color: AppColors.primary),
                                    tooltip: 'ดาวน์โหลด',
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('กำลังดาวน์โหลดไฟล์ ${att.name}...')),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    tooltip: 'ลบไฟล์',
                                    onPressed: () {
                                      appState.deleteOrderAttachment(order.id, att.id);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('ลบไฟล์ ${att.name} เรียบร้อยแล้ว')),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: AppColors.cardBorder),

                  // Comments & Timeline Tabs
                  Padding(
                    key: _tabBarKey,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TabBar(
                      controller: _tabController,
                      onTap: (_) => _scrollToTabBar(),
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      tabs: const [
                        Tab(text: 'Comments'),
                        Tab(text: 'Timeline'),
                      ],
                    ),
                  ),

                  // Active Tab Content
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, child) {
                      return _tabController.index == 0
                          ? Column(
                              children: [
                                order.comments.isEmpty
                                    ? const Padding(
                                        padding: EdgeInsets.all(32),
                                        child: Center(child: Text('ยังไม่มีความคิดเห็น', style: TextStyle(color: AppColors.textMuted))),
                                      )
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        padding: const EdgeInsets.all(16),
                                        itemCount: order.comments.length,
                                        itemBuilder: (context, index) {
                                          final comment = order.comments[index];
                                          return _buildCommentItem(comment);
                                        },
                                      ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    border: Border(top: BorderSide(color: AppColors.cardBorder)),
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.crop_original, color: AppColors.textMuted, size: 20),
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('เลือกรูปภาพเรียบร้อย')),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.attach_file, color: AppColors.textMuted, size: 20),
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('เลือกไฟล์เรียบร้อย')),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: TextField(
                                          controller: _commentController,
                                          decoration: const InputDecoration(
                                            hintText: 'พิมพ์ความคิดเห็น...',
                                            hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            fillColor: Color(0xFFF8FAFC),
                                          ),
                                          onSubmitted: (_) => _sendComment(appState, order.id),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.primary,
                                        child: IconButton(
                                          icon: const Icon(Icons.send, color: Colors.white, size: 18),
                                          onPressed: () => _sendComment(appState, order.id),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Padding(
                              padding: const EdgeInsets.all(16),
                              child: order.activityLogs.isEmpty
                                  ? const Center(child: Text('ไม่มีประวัติ Timeline', style: TextStyle(color: AppColors.textMuted)))
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: order.activityLogs.length,
                                      itemBuilder: (context, index) {
                                        final log = order.activityLogs[index];
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 14),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 30,
                                                height: 30,
                                                decoration: BoxDecoration(color: log.iconBgColor, shape: BoxShape.circle),
                                                child: Icon(log.icon, size: 14, color: log.iconColor),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(log.dateText, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                                    Text('${log.title} โดย ${log.authorName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_isSticky)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                elevation: 4,
                color: Colors.white,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: TabBar(
                      controller: _tabController,
                      onTap: (_) => _scrollToTabBar(),
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      tabs: const [
                        Tab(text: 'Comments'),
                        Tab(text: 'Timeline'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () => _showActivityStatusUpdateSheet(context, appState, order),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('อัปเดตสถานะ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(CasePriority priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: priority.backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 12, color: Colors.red),
          const SizedBox(width: 4),
          Text(
            priority.label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: priority.color),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(CommentModel comment) {
    final role = comment.author.role;
    Color roleBg;
    Color roleText;

    if (role.toLowerCase().contains('backend') || role.toLowerCase().contains('dev')) {
      roleBg = const Color(0xFFDBEAFE);
      roleText = const Color(0xFF1D61E7);
    } else if (role.toLowerCase().contains('lead')) {
      roleBg = const Color(0xFFFEF3C7);
      roleText = const Color(0xFFD97706);
    } else {
      roleBg = const Color(0xFFDCFCE7);
      roleText = const Color(0xFF16A34A);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            child: Text(comment.author.avatarUrl, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.author.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: roleBg, borderRadius: BorderRadius.circular(10)),
                      child: Text(role, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleText)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.content, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.3)),
                const SizedBox(height: 2),
                Text(comment.dateText, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
