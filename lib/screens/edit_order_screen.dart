import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../config/attachment_config.dart';

class EditOrderScreen extends StatefulWidget {
  final OrderModel orderObj;

  const EditOrderScreen({super.key, required this.orderObj});

  @override
  State<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends State<EditOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _errorDetailsController;
  late TextEditingController _customBankNameController;
  late TextEditingController _customPaymentMethodController;
  late TextEditingController _amountController;

  late String _selectedBankCode;
  late String _selectedPaymentMethodCode;
  late List<AttachmentModel> _attachedFiles;
  late DeliveryType _deliveryType;
  late CasePriority _priority;
  late OrderStatus _statusOrder;
  UserModel? _assignee;

  @override
  void initState() {
    super.initState();
    _errorDetailsController = TextEditingController(text: widget.orderObj.errorDetails ?? '');
    _amountController = TextEditingController(text: widget.orderObj.amount?.toString() ?? '');

    String initialCode = widget.orderObj.bankCode ?? 'SCB';
    if (initialCode == 'OTHER') {
      _selectedBankCode = 'OTHER';
      _customBankNameController = TextEditingController(text: widget.orderObj.bankName ?? '');
    } else if (kBankList.any((b) => b.code == initialCode)) {
      _selectedBankCode = initialCode;
      _customBankNameController = TextEditingController();
    } else {
      final match = kBankList.firstWhere(
        (b) => b.name.toLowerCase().contains((widget.orderObj.bankName ?? '').toLowerCase()) ||
               b.code.toLowerCase() == (widget.orderObj.bankName ?? '').toLowerCase(),
        orElse: () => const BankInfo(code: 'OTHER', name: ''),
      );
      if (match.code != 'OTHER') {
        _selectedBankCode = match.code;
        _customBankNameController = TextEditingController();
      } else {
        _selectedBankCode = 'OTHER';
        _customBankNameController = TextEditingController(text: widget.orderObj.bankName ?? '');
      }
    }

    String initialPMCode = widget.orderObj.paymentMethodCode ?? 'QR_PROMPTPAY';
    if (initialPMCode == 'OTHER') {
      _selectedPaymentMethodCode = 'OTHER';
      _customPaymentMethodController = TextEditingController(text: widget.orderObj.paymentMethod ?? '');
    } else if (kPaymentMethodList.any((p) => p.code == initialPMCode)) {
      _selectedPaymentMethodCode = initialPMCode;
      _customPaymentMethodController = TextEditingController();
    } else {
      final matchPM = kPaymentMethodList.firstWhere(
        (p) => p.name.toLowerCase().contains((widget.orderObj.paymentMethod ?? '').toLowerCase()) ||
               p.code.toLowerCase() == (widget.orderObj.paymentMethod ?? '').toLowerCase(),
        orElse: () => const PaymentMethodInfo(code: 'OTHER', name: ''),
      );
      if (matchPM.code != 'OTHER') {
        _selectedPaymentMethodCode = matchPM.code;
        _customPaymentMethodController = TextEditingController();
      } else {
        _selectedPaymentMethodCode = 'OTHER';
        _customPaymentMethodController = TextEditingController(text: widget.orderObj.paymentMethod ?? '');
      }
    }

    _attachedFiles = List.from(widget.orderObj.attachments);
    _deliveryType = widget.orderObj.deliveryType;
    _priority = widget.orderObj.priority;
    _statusOrder = widget.orderObj.statusOrder ?? OrderStatus.pending;
    _assignee = widget.orderObj.assignee;
  }

