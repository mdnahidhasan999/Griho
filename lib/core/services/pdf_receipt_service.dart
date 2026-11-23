// noinspection SpellCheckingInspection
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptLineItem {
  final String title;
  final String periodLabel;
  final double amount;
  final String? status;

  const ReceiptLineItem({
    required this.title,
    required this.periodLabel,
    required this.amount,
    this.status,
  });
}

class PaymentReceiptData {
  final String receiptNumber;
  final String status; // 'confirmed', 'pending', 'rejected'
  final DateTime issuedAt;
  final String tenantName;
  final String tenantGrihoId;
  final String propertyName;
  final String unitName;
  final String paymentMethod;
  final String? referenceNumber;
  final String? note;
  final List<ReceiptLineItem> items;

  const PaymentReceiptData({
    required this.receiptNumber,
    required this.status,
    required this.issuedAt,
    required this.tenantName,
    required this.tenantGrihoId,
    required this.propertyName,
    required this.unitName,
    required this.paymentMethod,
    this.referenceNumber,
    this.note,
    required this.items,
  });

  double get totalAmount =>
      items.fold<double>(0.0, (sum, item) => sum + item.amount);
}

class MonthlyInvoicePdfData {
  final String invoiceNumber;
  final String billingPeriodLabel;
  final String status; // 'paid', 'partiallyPaid', 'unpaid', 'overdue'
  final DateTime dueDate;
  final String tenantName;
  final String? tenantPhone;
  final String propertyName;
  final String? propertyAddress;
  final String unitName;
  final double paidAmount;
  final String? note;
  final List<ReceiptLineItem> items;

  const MonthlyInvoicePdfData({
    required this.invoiceNumber,
    required this.billingPeriodLabel,
    required this.status,
    required this.dueDate,
    required this.tenantName,
    this.tenantPhone,
    required this.propertyName,
    this.propertyAddress,
    required this.unitName,
    this.paidAmount = 0,
    this.note,
    required this.items,
  });

  double get totalAmount =>
      items.fold<double>(0.0, (sum, item) => sum + item.amount);

  double get dueAmount =>
      (totalAmount - paidAmount).clamp(0.0, double.infinity);
}

class PdfReceiptService {
  PdfReceiptService._();

  static const _brandEmerald = PdfColor.fromInt(0xFF059669);
  static const _brandDark = PdfColor.fromInt(0xFF0F172A);
  static const _lightSurface = PdfColor.fromInt(0xFFF8FAFC);
  static const _borderColor = PdfColor.fromInt(0xFFE2E8F0);

  static final NumberFormat _currencyFmt = NumberFormat('#,##0.00', 'en_US');
  static final DateFormat _dateFmt = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _shortDateFmt = DateFormat('dd MMM yyyy');

  // ==========================================================================
  // 1. MONEY RECEIPT PDF (BACKWARD-COMPATIBLE + MULTIPAGE SAFE)
  // ==========================================================================

