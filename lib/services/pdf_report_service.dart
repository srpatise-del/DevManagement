import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/app_models.dart';

class PdfReportService {
  static pw.Widget _buildHeaderBanner(String title, String nowStr, pw.Font font, pw.Font fontBold, String hexColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex(hexColor),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 17,
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
    );
  }

  static List<pw.Widget> _buildCaseSection(List<CaseModel> cases, pw.Font font, pw.Font fontBold) {
    final total = cases.length;
    final openCount = cases.where((c) => c.status == CaseStatus.open || c.status == CaseStatus.assigned).length;
    final inProgressCount = cases
        .where((c) =>
            c.status == CaseStatus.inProgress ||
            c.status == CaseStatus.waiting ||
            c.status == CaseStatus.testing ||
            c.status == CaseStatus.pending)
        .length;
    final resolvedCount = cases.where((c) => c.status == CaseStatus.done || c.status == CaseStatus.closed).length;

    return [
      pw.Text(
        'สรุปภาพรวมจำนวนเคส (Cases Summary Overview)',
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
      pw.SizedBox(height: 14),
      pw.Text(
        'ตารางรายละเอียดเคส (Case Details - $total รายการ)',
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#1E293B'),
          font: fontBold,
        ),
      ),
      pw.SizedBox(height: 6),
      if (cases.isEmpty)
        pw.Text('ไม่มีรายการเคสตามเงื่อนไขที่เลือก', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font))
      else
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
  }

  static List<pw.Widget> _buildOrderSection(List<OrderModel> orders, pw.Font font, pw.Font fontBold) {
    final total = orders.length;
    final diffCount = orders.where((o) => o.cardType == OrderCardType.orderDiff).length;
    final bankCount = orders.where((o) => o.cardType == OrderCardType.bankIssue).length;
    final doneCount = orders
        .where((o) => o.activityStatus == OrderActivityStatus.resolved || o.activityStatus == OrderActivityStatus.closed)
        .length;
    final totalAmount = orders
        .where((o) => o.cardType == OrderCardType.bankIssue)
        .fold<double>(0.0, (sum, o) => sum + (o.amount ?? 0.0));
    final amountFmt = NumberFormat('#,##0.00');

    return [
      pw.Text(
        'สรุปภาพรวมจำนวนออเดอร์ (Orders Summary Overview)',
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#1E293B'),
          font: fontBold,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: ['Total Orders', 'Order Diff', 'Bank Issue', 'Complete / Closed', 'ยอดรวม Bank (THB)'],
        data: [
          ['$total', '$diffCount', '$bankCount', '$doneCount', amountFmt.format(totalAmount)]
        ],
        border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1')),
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10, font: fontBold),
        headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#7C3AED')),
        cellAlignment: pw.Alignment.center,
        cellStyle: pw.TextStyle(fontSize: 10, font: fontBold, color: PdfColor.fromHex('#1E293B')),
      ),
      pw.SizedBox(height: 14),
      pw.Text(
        'ตารางรายละเอียดออเดอร์ (Order Details - $total รายการ)',
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#1E293B'),
          font: fontBold,
        ),
      ),
      pw.SizedBox(height: 6),
      if (orders.isEmpty)
        pw.Text('ไม่มีรายการออเดอร์ตามเงื่อนไขที่เลือก', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font))
      else
        pw.TableHelper.fromTextArray(
          headers: ['Order No.', 'ประเภท', 'สถานะ', 'Priority', 'รายละเอียด / ธนาคาร', 'ยอดเงิน', 'ผู้รับผิดชอบ', 'วันที่'],
          data: orders.map((o) {
            final isBank = o.cardType == OrderCardType.bankIssue;
            final detailText = isBank
                ? '${o.displayBankName} (${o.displayPaymentMethod})'
                : (o.errorDetails?.trim().isNotEmpty == true ? o.errorDetails!.trim() : '-');
            final amountText = isBank && o.amount != null ? amountFmt.format(o.amount) : '-';
            return [
              o.id,
              isBank ? 'Bank Issue' : 'Order Diff',
              o.activityStatus.label,
              o.priority.label,
              detailText,
              amountText,
              o.assignee != null ? o.assignee!.name : 'ยังไม่ระบุ',
              o.dateText,
            ];
          }).toList(),
          border: pw.TableBorder.all(color: PdfColor.fromHex('#E2E8F0')),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9, font: fontBold),
          headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E293B')),
          cellStyle: pw.TextStyle(fontSize: 8.5, font: font),
          cellAlignment: pw.Alignment.centerLeft,
          rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
        ),
    ];
  }

  /// Generates and directly downloads/saves a PDF Executive Summary Report for Cases.
  static Future<void> generateAndPreviewPdf(
    BuildContext context, {
    required List<CaseModel> cases,
    required DateTimeRange dateRange,
    required CaseStatus? selectedStatus,
    required CasePriority? selectedPriority,
    required String userRoleLabel,
    bool filterByDate = true,
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

      final font = await PdfGoogleFonts.kanitRegular();
      final fontBold = await PdfGoogleFonts.kanitBold();
      final doc = pw.Document();

      final dateFormat = DateFormat('dd/MM/yyyy');
      final dateRangeStr = filterByDate
          ? '${dateFormat.format(dateRange.start)} - ${dateFormat.format(dateRange.end)}'
          : 'ทุกช่วงเวลา';
      final statusStr = selectedStatus != null ? selectedStatus.label : 'ทุกสถานะ';
      final priorityStr = selectedPriority != null ? selectedPriority.label : 'ทุกระดับ';
      final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          header: (pw.Context ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Text('DevIncident - Case Management System', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font)),
          ),
          footer: (pw.Context ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text('หน้า ${ctx.pageNumber} จาก ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font)),
          ),
          build: (pw.Context ctx) => [
            _buildHeaderBanner('DevIncident - Cases Report', nowStr, font, fontBold, '#1D61E7'),
            pw.SizedBox(height: 14),
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
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B'), font: fontBold),
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
            ..._buildCaseSection(cases, font, fontBold),
          ],
        ),
      );

      final pdfBytes = await doc.save();
      final fileName = 'devincident_cases_report_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งออกรายงาน PDF $fileName เรียบร้อยแล้ว'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการสร้าง PDF: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Generates and shares a PDF Executive Summary Report for Orders (Order Diff & Bank Issue).
  static Future<void> generateOrdersPdf(
    BuildContext context, {
    required List<OrderModel> orders,
    required DateTimeRange dateRange,
    required OrderCardType? selectedCardType,
    required OrderActivityStatus? selectedActivityStatus,
    required CasePriority? selectedPriority,
    required String userRoleLabel,
    bool filterByDate = true,
  }) async {
    try {
      if (orders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่มีรายการออเดอร์สำหรับสร้างรายงาน PDF'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final font = await PdfGoogleFonts.kanitRegular();
      final fontBold = await PdfGoogleFonts.kanitBold();
      final doc = pw.Document();

      final dateFormat = DateFormat('dd/MM/yyyy');
      final dateRangeStr = filterByDate
          ? '${dateFormat.format(dateRange.start)} - ${dateFormat.format(dateRange.end)}'
          : 'ทุกช่วงเวลา';
      final cardTypeStr = selectedCardType != null ? selectedCardType.label : 'ทุกประเภท (Order Diff + Bank Issue)';
      final statusStr = selectedActivityStatus != null ? selectedActivityStatus.label : 'ทุกสถานะ';
      final priorityStr = selectedPriority != null ? selectedPriority.label : 'ทุกระดับ';
      final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          header: (pw.Context ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Text('DevIncident - Order Management System', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font)),
          ),
          footer: (pw.Context ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text('หน้า ${ctx.pageNumber} จาก ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font)),
          ),
          build: (pw.Context ctx) => [
            _buildHeaderBanner('DevIncident - Orders Report', nowStr, font, fontBold, '#7C3AED'),
            pw.SizedBox(height: 14),
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
                    'เงื่อนไขการออกรายงานออเดอร์ (Order Report Criteria)',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1E293B'), font: fontBold),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text('ช่วงวันที่: $dateRangeStr', style: pw.TextStyle(fontSize: 10, font: font))),
                      pw.Expanded(child: pw.Text('ประเภทการ์ด: $cardTypeStr', style: pw.TextStyle(fontSize: 10, font: font))),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text('สถานะ: $statusStr • Priority: $priorityStr', style: pw.TextStyle(fontSize: 10, font: font))),
                      pw.Expanded(child: pw.Text('สิทธิ์ผู้พิมพ์: $userRoleLabel', style: pw.TextStyle(fontSize: 10, font: font))),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            ..._buildOrderSection(orders, font, fontBold),
          ],
        ),
      );

      final pdfBytes = await doc.save();
      final fileName = 'devincident_orders_report_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งออกรายงาน PDF $fileName เรียบร้อยแล้ว'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการสร้าง PDF ออเดอร์: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Generates and shares a combined PDF Executive Summary Report containing both Cases and Orders.
  static Future<void> generateCombinedPdf(
    BuildContext context, {
    required List<CaseModel> cases,
    required List<OrderModel> orders,
    required DateTimeRange dateRange,
    required CasePriority? selectedPriority,
    required String userRoleLabel,
    bool filterByDate = true,
  }) async {
    try {
      if (cases.isEmpty && orders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่มีรายการเคสหรือออเดอร์สำหรับสร้างรายงาน PDF'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final font = await PdfGoogleFonts.kanitRegular();
      final fontBold = await PdfGoogleFonts.kanitBold();
      final doc = pw.Document();

      final dateFormat = DateFormat('dd/MM/yyyy');
      final dateRangeStr = filterByDate
          ? '${dateFormat.format(dateRange.start)} - ${dateFormat.format(dateRange.end)}'
          : 'ทุกช่วงเวลา';
      final priorityStr = selectedPriority != null ? selectedPriority.label : 'ทุกระดับ';
      final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          header: (pw.Context ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Text('DevIncident - Incident & Order Management', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font)),
          ),
          footer: (pw.Context ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text('หน้า ${ctx.pageNumber} จาก ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font)),
          ),
          build: (pw.Context ctx) => [
            _buildHeaderBanner('DevIncident - Full Summary Report', nowStr, font, fontBold, '#0F172A'),
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(child: pw.Text('ช่วงวันที่: $dateRangeStr', style: pw.TextStyle(fontSize: 10, font: font))),
                  pw.Expanded(child: pw.Text('Priority: $priorityStr', style: pw.TextStyle(fontSize: 10, font: font))),
                  pw.Expanded(child: pw.Text('สิทธิ์ผู้พิมพ์: $userRoleLabel', style: pw.TextStyle(fontSize: 10, font: font))),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            ..._buildCaseSection(cases, font, fontBold),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColor.fromHex('#CBD5E1')),
            pw.SizedBox(height: 12),
            ..._buildOrderSection(orders, font, fontBold),
          ],
        ),
      );

      final pdfBytes = await doc.save();
      final fileName = 'devincident_summary_report_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งออกรายงาน PDF รวม $fileName เรียบร้อยแล้ว'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการสร้าง PDF รวม: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