  @override
  void dispose() {
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
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final result = await FilePicker.platform.pickFiles(
                      allowMultiple: false,
                      type: FileType.custom,
                      allowedExtensions: AttachmentConfig.allAllowedExtensions.toList(),
                      withData: true,
                    );
                    if (result != null && result.files.isNotEmpty) {
                      final f = result.files.first;
                      final err = AttachmentConfig.validateFile(
                        fileName: f.name,
                        fileSizeBytes: f.size,
                      );
                      if (err != null) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(err), backgroundColor: Colors.red),
                          );
                        }
                        return;
                      }

                      final ext = f.extension ?? (f.name.contains('.') ? f.name.split('.').last : 'file');
                      final sizeStr = AttachmentConfig.formatFileSize(f.size);
                      final appState = Provider.of<AppState>(context, listen: false);

                      if (f.bytes != null) {
                        await appState.uploadOrderAttachment(
                          orderId: widget.orderObj.id,
                          fileBytes: f.bytes!,
                          fileName: f.name,
                          fileSize: sizeStr,
                          fileType: ext,
                          fileSizeBytes: f.size,
                        );
                        final updated = appState.orders.firstWhere(
                          (o) => o.id == widget.orderObj.id || o.supabaseId == widget.orderObj.supabaseId,
                          orElse: () => widget.orderObj,
                        );
                        setState(() {
                          _attachedFiles = List<AttachmentModel>.from(updated.attachments);
                        });
                      } else {
                        throw Exception('ไม่สามารถอ่านข้อมูลไฟล์จากอุปกรณ์ได้');
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('แนบไฟล์ ${f.name} สำเร็จแล้ว'), backgroundColor: Colors.green),
                        );
                      }
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text('แนบไฟล์ไม่สำเร็จ: ${e.toString().replaceAll('Exception: ', '')}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.folder_open, size: 20),
                label: const Text('เลือกไฟล์จากอุปกรณ์ (Choose File from device)', style: TextStyle(fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final appState = Provider.of<AppState>(context, listen: false);
      final selectedBank = kBankList.firstWhere((b) => b.code == _selectedBankCode, orElse: () => kBankList.first);
      final finalBankName = _selectedBankCode == 'OTHER' ? _customBankNameController.text.trim() : selectedBank.name;

      final selectedPM = kPaymentMethodList.firstWhere((p) => p.code == _selectedPaymentMethodCode, orElse: () => kPaymentMethodList.first);
      final finalPaymentMethod = _selectedPaymentMethodCode == 'OTHER' ? _customPaymentMethodController.text.trim() : selectedPM.name;

      final updatedOrder = widget.orderObj.copyWith(
        deliveryType: _deliveryType,
        priority: _priority,
        assignee: _assignee,
        clearAssignee: _assignee == null,
        attachments: _attachedFiles,
        errorDetails: widget.orderObj.cardType == OrderCardType.orderDiff ? _errorDetailsController.text.trim() : null,
        bankCode: widget.orderObj.cardType == OrderCardType.bankIssue ? _selectedBankCode : null,
        bankName: widget.orderObj.cardType == OrderCardType.bankIssue ? finalBankName : null,
        paymentMethodCode: widget.orderObj.cardType == OrderCardType.bankIssue ? _selectedPaymentMethodCode : null,
        paymentMethod: widget.orderObj.cardType == OrderCardType.bankIssue ? finalPaymentMethod : null,
        amount: widget.orderObj.cardType == OrderCardType.bankIssue ? double.tryParse(_amountController.text.trim()) : null,
        statusOrder: widget.orderObj.cardType == OrderCardType.bankIssue ? _statusOrder : null,
      );

      try {
        await appState.updateOrderCard(updatedOrder);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('แก้ไขการ์ดออเดอร์ ${widget.orderObj.id} เรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('แก้ไขการ์ดออเดอร์ไม่สำเร็จ: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isDiff = widget.orderObj.cardType == OrderCardType.orderDiff;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'แก้ไขการ์ดออเดอร์ (${widget.orderObj.id})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Type (Readonly info)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'ประเภทการ์ด: ${widget.orderObj.cardType.label}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Delivery Type & Priority
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Delivery Type', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<DeliveryType>(
                          value: _deliveryType,
                          items: DeliveryType.values.map((d) => DropdownMenuItem(value: d, child: Text(d.label))).toList(),
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
                        const Text('Priority', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<CasePriority>(
                          value: _priority,
                          items: CasePriority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.label))).toList(),
                          onChanged: (val) => setState(() => _priority = val!),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Specific fields: Error Details vs Bank Details
              if (isDiff) ...[
                const Text('รายละเอียดข้อผิดพลาด (Error Details)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _errorDetailsController,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'ระบุรายละเอียดปัญหาหรือ Error'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'กรุณากรอกรายละเอียด Error' : null,
                ),
              ] else ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ธนาคาร (Bank)', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    const Text('จำนวนเงิน (บาท)', style: TextStyle(fontWeight: FontWeight.bold)),
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
                value: appState.registeredUsers.contains(_assignee) ? _assignee : null,
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
                  child: const Text('บันทึกการแก้ไข', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
