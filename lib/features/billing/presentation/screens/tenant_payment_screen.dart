// noinspection SpellCheckingInspection
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/services/firebase_storage_service.dart';
import '../../../../core/services/pdf_receipt_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../tenants/presentation/providers/tenant_dashboard_provider.dart';
import '../../data/datasources/payment_workflow_datasource.dart';
import '../../domain/entities/monthly_bill.dart';
import '../providers/monthly_bill_provider.dart';
import '../providers/payment_workflow_provider.dart';
import '../widgets/billing_ui_helpers.dart';

typedef _JsonMap = Map<String, dynamic>;
typedef _DocSnapshot = QueryDocumentSnapshot<_JsonMap>;
typedef _DocList = List<_DocSnapshot>;

typedef _BillList = List<MonthlyBill>;

class TenantPaymentScreen extends ConsumerStatefulWidget {
  const TenantPaymentScreen({super.key});

  @override
  ConsumerState<TenantPaymentScreen> createState() =>
      _TenantPaymentScreenState();
}

class _TenantPaymentScreenState extends ConsumerState<TenantPaymentScreen> {
  final Set<String> _selectedBillIds = <String>{};
  final Set<String> _expandedMonthKeys = <String>{};
  final Set<String> _expandedPaymentGroupIds = <String>{};

  final Map<String, TextEditingController> _amountControllers =
      <String, TextEditingController>{};

  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();
  final _picker = ImagePicker();

  PaymentMethod _method = PaymentMethod.bkash;
  File? _proofImageFile;
  bool _submitting = false;

