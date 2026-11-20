import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptLineItem {
  final String title;
  final String periodLabel;
  final double amount;

  const ReceiptLineItem({
    required this.title,
    required this.periodLabel,
    required this.amount,
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

class PdfReceiptService {
  PdfReceiptService._();

  static final NumberFormat _currencyFmt = NumberFormat('#,##0.00', 'en_US');
  static final DateFormat _dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

  /// Generates the raw PDF bytes for a single or combined money receipt.
  static Future<Uint8List> buildReceiptPdf(PaymentReceiptData data) async {
    final pdf = pw.Document(
      title: 'Griho Receipt ${data.receiptNumber}',
      author: 'Griho Property Management',
    );

    final isConfirmed = data.status.toLowerCase() == 'confirmed';
    final isRejected = data.status.toLowerCase() == 'rejected';

    final statusLabel = isConfirmed
        ? 'PAID & CONFIRMED'
        : isRejected
        ? 'REJECTED'
        : 'PENDING VERIFICATION';

    final statusColor = isConfirmed
        ? PdfColors.green800
        : isRejected
        ? PdfColors.red800
        : PdfColors.orange800;

    final statusBg = isConfirmed
        ? PdfColors.green50
        : isRejected
        ? PdfColors.red50
        : PdfColors.orange50;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ============================================================
              // TOP BRANDING & RECEIPT HEADER
              // ============================================================
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFF1B2232),
                  borderRadius: pw.BorderRadius.circular(12),
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
                            color: PdfColors.white,
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Digital Rent & Property Management Receipt',
                          style: const pw.TextStyle(
                            color: PdfColors.grey300,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'MONEY RECEIPT',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '#${data.receiptNumber.toUpperCase()}',
                          style: const pw.TextStyle(
                            color: PdfColors.amber200,
                            fontSize: 10,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          _dateFmt.format(data.issuedAt),
                          style: const pw.TextStyle(
                            color: PdfColors.grey300,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 18),

              // ============================================================
              // STATUS BANNER & PAYMENT META
              // ============================================================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      color: statusBg,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: statusColor, width: 0.8),
                    ),
                    child: pw.Text(
                      statusLabel,
                      style: pw.TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Text(
                    'Method: ${data.paymentMethod.toUpperCase()}'
                    '${(data.referenceNumber != null && data.referenceNumber!.isNotEmpty) ? '  |  Ref: ${data.referenceNumber}' : ''}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 18),

              // ============================================================
              // RESIDENT & BUILDING DETAILS
              // ============================================================
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'RECEIVED FROM (RESIDENT)',
                            style: const pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey600,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            data.tenantName,
                            style: const pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if (data.tenantGrihoId.isNotEmpty) ...[
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Griho ID: ${data.tenantGrihoId}',
                              style: const pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'PROPERTY & UNIT',
                            style: const pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey600,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            data.propertyName,
                            style: const pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            data.unitName,
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // ============================================================
              // ITEMIZED BILLS TABLE
              // ============================================================
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.6,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      _cell('Description / Bill Type', isHeader: true),
                      _cell('Billing Period', isHeader: true),
                      _cell(
                        'Amount (BDT)',
                        isHeader: true,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                  // Line Items
                  for (final item in data.items)
                    pw.TableRow(
                      children: [
                        _cell(item.title),
                        _cell(item.periodLabel),
                        _cell(
                          _currencyFmt.format(item.amount),
                          align: pw.TextAlign.right,
                        ),
                      ],
                    ),
                ],
              ),

              pw.SizedBox(height: 14),

              // ============================================================
              // TOTAL SUMMARY BOX
              // ============================================================
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 230,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFF1B2232),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'TOTAL PAID',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'BDT ${_currencyFmt.format(data.totalAmount)}',
                        style: const pw.TextStyle(
                          color: PdfColors.amber200,
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (data.note != null && data.note!.trim().isNotEmpty) ...[
                pw.SizedBox(height: 16),
                pw.Text(
                  'Note: ${data.note!.trim()}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],

              pw.Spacer(),

              // ============================================================
              // FOOTER
              // ============================================================
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'This is a computer-generated receipt via Griho.',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    'No physical signature required.',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
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
          fontSize: isHeader ? 10 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.grey900 : PdfColors.grey800,
        ),
      ),
    );
  }

  /// Opens native print / save-as-PDF preview dialog.
  static Future<void> previewOrPrintReceipt(PaymentReceiptData data) async {
    final bytes = await buildReceiptPdf(data);
    await Printing.layoutPdf(
      name: 'Griho_Receipt_${data.receiptNumber}.pdf',
      onLayout: (_) async => bytes,
    );
  }

  /// Shares the generated PDF directly via WhatsApp, Email, etc.
  static Future<void> shareReceiptPdf(PaymentReceiptData data) async {
    final bytes = await buildReceiptPdf(data);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Griho_Receipt_${data.receiptNumber}.pdf',
    );
  }
}
