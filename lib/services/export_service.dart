import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:printing/printing.dart';
import '../models/app_models.dart';

class ExportService {
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

      // 1. Build CSV Header
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

      // 2. Build CSV Rows from CaseModel
      for (var c in cases) {
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

      // 3. Convert List to CSV string
      final csvData = const ListToCsvConverter().convert(rows);

      // 4. Add UTF-8 BOM (\uFEFF) so Thai text opens correctly in Microsoft Excel
      final utf8BomCsv = '\uFEFF$csvData';
      final bytes = Uint8List.fromList(utf8.encode(utf8BomCsv));

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'DevCase_Report_$timestamp.csv';

      // 5. Open Native Mobile Share/Download Sheet
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
}
