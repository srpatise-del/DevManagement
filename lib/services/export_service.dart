import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:printing/printing.dart';
import '../models/app_models.dart';

class ExportService {
  static List<List<dynamic>> _buildCaseRows(List<CaseModel> cases) {
    final List<List<dynamic>> rows = [
      [
        'Case ID',
        'Title',
        'Status',
        'Priority',
        'Team',
        'Category',
        'Assignee',
        'Date',
        'System Affected',
        'Environment',
        'URL',
        'Browser',
        'Created By',
        'Comments Count',
        'Files Count',
      ]
    ];

    for (final c in cases) {
      rows.add([
        c.id,
        c.title,
        c.status.label,
        c.priority.label,
        c.team.label,
        c.category,
        c.assignee != null ? c.assignee!.name : 'ยังไม่ระบุผู้รับผิดชอบ',
        c.dateText,
        c.systemAffected,
        c.environment,
        c.url,
        c.browser,
        c.createdById,
        c.comments.length,
        c.attachedFiles.length,
      ]);
    }
    return rows;
  }

  static List<List<dynamic>> _buildOrderRows(List<OrderModel> orders) {
    final List<List<dynamic>> rows = [
      [
        'Order No.',
        'Card Type',
        'Delivery Type',
        'Activity Status',
        'Order Status',
        'Priority',
        'Bank',
        'Payment Method',
        'Amount (THB)',
        'Error / Details',
        'Assignee',
        'Created By',
        'Date',
        'Comments Count',
        'Attachments Count',
      ]
    ];

    for (final o in orders) {
      final isBank = o.cardType == OrderCardType.bankIssue;
      rows.add([
        o.id,
        o.cardType.label,
        o.deliveryType.label,
        o.activityStatus.label,
        isBank && o.statusOrder != null ? '${o.statusOrder!.code} - ${o.statusOrder!.label}' : '-',
        o.priority.label,
        isBank ? o.displayBankName : '-',
        isBank ? o.displayPaymentMethod : '-',
        isBank && o.amount != null ? o.amount!.toStringAsFixed(2) : '-',
        o.errorDetails ?? '-',
        o.assignee != null ? o.assignee!.name : 'ยังไม่ระบุผู้รับผิดชอบ',
        o.createBy,
        o.dateText,
        o.comments.length,
        o.attachments.length,
      ]);
    }
    return rows;
  }

  static Future<void> _shareCsvRows(
    BuildContext context,
    List<List<dynamic>> rows,
    String fileName,
  ) async {
    final csvData = const ListToCsvConverter().convert(rows);
    // Add UTF-8 BOM (\uFEFF) so Thai text opens correctly in Microsoft Excel
    final utf8BomCsv = '\uFEFF$csvData';
    final bytes = Uint8List.fromList(utf8.encode(utf8BomCsv));

    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งออกไฟล์ $fileName เรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Exports a list of [cases] to a CSV file and opens the native Mobile Share/Save Sheet.
  static Future<void> exportCasesToCsv(
    BuildContext context,
    List<CaseModel> cases, {
    String? titleSuffix,
  }) async {
    try {
      if (cases.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่มีรายการเคสสำหรับส่งออกข้อมูล'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final rows = _buildCaseRows(cases);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'DevIncident_Cases_Report_$timestamp.csv';
      await _shareCsvRows(context, rows, fileName);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการส่งออก CSV: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Exports a list of [orders] to a CSV file and opens the native Mobile Share/Save Sheet.
  static Future<void> exportOrdersToCsv(
    BuildContext context,
    List<OrderModel> orders,
  ) async {
    try {
      if (orders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่มีรายการออเดอร์สำหรับส่งออกข้อมูล'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final rows = _buildOrderRows(orders);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'DevIncident_Orders_Report_$timestamp.csv';
      await _shareCsvRows(context, rows, fileName);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการส่งออก CSV ออเดอร์: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Exports both [cases] and [orders] into a single combined CSV report with clear sections.
  static Future<void> exportCombinedToCsv(
    BuildContext context, {
    required List<CaseModel> cases,
    required List<OrderModel> orders,
  }) async {
    try {
      if (cases.isEmpty && orders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่มีรายการเคสหรือออเดอร์สำหรับส่งออกข้อมูล'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final List<List<dynamic>> rows = [];
      if (cases.isNotEmpty) {
        rows.add(['=== CASES REPORT (${cases.length}) ===']);
        rows.addAll(_buildCaseRows(cases));
      }
      if (cases.isNotEmpty && orders.isNotEmpty) {
        rows.add([]);
      }
      if (orders.isNotEmpty) {
        rows.add(['=== ORDERS REPORT (${orders.length}) ===']);
        rows.addAll(_buildOrderRows(orders));
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'DevIncident_All_Report_$timestamp.csv';
      await _shareCsvRows(context, rows, fileName);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการส่งออก CSV รวม: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
