import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/app_models.dart';

class PdfReportService {
  /// Generates and directly downloads/saves a PDF Executive Summary Report.
  static Future<void> generateAndPreviewPdf(
    BuildContext context, {
    required List<CaseModel> cases,
    required DateTimeRange dateRange,
    required CaseStatus? selectedStatus,
    required CasePriority? selectedPriority,
    required String userRoleLabel,
  }) async {
    try {
      if (cases.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่มีรายการเคสสำหรับสร้างรายงาน PDF'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Load Thai Font (Kanit) for PDF rendering
      final font = await PdfGoogleFonts.kanitRegular();
      final fontBold = await PdfGoogleFonts.kanitBold();

      final doc = pw.Document();

      // Dates & Filters formatting
      final dateFormat = DateFormat('dd/MM/yyyy');
      final dateRangeStr = '${dateFormat.format(dateRange.start)} - ${dateFormat.format(dateRange.end)}';
      final statusStr = selectedStatus != null ? selectedStatus.label : 'ทุกสถานะ';
      final priorityStr = selectedPriority != null ? selectedPriority.label : 'ทุกระดับ';
      final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      // Status Counts Calculation
      final total = cases.length;
      final openCount = cases.where((c) => c.status == CaseStatus.open || c.status == CaseStatus.assigned).length;
      final inProgressCount = cases.where((c) => c.status == CaseStatus.inProgress || c.status == CaseStatus.waiting || c.status == CaseStatus.testing || c.status == CaseStatus.pending).length;
      final resolvedCount = cases.where((c) => c.status == CaseStatus.done || c.status == CaseStatus.closed).length;

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(
            base: font,
            bold: fontBold,
          ),
          header: (pw.Context ctx) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                'Dev Case Management System',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                  font: font,
                ),
              ),
            );
          },
          footer: (pw.Context ctx) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Text(
                'หน้า ${ctx.pageNumber} จาก ${ctx.pagesCount}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                  font: font,
                ),
              ),
            );
          },
          build: (pw.Context ctx) {
            return [
              // Report Header Title
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#1D61E7'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Dev Case Management Report',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        font: fontBold,
                      ),
                    ),
                    pw.Text(
                      'วันที่พิมพ์: $nowStr',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.white,
                        font: font,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Filter Summary Info Box
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'เงื่อนไขการออกรายงาน (Report Search Criteria)',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#1E293B'),
                        font: fontBold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text('ช่วงวันที่: $dateRangeStr', style: pw.TextStyle(fontSize: 10, font: font))),
                        pw.Expanded(child: pw.Text('สถานะ: $statusStr', style: pw.TextStyle(fontSize: 10, font: font))),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(child: pw.Text('Priority: $priorityStr', style: pw.TextStyle(fontSize: 10, font: font))),
                        pw.Expanded(child: pw.Text('สิทธิ์ผู้พิมพ์: $userRoleLabel', style: pw.TextStyle(fontSize: 10, font: font))),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              // Executive Summary Table
              pw.Text(
                'สรุปภาพรวมจำนวนเคส (Summary Overview)',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1E293B'),
                  font: fontBold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['Total Cases', 'Open', 'In Progress', 'Resolved'],
                data: [
                  ['$total', '$openCount', '$inProgressCount', '$resolvedCount']
                ],
                border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1')),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11, font: fontBold),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1D61E7')),
                cellAlignment: pw.Alignment.center,
                cellStyle: pw.TextStyle(fontSize: 11, font: fontBold, color: PdfColor.fromHex('#1E293B')),
              ),
              pw.SizedBox(height: 16),

              // Case Details Table
              pw.Text(
                'ตารางรายละเอียดเคส (Case Details)',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1E293B'),
                  font: fontBold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: ['Case ID', 'หัวข้อเคส (Title)', 'Status', 'Priority', 'ทีม', 'ผู้รับผิดชอบ', 'วันที่'],
                data: cases.map((c) {
                  return [
                    c.id,
                    c.title,
                    c.status.label,
                    c.priority.label,
                    c.team.label,
                    c.assignee != null ? c.assignee!.name : 'ยังไม่ระบุ',
                    c.dateText,
                  ];
                }).toList(),
                border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0')),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10, font: fontBold),
                headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E293B')),
                cellStyle: pw.TextStyle(fontSize: 9, font: font),
                cellAlignment: pw.Alignment.centerLeft,
                rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              ),
            ];
          },
        ),
      );

      // Save PDF bytes
      final pdfBytes = await doc.save();
      final fileName = 'dev_case_report_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.pdf';

      // Share/Download PDF directly via Printing native handler
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ส่งออกรายงาน PDF $fileName เรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการสร้าง PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
