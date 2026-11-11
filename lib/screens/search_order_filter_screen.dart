import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';

class SearchOrderFilterScreen extends StatefulWidget {
  const SearchOrderFilterScreen({super.key});

  @override
  State<SearchOrderFilterScreen> createState() => _SearchOrderFilterScreenState();
}

class _SearchOrderFilterScreenState extends State<SearchOrderFilterScreen> {
  final TextEditingController _searchController = TextEditingController();
  OrderCardType? _tempCardType;
  DeliveryType? _tempDeliveryType;
  OrderActivityStatus? _tempActivityStatus;
  CasePriority? _tempPriority;
  DateTimeRange? _tempDateRange;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _searchController.text = appState.orderSearchQuery;
    _tempCardType = appState.filterOrderCardType;
    _tempDeliveryType = appState.filterOrderDeliveryType;
    _tempActivityStatus = appState.filterOrderActivityStatus;
    _tempPriority = appState.filterOrderPriority;
    _tempDateRange = appState.filterOrderDateRange;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearAll() {
    setState(() {
      _searchController.clear();
      _tempCardType = null;
      _tempDeliveryType = null;
      _tempActivityStatus = null;
      _tempPriority = null;
      _tempDateRange = null;
    });
    Provider.of<AppState>(context, listen: false).setOrderFilters(clearAll: true);
  }

  void _applyFilter() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setOrderFilters(
      query: _searchController.text.trim(),
      cardType: _tempCardType,
      clearCardType: _tempCardType == null,
      deliveryType: _tempDeliveryType,
      clearDeliveryType: _tempDeliveryType == null,
      activityStatus: _tempActivityStatus,
      clearActivityStatus: _tempActivityStatus == null,
      priority: _tempPriority,
      clearPriority: _tempPriority == null,
      dateRange: _tempDateRange,
      clearDateRange: _tempDateRange == null,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
          'ค้นหา / กรองออเดอร์',
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
                hintText: 'ค้นหา Order No., ธนาคาร, อาการ Error...',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 20),

            // Card Type Section
            _buildSectionHeader('ประเภทการ์ด (Card Type)'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip(
                  label: 'ทั้งหมด',
                  isSelected: _tempCardType == null,
                  onTap: () => setState(() => _tempCardType = null),
                ),
                ...OrderCardType.values.map(
                  (c) => _buildChoiceChip(
                    label: c.label,
                    isSelected: _tempCardType == c,
                    onTap: () => setState(() => _tempCardType = c),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Delivery Type Section
            _buildSectionHeader('ประเภทการจัดส่ง (Delivery Type)'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip(
                  label: 'ทั้งหมด',
                  isSelected: _tempDeliveryType == null,
                  onTap: () => setState(() => _tempDeliveryType = null),
                ),
                ...DeliveryType.values.map(
                  (d) => _buildChoiceChip(
                    label: d.label,
                    isSelected: _tempDeliveryType == d,
                    onTap: () => setState(() => _tempDeliveryType = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Activity Status Section
            _buildSectionHeader('สถานะ Activity'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChoiceChip(
                  label: 'ทั้งหมด',
                  isSelected: _tempActivityStatus == null,
                  onTap: () => setState(() => _tempActivityStatus = null),
                ),
                ...OrderActivityStatus.values.map(
                  (st) => _buildChoiceChip(
                    label: st.label,
                    isSelected: _tempActivityStatus == st,
                    color: st.color,
                    bgColor: st.backgroundColor,
                    onTap: () => setState(() => _tempActivityStatus = st),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Priority Section
            _buildSectionHeader('ระดับความสำคัญ (Priority)'),
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