  @override
  void dispose() {
    for (final controller in _amountControllers.values) {
      controller.dispose();
    }
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double _remaining(MonthlyBill bill) {
    final diff = bill.amount - bill.paidAmount;
    return diff > 0 ? diff : 0.0;
  }

  bool _isPayable(MonthlyBill bill) {
    return bill.status != MonthlyBillStatus.paid &&
        bill.status != MonthlyBillStatus.cancelled &&
        _remaining(bill) > 0.001;
  }

  String _billTitle(MonthlyBill bill) {
    if (bill.title != null && bill.title!.trim().isNotEmpty) {
      return bill.title!.trim();
    }
    return monthlyBillTypeLabel(bill.type);
  }

  TextEditingController _amountControllerFor(MonthlyBill bill) {
    return _amountControllers.putIfAbsent(
      bill.id,
      () => TextEditingController(text: _remaining(bill).toStringAsFixed(2)),
    );
  }

  double _enteredAmount(MonthlyBill bill) {
    return double.tryParse(_amountControllerFor(bill).text.trim()) ?? 0.0;
  }

  double _selectedTotal(List<MonthlyBill> bills) {
    return bills
        .where((bill) => _selectedBillIds.contains(bill.id))
        .fold<double>(0.0, (total, bill) => total + _enteredAmount(bill));
  }

  Future<void> _pickProofImage() async {
    if (_submitting || kIsWeb) {
      return;
    }
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _proofImageFile = File(picked.path));
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, 'Could not select image: $e');
    }
  }

  Future<void> _submit(List<MonthlyBill> payableBills, String tenantUid) async {
    FocusScope.of(context).unfocus();

    final selectedBills = payableBills
        .where((bill) => _selectedBillIds.contains(bill.id))
        .toList();

    if (selectedBills.isEmpty) {
      GrihoFeedback.showWarning(
        context,
        'Please select at least one bill to pay.',
      );
      return;
    }

    final amountsByBillId = <String, double>{};
    final collectionsByBillId = <String, String>{};

    for (final bill in selectedBills) {
      final amount = _enteredAmount(bill);

      if (!amount.isFinite || amount <= 0) {
        GrihoFeedback.showError(
          context,
          'Enter a valid payment amount for ${_billTitle(bill)}.',
        );
        return;
      }

      if (amount > _remaining(bill) + 0.001) {
        GrihoFeedback.showError(
          context,
          'Payment cannot exceed the remaining balance for ${_billTitle(bill)}.',
        );
        return;
      }

      amountsByBillId[bill.id] = amount;
      collectionsByBillId[bill.id] = bill.billCollection;
    }

    final reference = _referenceController.text.trim();
    if (_method != PaymentMethod.cash && reference.isEmpty) {
      GrihoFeedback.showError(
        context,
        'Please enter the transaction/reference ID.',
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      String? uploadedProofUrl;
      if (_proofImageFile != null && !kIsWeb) {
        final sampleBill = selectedBills.first;
        final tempBatchKey = DateTime.now().millisecondsSinceEpoch.toString();
        uploadedProofUrl = await FirebaseStorageService().uploadPaymentProof(
          propertyId: sampleBill.propertyId,
          paymentId: '${tenantUid}_$tempBatchKey',
          imageFile: _proofImageFile!,
        );
      }

      final createdPayments = await ref
          .read(paymentWorkflowDataSourceProvider)
          .submitPayments(
            amountsByBillId: amountsByBillId,
            collectionsByBillId: collectionsByBillId,
            method: _method,
            reference: reference.isEmpty ? null : reference,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            proofUrl: uploadedProofUrl,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedBillIds.clear();
        _proofImageFile = null;
        _referenceController.clear();
        _noteController.clear();
      });

      GrihoFeedback.showSuccess(
        context,
        'Submitted ${createdPayments.length} payment request(s). Pending owner verification.',
      );

      // Note: tenantPaymentTransactionsProvider is a live stream and updates automatically.
      ref.invalidate(currentTenantMonthlyBillsProvider);
      if (tenantUid.isNotEmpty) {
        ref.invalidate(tenantMonthlyBillHistoryProvider(tenantUid));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(
        context,
        'Unable to submit payment: ${cleanBillingError(error)}',
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  // ------------------------------------------------------------
  // MONTHLY INVOICE PDF GENERATOR (FOR OUTSTANDING MONTH GROUP)
  // ------------------------------------------------------------

  Future<void> _exportMonthInvoicePdf(
    _MonthlyPayableGroup group, {
    required bool share,
  }) async {
    try {
      final dashboard = ref.read(tenantDashboardProvider).value;
      final tenant = dashboard?.tenant;
      final property = dashboard?.currentProperty;
      final periodLabel = formatBillingMonthYear(group.billingPeriodStart);

      final items = group.bills
          .map(
            (bill) => ReceiptLineItem(
              title: _billTitle(bill),
              periodLabel: periodLabel,
              amount: bill.amount,
            ),
          )
          .toList();

      final paidAmount = group.bills.fold<double>(
        0.0,
        (sum, bill) => sum + bill.paidAmount,
      );
      final totalDue = group.bills.fold<double>(
        0.0,
        (sum, bill) => sum + _remaining(bill),
      );
      final isOverdue = group.bills.any((b) => b.isOverdue);

      final invoiceNo =
          'INV-${group.billingPeriodStart.year}${group.billingPeriodStart.month.toString().padLeft(2, '0')}';

      final invoiceData = MonthlyInvoicePdfData(
        invoiceNumber: invoiceNo,
        billingPeriodLabel: periodLabel,
        status: totalDue <= 0.001
            ? 'paid'
            : isOverdue
            ? 'overdue'
            : paidAmount > 0
            ? 'partiallyPaid'
            : 'unpaid',
        dueDate: group.dueDate,
        tenantName: dashboard?.displayName ?? tenant?.name ?? 'Resident',
        tenantPhone: tenant?.phone,
        propertyName: dashboard?.currentPropertyName ?? 'Property',
        propertyAddress: property?.address,
        unitName: dashboard?.currentUnitDisplayName ?? 'Unit',
        paidAmount: paidAmount,
        items: items,
      );

      if (share) {
        await PdfReceiptService.shareInvoicePdf(invoiceData);
      } else {
        await PdfReceiptService.previewOrPrintInvoice(invoiceData);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, 'Could not generate invoice PDF: $e');
    }
  }

  // ------------------------------------------------------------
  // PDF RECEIPT GENERATOR FOR PAYMENT GROUP
  // ------------------------------------------------------------

  PaymentReceiptData _buildReceiptData(
    _PaymentGroup group,
    List<MonthlyBill> allBills,
  ) {
    final profile = ref.read(currentUserProfileProvider).value;
    final dashboard = ref.read(tenantDashboardProvider).value;

    final firstData = group.payments.first.data();
    final issuedAt = firstData['createdAt'] is Timestamp
        ? (firstData['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    final items = group.payments.map((doc) {
      final data = doc.data();
      final amount = (data['amount'] is num)
          ? (data['amount'] as num).toDouble()
          : 0.0;
      final title = _paymentBillTitle(data, allBills);
      final periodRaw = data['billingPeriodStart'];
      final periodLabel = periodRaw is Timestamp
          ? formatBillingMonthYear(periodRaw.toDate())
          : 'Monthly Charge';

      return ReceiptLineItem(
        title: title,
        periodLabel: periodLabel,
        amount: amount,
      );
    }).toList();

    final shortReceiptId = group.id.replaceFirst('legacy_', '');
    final receiptNo = shortReceiptId.length > 10
        ? shortReceiptId.substring(0, 10)
        : shortReceiptId;

    return PaymentReceiptData(
      receiptNumber: receiptNo,
      status: group.status,
      issuedAt: issuedAt,
      tenantName: (firstData['tenantName'] ?? profile?.name ?? 'Resident')
          .toString(),
      tenantGrihoId: (firstData['grihoId'] ?? profile?.publicId ?? '')
          .toString(),
      propertyName:
          (firstData['propertyName'] ??
                  dashboard?.currentPropertyName ??
                  'Property')
              .toString(),
      unitName:
          (firstData['unitName'] ?? dashboard?.currentUnitDisplayName ?? 'Unit')
              .toString(),
      paymentMethod: group.method,
      referenceNumber: group.reference,
      note: (firstData['note'] ?? '').toString(),
      items: items,
    );
  }

  Future<void> _openPdfReceipt(
    _PaymentGroup group,
    List<MonthlyBill> allBills, {
    required bool share,
  }) async {
    try {
      final receiptData = _buildReceiptData(group, allBills);
      if (share) {
        await PdfReceiptService.shareReceiptPdf(receiptData);
      } else {
        await PdfReceiptService.previewOrPrintReceipt(receiptData);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, 'Could not generate PDF receipt: $e');
    }
  }

  // ------------------------------------------------------------
  // PAYMENT HISTORY GROUPING
  // ------------------------------------------------------------

  List<_PaymentGroup> _groupPayments(_DocList docs) {
    final grouped = <String, _DocList>{};

    for (final doc in docs) {
      final data = doc.data();
      final batchId = (data['batchId'] ?? '').toString().trim();
      final groupKey = batchId.isNotEmpty ? batchId : 'legacy_${doc.id}';
      grouped.putIfAbsent(groupKey, () => []).add(doc);
    }

    final result = grouped.entries.map((entry) {
      final payments = entry.value
        ..sort(
          (a, b) => _createdAtMillisFromValue(
            b.data()['createdAt'],
          ).compareTo(_createdAtMillisFromValue(a.data()['createdAt'])),
        );

      final totalAmount = payments.fold<double>(0.0, (total, doc) {
        final amount = doc.data()['amount'];
        return total + (amount is num ? amount.toDouble() : 0.0);
      });

      final statuses = payments
          .map(
            (doc) =>
                (doc.data()['status'] ?? 'pending').toString().toLowerCase(),
          )
          .toSet();

      final overallStatus = _resolveGroupStatus(statuses);
      final firstData = payments.first.data();

      return _PaymentGroup(
        id: entry.key,
        payments: payments,
        totalAmount: totalAmount,
        status: overallStatus,
        method: (firstData['method'] ?? 'other').toString(),
        reference: (firstData['reference'] ?? '').toString(),
        createdAt: firstData['createdAt'],
      );
    }).toList();

    result.sort(
      (a, b) => _createdAtMillisFromValue(
        b.createdAt,
      ).compareTo(_createdAtMillisFromValue(a.createdAt)),
    );

    return result;
  }

  int _createdAtMillisFromValue(dynamic value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }
    if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    }
    return 0;
  }

  String _resolveGroupStatus(Set<String> statuses) {
    if (statuses.isEmpty) {
      return 'pending';
    }
    if (statuses.length == 1) {
      return statuses.first;
    }
    if (statuses.every((s) => s == 'confirmed')) {
      return 'confirmed';
    }
    if (statuses.every((s) => s == 'rejected')) {
      return 'rejected';
    }
    if (statuses.contains('pending')) {
      return 'pending';
    }
    return 'partially processed';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return GrihoColors.emerald;
      case 'rejected':
        return GrihoColors.error;
      case 'pending':
        return GrihoColors.warning;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Iconsax.tick_circle;
      case 'rejected':
        return Iconsax.close_circle;
      case 'pending':
        return Iconsax.clock;
      default:
        return Iconsax.info_circle;
    }
  }

  String _paymentBillTitle(Map<String, dynamic> data, List<MonthlyBill> bills) {
    final billId = (data['billId'] ?? '').toString();
    final collection = (data['billCollection'] ?? 'monthlyBills').toString();

    for (final bill in bills) {
      if (bill.id == billId) {
        return _billTitle(bill);
      }
    }

    if (collection == 'monthlyRents') {
      return 'House Rent';
    }
    return (data['billTitle'] ?? 'Utility Bill').toString();
  }

  // ------------------------------------------------------------
  // PAYMENT HISTORY WIDGET
  // ------------------------------------------------------------

  Widget _buildPaymentHistory(
    List<MonthlyBill> bills,
    AsyncValue<PaymentQuerySnapshot> paymentHistory,
  ) {
    final theme = Theme.of(context);

    return paymentHistory.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Text('Unable to load payment history: $error'),
      data: (snapshot) {
        final groups = _groupPayments(snapshot.docs.toList());

        if (groups.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: GrihoStatusState(
              icon: Iconsax.receipt_item,
              title: 'No Payment Submissions',
              subtitle:
                  'Your submitted payments and receipts will appear here.',
            ),
          );
        }

        return Column(
          children: groups.map((group) {
            final statusColor = _statusColor(group.status);
            final statusIcon = _statusIcon(group.status);
            final isExpanded = _expandedPaymentGroupIds.contains(group.id);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedPaymentGroupIds.remove(group.id);
                        } else {
                          _expandedPaymentGroupIds.add(group.id);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: statusColor.withValues(
                              alpha: 0.14,
                            ),
                            child: Icon(
                              statusIcon,
                              color: statusColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '৳${formatBillingAmount(group.totalAmount)}',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    _StatusBadge(
                                      status: group.status,
                                      color: statusColor,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${group.payments.length} bill(s) • '
                                  'Method: ${group.method.toUpperCase()}'
                                  '${group.reference.isNotEmpty ? ' • Ref: ${group.reference}' : ''}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isExpanded
                                ? Iconsax.arrow_up_2
                                : Iconsax.arrow_down_1,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Payment Group Total',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '৳${formatBillingAmount(group.totalAmount)}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _openPdfReceipt(
                                    group,
                                    bills,
                                    share: false,
                                  ),
                                  icon: const Icon(
                                    Iconsax.document_text,
                                    size: 17,
                                  ),
                                  label: const Text('PDF Receipt'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.tonalIcon(
                                  onPressed: () => _openPdfReceipt(
                                    group,
                                    bills,
                                    share: true,
                                  ),
                                  icon: const Icon(Iconsax.export_3, size: 17),
                                  label: const Text('Share Receipt'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Included Bills',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...group.payments.map((paymentDoc) {
                            final data = paymentDoc.data();
                            final amount = data['amount'];
                            final paidAmount = amount is num
                                ? amount.toDouble()
                                : 0.0;
                            final billStatus = (data['status'] ?? 'pending')
                                .toString()
                                .toLowerCase();
                            final billStatusColor = _statusColor(billStatus);
                            final billTitle = _paymentBillTitle(data, bills);
                            final reason = (data['rejectionReason'] ?? '')
                                .toString();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          billTitle,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                      Text(
                                        '৳${formatBillingAmount(paidAmount)}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: _StatusBadge(
                                      status: billStatus,
                                      color: billStatusColor,
                                    ),
                                  ),
                                  if (reason.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Rejection Reason: $reason',
                                      style: const TextStyle(
                                        color: GrihoColors.error,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // MAIN SCREEN
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firebaseUser = ref.watch(currentFirebaseUserProvider);
    final uid = firebaseUser?.uid.trim() ?? '';

    final currentBillsAsync = ref.watch(currentTenantMonthlyBillsProvider);
    final historyBillsAsync = uid.isNotEmpty
        ? ref.watch(tenantMonthlyBillHistoryProvider(uid))
        : const AsyncValue<_BillList>.data(<MonthlyBill>[]);

    final paymentHistory = ref.watch(tenantPaymentTransactionsProvider);

    final isInitialLoading =
        currentBillsAsync.isLoading && !currentBillsAsync.hasValue;

    if (isInitialLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Property Payments')),
        body: const GrihoLoadingView(message: 'Loading your bills...'),
      );
    }

    if (currentBillsAsync.hasError && !currentBillsAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(title: const Text('Property Payments')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load bills',
              subtitle: currentBillsAsync.error.toString(),
              actionLabel: 'Retry',
              onAction: () {
                ref.invalidate(currentTenantMonthlyBillsProvider);
                if (uid.isNotEmpty) {
                  ref.invalidate(tenantMonthlyBillHistoryProvider(uid));
                }
              },
            ),
          ),
        ),
      );
    }

    final allBillsMap = <String, MonthlyBill>{};
    for (final bill in historyBillsAsync.value ?? const <MonthlyBill>[]) {
      allBillsMap[bill.id] = bill;
    }
    for (final bill in currentBillsAsync.value ?? const <MonthlyBill>[]) {
      allBillsMap[bill.id] = bill;
    }

    final allBills = allBillsMap.values.toList();
    final payableBills = allBills.where(_isPayable).toList();

    _selectedBillIds.removeWhere(
      (id) => !payableBills.any((bill) => bill.id == id),
    );

    for (final bill in payableBills) {
      _amountControllerFor(bill);
    }

    final monthlyGroupsMap = <String, _BillList>{};
    for (final bill in payableBills) {
      final key =
          '${bill.billingPeriodStart.year}-${bill.billingPeriodStart.month.toString().padLeft(2, '0')}';
      monthlyGroupsMap.putIfAbsent(key, () => <MonthlyBill>[]).add(bill);
    }

    final monthlyGroups =
        monthlyGroupsMap.entries.map((entry) {
          final billsInMonth = entry.value
            ..sort((a, b) {
              final isRentA = a.type == MonthlyBillType.rent ? 0 : 1;
              final isRentB = b.type == MonthlyBillType.rent ? 0 : 1;
              if (isRentA != isRentB) {
                return isRentA.compareTo(isRentB);
              }
              return a.type.name.compareTo(b.type.name);
            });

          return _MonthlyPayableGroup(
            periodKey: entry.key,
            billingPeriodStart: billsInMonth.first.billingPeriodStart,
            dueDate: billsInMonth.first.dueDate,
            bills: billsInMonth,
          );
        }).toList()..sort(
          (a, b) => a.billingPeriodStart.compareTo(b.billingPeriodStart),
        );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Property Payments')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentTenantMonthlyBillsProvider);
          if (uid.isNotEmpty) {
            ref.invalidate(tenantMonthlyBillHistoryProvider(uid));
          }
          await ref.read(currentTenantMonthlyBillsProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Iconsax.info_circle,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart Bill & Rent Payment',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select overdue bills, current month charges, or upcoming invoices below. You can pay partial or full amounts and download PDF invoices.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Outstanding Invoices',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (payableBills.isNotEmpty)
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () {
                              setState(() {
                                if (_selectedBillIds.length ==
                                    payableBills.length) {
                                  _selectedBillIds.clear();
                                } else {
                                  _selectedBillIds
                                    ..clear()
                                    ..addAll(
                                      payableBills.map((bill) => bill.id),
                                    );
                                  _expandedMonthKeys.addAll(
                                    monthlyGroups.map((g) => g.periodKey),
                                  );
                                }
                              });
                            },
                      child: Text(
                        _selectedBillIds.length == payableBills.length
                            ? 'Deselect All'
                            : 'Select All',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (payableBills.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: GrihoStatusState(
                    icon: Iconsax.tick_circle,
                    title: 'All Caught Up!',
                    subtitle: 'No outstanding bills or rent found.',
                  ),
                )
              else ...[
                ...monthlyGroups.map(_buildMonthCollapsibleCard),
                const SizedBox(height: 12),
                if (_selectedBillIds.isNotEmpty)
                  GrihoSectionCard(
                    title: 'Payment Summary & Method',
                    icon: Iconsax.wallet_3,
                    children: [
                      _InfoRow(
                        label: 'Selected Charges Count',
                        value: '${_selectedBillIds.length}',
                      ),
                      const SizedBox(height: 6),
                      _InfoRow(
                        label: 'Total Payable Amount',
                        value:
                            '৳${formatBillingAmount(_selectedTotal(payableBills))}',
                        isHighlight: true,
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<PaymentMethod>(
                        initialValue: _method,
                        decoration: const InputDecoration(
                          labelText: 'Payment Method',
                          prefixIcon: Icon(
                            Iconsax.wallet_3,
                            color: GrihoColors.emerald,
                            size: 19,
                          ),
                        ),
                        items: PaymentMethod.values.map((method) {
                          return DropdownMenuItem<PaymentMethod>(
                            value: method,
                            child: Text(_methodLabel(method)),
                          );
                        }).toList(),
                        onChanged: _submitting
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _method = value);
                                }
                              },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _referenceController,
                        enabled: !_submitting,
                        decoration: InputDecoration(
                          labelText: _method == PaymentMethod.cash
                              ? 'Receipt / Reference Number (Optional)'
                              : 'Transaction ID / TrxID *',
                          hintText: _method == PaymentMethod.bkash
                              ? 'e.g. 9H74X... (bKash TrxID)'
                              : _method == PaymentMethod.nagad
                              ? 'e.g. NAGAD1234...'
                              : 'Enter transaction reference',
                          prefixIcon: const Icon(
                            Iconsax.receipt_item,
                            color: GrihoColors.emerald,
                            size: 19,
                          ),
                        ),
                      ),
                      if (!kIsWeb) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _submitting ? null : _pickProofImage,
                                icon: const Icon(Iconsax.gallery, size: 17),
                                label: Text(
                                  _proofImageFile == null
                                      ? 'Attach Receipt Screenshot (Optional)'
                                      : 'Screenshot Attached',
                                ),
                              ),
                            ),
                            if (_proofImageFile != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Remove screenshot',
                                onPressed: _submitting
                                    ? null
                                    : () => setState(
                                        () => _proofImageFile = null,
                                      ),
                                icon: const Icon(
                                  Iconsax.close_circle,
                                  color: GrihoColors.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _noteController,
                        enabled: !_submitting,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Note for Owner (Optional)',
                          hintText: 'Add any details regarding this payment...',
                          prefixIcon: Icon(
                            Iconsax.edit_2,
                            color: GrihoColors.emerald,
                            size: 19,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      GrihoPrimaryButton(
                        label: _submitting
                            ? 'Submitting Payments...'
                            : 'Submit All Selected Payments',
                        icon: Iconsax.wallet_check,
                        isLoading: _submitting,
                        onPressed: () => _submit(payableBills, uid),
                      ),
                    ],
                  ),
              ],
              const SizedBox(height: 28),
              Text(
                'Payment History & Submissions',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildPaymentHistory(allBills, paymentHistory),
              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // COLLAPSIBLE MONTH CARD (WITH INVOICE PDF EXPORT)
  // ------------------------------------------------------------

  Widget _buildMonthCollapsibleCard(_MonthlyPayableGroup group) {
    final theme = Theme.of(context);

    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final monthStart = DateTime(
      group.billingPeriodStart.year,
      group.billingPeriodStart.month,
      1,
    );

    final String badgeText;
    final Color badgeColor;

    if (monthStart.isBefore(currentMonthStart)) {
      badgeText = 'OVERDUE';
      badgeColor = GrihoColors.error;
    } else if (monthStart.isAtSameMomentAs(currentMonthStart)) {
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime(
        group.dueDate.year,
        group.dueDate.month,
        group.dueDate.day,
      );

      if (today.isAfter(due)) {
        badgeText = 'CURRENT (OVERDUE)';
        badgeColor = GrihoColors.error;
      } else {
        badgeText = 'CURRENT MONTH';
        badgeColor = theme.colorScheme.primary;
      }
    } else {
      badgeText = 'UPCOMING';
      badgeColor = Colors.purple;
    }

    final totalMonthAmount = group.bills.fold<double>(
      0.0,
      (total, b) => total + b.amount,
    );
    final totalMonthDue = group.bills.fold<double>(
      0.0,
      (total, b) => total + _remaining(b),
    );

    final allSelectedInMonth = group.bills.every(
      (b) => _selectedBillIds.contains(b.id),
    );
    final isExpanded = _expandedMonthKeys.contains(group.periodKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: monthStart.isBefore(currentMonthStart)
              ? GrihoColors.error.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedMonthKeys.remove(group.periodKey);
                } else {
                  _expandedMonthKeys.add(group.periodKey);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      monthStart.isBefore(currentMonthStart)
                          ? Iconsax.warning_2
                          : monthStart.isAfter(currentMonthStart)
                          ? Iconsax.calendar_1
                          : Iconsax.receipt_item,
                      color: badgeColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                formatBillingMonthYear(
                                  group.billingPeriodStart,
                                ),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _StatusBadge(status: badgeText, color: badgeColor),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Due: ${formatBillingShortDate(group.dueDate)} • ${group.bills.length} charge(s)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '৳${formatBillingAmount(totalMonthDue)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: totalMonthDue > 0
                                    ? GrihoColors.error
                                    : GrihoColors.emerald,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Iconsax.arrow_up_2 : Iconsax.arrow_down_1,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Total: ৳${formatBillingAmount(totalMonthAmount)} • Due: ৳${formatBillingAmount(totalMonthDue)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () {
                                setState(() {
                                  if (allSelectedInMonth) {
                                    for (final b in group.bills) {
                                      _selectedBillIds.remove(b.id);
                                    }
                                  } else {
                                    for (final b in group.bills) {
                                      _selectedBillIds.add(b.id);
                                    }
                                  }
                                });
                              },
                        child: Text(
                          allSelectedInMonth
                              ? 'Deselect Month'
                              : 'Select Month',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _exportMonthInvoicePdf(group, share: false),
                          icon: const Icon(Iconsax.document_text, size: 16),
                          label: const Text('Invoice PDF'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () =>
                              _exportMonthInvoicePdf(group, share: true),
                          icon: const Icon(Iconsax.export_3, size: 16),
                          label: const Text('Share Invoice'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...group.bills.map((bill) {
                    final selected = _selectedBillIds.contains(bill.id);
                    final controller = _amountControllerFor(bill);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.primaryContainer.withValues(
                                alpha: 0.25,
                              )
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: selected,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: _submitting
                                      ? null
                                      : (value) {
                                          setState(() {
                                            if (value == true) {
                                              _selectedBillIds.add(bill.id);
                                            } else {
                                              _selectedBillIds.remove(bill.id);
                                            }
                                          });
                                        },
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _billTitle(bill),
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Total: ৳${formatBillingAmount(bill.amount)} • Paid: ৳${formatBillingAmount(bill.paidAmount)}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontSize: 11,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: GrihoColors.error.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Due: ৳${formatBillingAmount(_remaining(bill))}',
                                    style: const TextStyle(
                                      color: GrihoColors.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (selected) ...[
                              const Divider(height: 16),
                              TextField(
                                controller: controller,
                                enabled: !_submitting,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}'),
                                  ),
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Enter Payment Amount (৳)',
                                  helperText:
                                      'Maximum payable: ৳${formatBillingAmount(_remaining(bill))}',
                                  prefixIcon: const Icon(
                                    Iconsax.money_2,
                                    color: GrihoColors.emerald,
                                    size: 19,
                                  ),
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _methodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash Payment';
      case PaymentMethod.bank:
        return 'Bank Transfer';
      case PaymentMethod.bkash:
        return 'bKash';
      case PaymentMethod.nagad:
        return 'Nagad';
      case PaymentMethod.other:
        return 'Other Method';
    }
  }
}

class _MonthlyPayableGroup {
  final String periodKey;
  final DateTime billingPeriodStart;
  final DateTime dueDate;
  final _BillList bills;

  const _MonthlyPayableGroup({
    required this.periodKey,
    required this.billingPeriodStart,
    required this.dueDate,
    required this.bills,
  });
}

class _PaymentGroup {
  const _PaymentGroup({
    required this.id,
    required this.payments,
    required this.totalAmount,
    required this.status,
    required this.method,
    required this.reference,
    required this.createdAt,
  });

  final String id;
  final _DocList payments;
  final double totalAmount;
  final String status;
  final String method;
  final String reference;
  final dynamic createdAt;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  final String label;
  final String value;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isHighlight
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isHighlight ? 16 : 14,
            color: isHighlight
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
