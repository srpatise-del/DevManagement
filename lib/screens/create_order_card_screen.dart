import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';

class CreateOrderCardScreen extends StatefulWidget {
  const CreateOrderCardScreen({super.key});

  @override
  State<CreateOrderCardScreen> createState() => _CreateOrderCardScreenState();
}

class _CreateOrderCardScreenState extends State<CreateOrderCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _orderNoController = TextEditingController();
  final _errorDetailsController = TextEditingController();
  final _customBankNameController = TextEditingController();
  final _amountController = TextEditingController();

  String _selectedBankCode = 'SCB';
  String _selectedPaymentMethodCode = 'QR_PROMPTPAY';
  final _customPaymentMethodController = TextEditingController();
  final List<AttachmentModel> _attachedFiles = [];

  OrderCardType _cardType = OrderCardType.orderDiff;
  DeliveryType _deliveryType = DeliveryType.express;
  CasePriority _priority = CasePriority.medium;
  OrderStatus _statusOrder = OrderStatus.pending;
  UserModel? _assignee;

  @override
  void dispose() {
    _orderNoController.dispose();
    _errorDetailsController.dispose();
    _customBankNameController.dispose();
    _customPaymentMethodController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _showBankSelectionDialog() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final filteredBanks = kBankList.where((b) =>
              b.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
              b.code.toLowerCase().contains(searchQuery.toLowerCase())
            ).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('เลือกธนาคาร (Select Bank)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'ค้นหาธนาคาร (ชื่อหรือรหัส)...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredBanks.length,
                      itemBuilder: (context, index) {
                        final bank = filteredBanks[index];
                        final isSelected = _selectedBankCode == bank.code;
                        return ListTile(
                          title: Text(
                            bank.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(bank.code, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                          onTap: () {
                            setState(() {
                              _selectedBankCode = bank.code;
                              if (bank.code != 'OTHER') {
                                _customBankNameController.clear();
                              }
                            });
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddFileDialog() {
    final fileNameController = TextEditingController();
    final fileSizeController = TextEditingController(text: '1.2 MB');

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
                  const Text('แนบไฟล์เอกสาร / หลักฐาน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('เลือกไฟล์ตัวอย่างด่วน:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPresetChip('slip_transfer.png', '1.2 MB', 'png', ctx),
                  _buildPresetChip('order_report.xlsx', '3.1 MB', 'xlsx', ctx),
                  _buildPresetChip('error_log.txt', '120 KB', 'txt', ctx),
                  _buildPresetChip('tax_invoice.pdf', '850 KB', 'pdf', ctx),
                ],
              ),
              const Divider(height: 24),
              TextField(
                controller: fileNameController,
                decoration: const InputDecoration(hintText: 'ชื่อไฟล์ (เช่น document.pdf)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fileSizeController,
                decoration: const InputDecoration(hintText: 'ขนาดไฟล์ (เช่น 1.5 MB)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final name = fileNameController.text.trim();
                    final size = fileSizeController.text.trim().isNotEmpty ? fileSizeController.text.trim() : '1.0 MB';
                    if (name.isNotEmpty) {
                      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : 'xlsx';
                      setState(() {
                        _attachedFiles.add(AttachmentModel(
                          id: 'att-${DateTime.now().millisecondsSinceEpoch}',
                          name: name,
                          size: size,
                          dateText: 'วันนี้',
                          fileType: ext,
                        ));
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('เพิ่มไฟล์แนบ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPresetChip(String name, String size, String type, BuildContext ctx) {
    return ActionChip(
      label: Text(name),
      avatar: const Icon(Icons.attach_file, size: 14),
      backgroundColor: const Color(0xFFF1F5F9),
      onPressed: () {
        setState(() {
          _attachedFiles.add(AttachmentModel(
            id: 'att-${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            size: size,
            dateText: 'วันนี้',
            fileType: type,
          ));
        });
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('แนบไฟล์ $name แล้ว')),
        );
      },
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final appState = Provider.of<AppState>(context, listen: false);
      final selectedBank = kBankList.firstWhere((b) => b.code == _selectedBankCode, orElse: () => kBankList.first);
      final finalBankName = _selectedBankCode == 'OTHER' ? _customBankNameController.text.trim() : selectedBank.name;

      final selectedPM = kPaymentMethodList.firstWhere((p) => p.code == _selectedPaymentMethodCode, orElse: () => kPaymentMethodList.first);
      final finalPaymentMethod = _selectedPaymentMethodCode == 'OTHER' ? _customPaymentMethodController.text.trim() : selectedPM.name;

      appState.createOrderCard(
        cardType: _cardType,
        orderNo: _orderNoController.text.trim(),
        deliveryType: _deliveryType,
        priority: _priority,
        assignee: _assignee,
        createBy: appState.currentUser.name,
        attachments: _attachedFiles,
        errorDetails: _cardType == OrderCardType.orderDiff ? _errorDetailsController.text.trim() : null,
        bankCode: _cardType == OrderCardType.bankIssue ? _selectedBankCode : null,
        bankName: _cardType == OrderCardType.bankIssue ? finalBankName : null,
        paymentMethodCode: _cardType == OrderCardType.bankIssue ? _selectedPaymentMethodCode : null,
        paymentMethod: _cardType == OrderCardType.bankIssue ? finalPaymentMethod : null,
        amount: _cardType == OrderCardType.bankIssue ? double.tryParse(_amountController.text.trim()) ?? 0.0 : null,
        statusOrder: _cardType == OrderCardType.bankIssue ? _statusOrder : null,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('สร้างการ์ดออเดอร์เรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'สร้างการ์ดออเดอร์ใหม่ (Create Card)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Type Selector
              const Text('เลือกประเภทการ์ด (Card Type)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<OrderCardType>(
                      title: const Text('Order Diff', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      value: OrderCardType.orderDiff,
                      groupValue: _cardType,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => _cardType = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<OrderCardType>(
                      title: const Text('Bank Issue', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      value: OrderCardType.bankIssue,
                      groupValue: _cardType,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => _cardType = val!),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Order No.
              const Text('หมายเลขคำสั่งซื้อ (Order No.)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _orderNoController,
                decoration: const InputDecoration(hintText: 'เช่น 123456 (เว้นว่างเพื่อสร้างอัตโนมัติ)'),
              ),
              const SizedBox(height: 14),

              // Delivery Type & Priority
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ประเภทการส่ง (Delivery Type)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<DeliveryType>(
                          value: _deliveryType,
                          items: DeliveryType.values.map((d) => DropdownMenuItem(value: d, child: Text(d.label, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) => setState(() => _deliveryType = val!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ระดับความสำคัญ (Priority)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<CasePriority>(
                          value: _priority,
                          items: CasePriority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (val) => setState(() => _priority = val!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Conditional Fields for Order Diff vs Bank Issue
              if (_cardType == OrderCardType.orderDiff) ...[
                const Text('รายละเอียดข้อผิดพลาด (Error Details)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _errorDetailsController,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'ระบุรหัสหรือข้อความ Error ที่พบ'),
                  validator: (val) => (val == null || val.trim().isEmpty) ? 'กรุณากรอกรายละเอียด Error' : null,
                ),
              ] else ...[
                // Bank Issue Fields
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ธนาคาร (Bank)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _showBankSelectionDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                kBankList.firstWhere((b) => b.code == _selectedBankCode, orElse: () => kBankList.first).name,
                                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedBankCode == 'OTHER') ...[
                      const SizedBox(height: 10),
                      const Text('ระบุชื่อธนาคาร (Bank Name)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _customBankNameController,
                        decoration: const InputDecoration(hintText: 'กรุณาระบุชื่อธนาคาร'),
                        validator: (val) {
                          if (_selectedBankCode == 'OTHER' && (val == null || val.trim().isEmpty)) {
                            return 'กรุณาระบุชื่อธนาคาร';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('จำนวนเงิน (Amount)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'เช่น 1500.00'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ช่องทางชำระเงิน (Payment Method)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedPaymentMethodCode,
                      items: kPaymentMethodList.map((pm) => DropdownMenuItem(
                        value: pm.code,
                        child: Text(pm.name, style: const TextStyle(fontSize: 13)),
                      )).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPaymentMethodCode = val ?? 'QR_PROMPTPAY';
                          if (_selectedPaymentMethodCode != 'OTHER') {
                            _customPaymentMethodController.clear();
                          }
                        });
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                    if (_selectedPaymentMethodCode == 'OTHER') ...[
                      const SizedBox(height: 10),
                      const Text('ระบุช่องทางชำระเงิน (Payment Method)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _customPaymentMethodController,
                        decoration: const InputDecoration(hintText: 'กรุณาระบุช่องทางชำระเงิน'),
                        validator: (val) {
                          if (_selectedPaymentMethodCode == 'OTHER' && (val == null || val.trim().isEmpty)) {
                            return 'กรุณาระบุช่องทางชำระเงิน';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('สถานะคำสั่งซื้อ (Status Order)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<OrderStatus>(
                      value: _statusOrder,
                      items: OrderStatus.values.map((s) => DropdownMenuItem(value: s, child: Text('${s.code} - ${s.label}', style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (val) => setState(() => _statusOrder = val!),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),

              // Assignee & Interactive Attachments
              const Text('ผู้รับผิดชอบงาน (Assign)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<UserModel?>(
                value: _assignee,
                items: [
                  const DropdownMenuItem(value: null, child: Text('ยังไม่ระบุผู้รับผิดชอบ')),
                  ...appState.registeredUsers.map((u) => DropdownMenuItem(value: u, child: Text('${u.name} (${u.role})'))),
                ],
                onChanged: (val) => setState(() => _assignee = val),
              ),
              const SizedBox(height: 14),

              // Attachments Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ไฟล์แนบ / หลักฐาน (Attachments)', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _showAddFileDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('แนบไฟล์', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_attachedFiles.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Center(
                    child: Text('ยังไม่มีไฟล์แนบ (คลิก "แนบไฟล์" ด้านบนเพื่อเพิ่ม)', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ),
                )
              else
                ..._attachedFiles.map((f) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_drive_file, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                              Text(f.size, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          onPressed: () {
                            setState(() {
                              _attachedFiles.remove(f);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('บันทึกการสร้างการ์ด', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