  static Future<Uint8List> buildReceiptPdf(PaymentReceiptData data) async {
    final pdf = pw.Document(
      title: 'Griho Receipt ${data.receiptNumber}',
      author: 'Griho Property Management',
    );

    final statusLower = data.status.toLowerCase();
    final isConfirmed = statusLower == 'confirmed' || statusLower == 'paid';
    final isRejected = statusLower == 'rejected';

    final statusLabel = isConfirmed
        ? 'PAID & CONFIRMED'
        : isRejected
        ? 'REJECTED'
        : 'PENDING VERIFICATION';

    final statusColor = isConfirmed
        ? _brandEmerald
        : isRejected
        ? PdfColors.red700
        : PdfColors.orange800;

    final statusBg = isConfirmed
        ? PdfColors.green50
        : isRejected
        ? PdfColors.red50
        : PdfColors.orange50;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => _buildFooter(
          context,
          leftText:
              'Computer-generated receipt via Griho • No signature required.',
        ),
        build: (context) => [
          _buildTopBanner(
            documentTitle: 'MONEY RECEIPT',
            reference: '#${data.receiptNumber.toUpperCase()}',
            dateText: _dateFmt.format(data.issuedAt.toLocal()),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _statusBadge(
                label: statusLabel,
                textColor: statusColor,
                bgColor: statusBg,
              ),
              pw.Text(
                'Method: ${data.paymentMethod.toUpperCase()}'
                '${(data.referenceNumber != null && data.referenceNumber!.trim().isNotEmpty) ? '  |  Ref: ${data.referenceNumber!.trim()}' : ''}',
                style: const pw.TextStyle(
                  fontSize: 9.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          _buildPartyDetailsBox(
            leftLabel: 'RECEIVED FROM (RESIDENT)',
            leftTitle: data.tenantName,
            leftSublines: [
              if (data.tenantGrihoId.trim().isNotEmpty)
                'Griho ID: ${data.tenantGrihoId.trim()}',
            ],
            rightLabel: 'PROPERTY & UNIT',
            rightTitle: data.propertyName,
            rightSublines: [data.unitName],
          ),
          pw.SizedBox(height: 18),
          _buildItemsTable(data.items),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 240,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _brandDark,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL PAID',
                    style: const pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 10.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'BDT ${_currencyFmt.format(data.totalAmount)}',
                    style: const pw.TextStyle(
                      color: PdfColors.greenAccent200,
                      fontSize: 12.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (data.note != null && data.note!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildNoteBox('Note: ${data.note!.trim()}'),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static Future<void> previewOrPrintReceipt(PaymentReceiptData data) async {
    final bytes = await buildReceiptPdf(data);
    await Printing.layoutPdf(
      name: 'Griho_Receipt_${data.receiptNumber}.pdf',
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> shareReceiptPdf(PaymentReceiptData data) async {
    final bytes = await buildReceiptPdf(data);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Griho_Receipt_${data.receiptNumber}.pdf',
    );
  }

  // ==========================================================================
  // 2. MONTHLY INVOICE PDF (RENT + UTILITY BILLS FOR ALL ROLES)
  // ==========================================================================

  static Future<Uint8List> buildInvoicePdf(MonthlyInvoicePdfData data) async {
    final pdf = pw.Document(
      title: 'Griho Invoice ${data.invoiceNumber}',
      author: 'Griho Property Management',
    );

    final isPaid = data.dueAmount <= 0 || data.status.toLowerCase() == 'paid';
    final isOverdue = data.status.toLowerCase() == 'overdue';

    final statusLabel = isPaid
        ? 'PAID IN FULL'
        : isOverdue
        ? 'OVERDUE'
        : data.paidAmount > 0
        ? 'PARTIALLY PAID'
        : 'UNPAID';

    final statusColor = isPaid
        ? _brandEmerald
        : isOverdue
        ? PdfColors.red700
        : PdfColors.orange800;

    final statusBg = isPaid
        ? PdfColors.green50
        : isOverdue
        ? PdfColors.red50
        : PdfColors.orange50;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => _buildFooter(
          context,
          leftText: 'Griho • Digital Rent & Utility Invoice',
        ),
        build: (context) => [
          _buildTopBanner(
            documentTitle: 'MONTHLY INVOICE',
            reference: '#${data.invoiceNumber.toUpperCase()}',
            dateText: 'Period: ${data.billingPeriodLabel}',
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _statusBadge(
                label: statusLabel,
                textColor: statusColor,
                bgColor: statusBg,
              ),
              pw.Text(
                'Due Date: ${_shortDateFmt.format(data.dueDate.toLocal())}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          _buildPartyDetailsBox(
            leftLabel: 'BILLED TO (RESIDENT)',
            leftTitle: data.tenantName,
            leftSublines: [
              if (data.tenantPhone != null &&
                  data.tenantPhone!.trim().isNotEmpty)
                data.tenantPhone!.trim(),
            ],
            rightLabel: 'PROPERTY & UNIT',
            rightTitle: data.propertyName,
            rightSublines: [
              data.unitName,
              if (data.propertyAddress != null &&
                  data.propertyAddress!.trim().isNotEmpty)
                data.propertyAddress!.trim(),
            ],
          ),
          pw.SizedBox(height: 18),
          _buildItemsTable(data.items),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 240,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: _lightSurface,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: _borderColor),
              ),
              child: pw.Column(
                children: [
                  _totalRow(
                    'Total Billed',
                    'BDT ${_currencyFmt.format(data.totalAmount)}',
                  ),
                  pw.SizedBox(height: 5),
                  _totalRow(
                    'Amount Paid',
                    'BDT ${_currencyFmt.format(data.paidAmount)}',
                  ),
                  pw.Divider(color: _borderColor, height: 12),
                  _totalRow(
                    'Balance Due',
                    'BDT ${_currencyFmt.format(data.dueAmount)}',
                    bold: true,
                    valueColor: data.dueAmount > 0
                        ? PdfColors.red700
                        : _brandEmerald,
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 16),
          _buildNoteBox(
            data.note?.trim().isNotEmpty == true
                ? data.note!.trim()
                : 'Please settle any remaining balance on or before ${_shortDateFmt.format(data.dueDate.toLocal())}.',
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<void> previewOrPrintInvoice(MonthlyInvoicePdfData data) async {
    final bytes = await buildInvoicePdf(data);
    await Printing.layoutPdf(
      name: 'Griho_Invoice_${data.invoiceNumber}.pdf',
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> shareInvoicePdf(MonthlyInvoicePdfData data) async {
    final bytes = await buildInvoicePdf(data);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Griho_Invoice_${data.invoiceNumber}.pdf',
    );
  }

  // ==========================================================================
  // 3. STATEMENT / HISTORY PDF (LEDGER, RENT RATES, TENANCY HISTORY)
  // ==========================================================================

  static Future<Uint8List> buildStatementPdf({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    String? summaryText,
  }) async {
    final pdf = pw.Document(
      title: 'Griho $title',
      author: 'Griho Property Management',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => _buildFooter(
          context,
          leftText: 'Griho • Digital Property Statement',
        ),
        build: (context) => [
          _buildTopBanner(
            documentTitle: title.toUpperCase(),
            reference: 'STATEMENT',
            dateText: _shortDateFmt.format(DateTime.now()),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: const pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9.5,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: _brandDark),
            cellStyle: const pw.TextStyle(fontSize: 9.5),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            border: pw.TableBorder.all(color: _borderColor, width: 0.6),
            oddRowDecoration: const pw.BoxDecoration(color: _lightSurface),
          ),
          if (summaryText != null && summaryText.trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _buildNoteBox(summaryText.trim()),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static Future<void> previewOrPrintStatement({
    required String fileName,
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    String? summaryText,
  }) async {
    final bytes = await buildStatementPdf(
      title: title,
      subtitle: subtitle,
      headers: headers,
      rows: rows,
      summaryText: summaryText,
    );
    await Printing.layoutPdf(
      name: fileName.endsWith('.pdf') ? fileName : '$fileName.pdf',
      onLayout: (_) async => bytes,
    );
  }

  static Future<void> shareStatementPdf({
    required String fileName,
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    String? summaryText,
  }) async {
    final bytes = await buildStatementPdf(
      title: title,
      subtitle: subtitle,
      headers: headers,
      rows: rows,
      summaryText: summaryText,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: fileName.endsWith('.pdf') ? fileName : '$fileName.pdf',
    );
  }

  // ==========================================================================
  // SHARED LAYOUT HELPERS
  // ==========================================================================

  static pw.Widget _buildTopBanner({
    required String documentTitle,
    required String reference,
    required String dateText,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: _brandDark,
        borderRadius: pw.BorderRadius.circular(12),
        border: const pw.Border(
          bottom: pw.BorderSide(color: _brandEmerald, width: 3),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'GRIHO',
                style: const pw.TextStyle(
                  color: PdfColors.greenAccent200,
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Manage Every Home',
                style: const pw.TextStyle(
                  color: PdfColors.grey300,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                documentTitle,
                style: const pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 13.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                reference,
                style: const pw.TextStyle(
                  color: PdfColors.amber200,
                  fontSize: 10,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                dateText,
                style: const pw.TextStyle(
                  color: PdfColors.grey300,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _statusBadge({
    required String label,
    required PdfColor textColor,
    required PdfColor bgColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: textColor, width: 0.8),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          color: textColor,
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _buildPartyDetailsBox({
    required String leftLabel,
    required String leftTitle,
    required List<String> leftSublines,
    required String rightLabel,
    required String rightTitle,
    required List<String> rightSublines,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _lightSurface,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _borderColor, width: 0.7),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  leftLabel,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  leftTitle,
                  style: const pw.TextStyle(
                    fontSize: 12.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                for (final line in leftSublines) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    line,
                    style: const pw.TextStyle(
                      fontSize: 9.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  rightLabel,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  rightTitle,
                  textAlign: pw.TextAlign.right,
                  style: const pw.TextStyle(
                    fontSize: 12.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                for (final line in rightSublines) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    line,
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(
                      fontSize: 9.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(List<ReceiptLineItem> items) {
    return pw.Table(
      border: pw.TableBorder.all(color: _borderColor, width: 0.7),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _brandDark),
          children: [
            _cell('Description / Bill Type', isHeader: true),
            _cell('Billing Period', isHeader: true),
            _cell('Amount (BDT)', isHeader: true, align: pw.TextAlign.right),
          ],
        ),
        for (var i = 0; i < items.length; i++)
          pw.TableRow(
            decoration: i.isOdd
                ? const pw.BoxDecoration(color: _lightSurface)
                : null,
            children: [
              _cell(items[i].title),
              _cell(items[i].periodLabel),
              _cell(
                _currencyFmt.format(items[i].amount),
                align: pw.TextAlign.right,
              ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _cell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.grey800,
        ),
      ),
    );
  }

  static pw.Widget _totalRow(
    String label,
    String value, {
    bool bold = false,
    PdfColor? valueColor,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: bold ? 10.5 : 9.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: bold ? _brandDark : PdfColors.grey700,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: bold ? 11.5 : 9.5,
            fontWeight: pw.FontWeight.bold,
            color: valueColor ?? _brandDark,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildNoteBox(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _lightSurface,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _borderColor, width: 0.7),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    );
  }

  static pw.Widget _buildFooter(
    pw.Context context, {
    required String leftText,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borderColor, width: 0.7)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            leftText,
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }
}
