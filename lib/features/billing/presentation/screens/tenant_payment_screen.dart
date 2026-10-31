import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/payment_workflow_datasource.dart';
import '../../domain/entities/monthly_bill.dart';
import '../../../tenants/presentation/providers/tenant_dashboard_provider.dart';
import '../providers/payment_workflow_provider.dart';

class TenantPaymentScreen extends ConsumerStatefulWidget {
  const TenantPaymentScreen({super.key});

  @override
  ConsumerState<TenantPaymentScreen> createState() =>
      _TenantPaymentScreenState();
}

class _TenantPaymentScreenState extends ConsumerState<TenantPaymentScreen> {
  final Set<String> _selectedBillIds = <String>{};

  final Map<String, TextEditingController> _amountControllers =
      <String, TextEditingController>{};

  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();

  PaymentMethod _method = PaymentMethod.bkash;
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
    return (bill.amount - bill.paidAmount)
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  String _money(double amount) {
    return amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
  }

  String _billTitle(MonthlyBill bill) {
    const names = {
      MonthlyBillType.rent: 'Rent',
      MonthlyBillType.water: 'Water',
      MonthlyBillType.gas: 'Gas',
      MonthlyBillType.garbage: 'Garbage',
      MonthlyBillType.serviceCharge: 'Service Charge',
      MonthlyBillType.electricity: 'Electricity',
      MonthlyBillType.other: 'Other Charge',
    };

    return names[bill.type] ?? bill.type.name;
  }

  TextEditingController _amountControllerFor(MonthlyBill bill) {
    return _amountControllers.putIfAbsent(
      bill.id,
      () => TextEditingController(text: _remaining(bill).toStringAsFixed(2)),
    );
  }

  double _enteredAmount(MonthlyBill bill) {
    return double.tryParse(_amountControllerFor(bill).text.trim()) ?? 0;
  }

  double _selectedTotal(List<MonthlyBill> bills) {
    return bills
        .where((bill) => _selectedBillIds.contains(bill.id))
        .fold<double>(0, (total, bill) => total + _enteredAmount(bill));
  }

  Future<void> _submit(List<MonthlyBill> payableBills) async {
    final selectedBills = payableBills
        .where((bill) => _selectedBillIds.contains(bill.id))
        .toList();

    if (selectedBills.isEmpty) {
      _message('Please select at least one bill to pay.');
      return;
    }

    final amountsByBillId = <String, double>{};
    final collectionsByBillId = <String, String>{};

    for (final bill in selectedBills) {
      final amount = _enteredAmount(bill);

      if (!amount.isFinite || amount <= 0) {
        _message('Enter a valid payment amount for ${_billTitle(bill)}.');
        return;
      }

      if (amount > _remaining(bill) + 0.001) {
        _message(
          'Payment cannot exceed the remaining balance for ${_billTitle(bill)}.',
        );
        return;
      }

      amountsByBillId[bill.id] = amount;
      collectionsByBillId[bill.id] = bill.billCollection;
    }

    final reference = _referenceController.text.trim();

    if (_method != PaymentMethod.cash && reference.isEmpty) {
      _message('Please enter the transaction/reference ID.');
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
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
          );

      if (!mounted) return;

      setState(() {
        _selectedBillIds.clear();

        for (final bill in selectedBills) {
          _amountControllers[bill.id]?.text = _remaining(
            bill,
          ).toStringAsFixed(2);
        }

        _referenceController.clear();
        _noteController.clear();
      });

      _message(
        'Successfully submitted ${createdPayments.length} payment request(s). '
        'They are pending owner verification.',
      );

      ref.invalidate(tenantPaymentTransactionsProvider);
      ref.invalidate(currentTenantMonthlyBillsProvider);
    } catch (error) {
      if (!mounted) return;

      _message('Unable to submit payment: ${_friendlyError(error)}');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst('Bad state: ', '');
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------
  // PAYMENT HISTORY GROUPING
  // ------------------------------------------------------------

  List<_PaymentGroup> _groupPayments(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final grouped =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

    for (final doc in docs) {
      final data = doc.data();

      // New payments should contain a common batchId.
      // Legacy payments without batchId remain individual groups.
      final batchId = (data['batchId'] ?? '').toString().trim();

      final groupKey = batchId.isNotEmpty ? batchId : 'legacy_${doc.id}';

      grouped.putIfAbsent(groupKey, () => []).add(doc);
    }

    final result = grouped.entries.map((entry) {
      final payments = entry.value;

      payments.sort((a, b) {
        return _createdAtMillis(b.data()).compareTo(_createdAtMillis(a.data()));
      });

      final totalAmount = payments.fold<double>(0, (total, doc) {
        final amount = doc.data()['amount'];
        return total + (amount is num ? amount.toDouble() : 0);
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

  int _createdAtMillis(Map<String, dynamic> data) {
    return _createdAtMillisFromValue(data['createdAt']);
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
    if (statuses.isEmpty) return 'pending';

    if (statuses.length == 1) {
      return statuses.first;
    }

    if (statuses.every((status) => status == 'confirmed')) {
      return 'confirmed';
    }

    if (statuses.every((status) => status == 'rejected')) {
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
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'pending':
        return Icons.hourglass_top_rounded;
      default:
        return Icons.info_outline_rounded;
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
      return 'Rent';
    }

    return 'Bill';
  }

  // ------------------------------------------------------------
  // PAYMENT HISTORY CARD
  // ------------------------------------------------------------

  Widget _buildPaymentHistory(
    List<MonthlyBill> bills,
    AsyncValue<QuerySnapshot<Map<String, dynamic>>> paymentHistory,
  ) {
    final theme = Theme.of(context);

    return paymentHistory.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, _) => Text('Unable to load payment history: $error'),
      data: (snapshot) {
        final docs = snapshot.docs.toList();
        final groups = _groupPayments(docs);

        if (groups.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Text(
              'No payment submissions yet.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          );
        }

        return Column(
          children: groups.map((group) {
            final statusColor = _statusColor(group.status);
            final statusIcon = _statusIcon(group.status);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: PageStorageKey<String>('payment_${group.id}'),
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.15),
                    child: Icon(statusIcon, color: statusColor),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '৳${_money(group.totalAmount)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _StatusBadge(status: group.status, color: statusColor),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${group.payments.length} bill(s) • '
                      'Method: ${group.method.toUpperCase()}'
                      '${group.reference.isNotEmpty ? ' • Ref: ${group.reference}' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
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
                          '৳${_money(group.totalAmount)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
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

                      final collection =
                          (data['billCollection'] ?? 'monthlyBills').toString();

                      final reason = (data['rejectionReason'] ?? '').toString();

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
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  '৳${_money(paidAmount)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Collection: $collection',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                                _StatusBadge(
                                  status: billStatus,
                                  color: billStatusColor,
                                ),
                              ],
                            ),

                            if (reason.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Rejection Reason: $reason',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                    if (group.payments.length > 1) ...[
                      const Divider(height: 20),
                      _InfoRow(
                        label: 'Total Submitted Bills',
                        value: '${group.payments.length}',
                      ),
                      const SizedBox(height: 6),
                      _InfoRow(
                        label: 'Combined Payment Amount',
                        value: '৳${_money(group.totalAmount)}',
                        isHighlight: true,
                      ),
                    ],
                  ],
                ),
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

    final billsAsync = ref.watch(currentTenantMonthlyBillsProvider);

    final paymentHistory = ref.watch(tenantPaymentTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Property Payments',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: billsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: 'Unable to load your bills: $error',
          onRetry: () {
            ref.invalidate(currentTenantMonthlyBillsProvider);
          },
        ),
        data: (bills) {
          final payableBills = bills
              .where(
                (bill) =>
                    bill.status != MonthlyBillStatus.paid &&
                    bill.status != MonthlyBillStatus.cancelled &&
                    _remaining(bill) > 0,
              )
              .toList();

          _selectedBillIds.removeWhere(
            (id) => !payableBills.any((bill) => bill.id == id),
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // INFORMATION CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Smart Bill Payment',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select one or multiple bills below, enter payment amounts, and submit. The property owner will review and verify them.',
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

              // OUTSTANDING BILLS HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Outstanding Bills',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (payableBills.isNotEmpty)
                    TextButton.icon(
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
                                }
                              });
                            },
                      icon: Icon(
                        _selectedBillIds.length == payableBills.length
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _selectedBillIds.length == payableBills.length
                            ? 'Deselect All'
                            : 'Select All',
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // EMPTY BILLS
              if (payableBills.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 48,
                          color: Colors.green,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'All caught up! No outstanding bills found.',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // INDIVIDUAL SELECTABLE BILLS
                ...payableBills.map((bill) {
                  final selected = _selectedBillIds.contains(bill.id);

                  final controller = _amountControllerFor(bill);

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _billTitle(bill),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Total: ৳${_money(bill.amount)}  •  '
                                      'Paid: ৳${_money(bill.paidAmount)}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer
                                      .withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Due: ৳${_money(_remaining(bill))}',
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (selected) ...[
                            const Divider(height: 20),
                            TextField(
                              controller: controller,
                              enabled: !_submitting,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Enter Payment Amount (৳)',
                                helperText:
                                    'Maximum payable: ৳${_money(_remaining(bill))}',
                                prefixIcon: const Icon(Icons.payment_rounded),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
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

                const SizedBox(height: 12),

                // PAYMENT SUMMARY
                if (_selectedBillIds.isNotEmpty) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Summary & Method',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const Divider(height: 20),

                          _InfoRow(
                            label: 'Selected Bills Count',
                            value: '${_selectedBillIds.length}',
                          ),

                          const SizedBox(height: 6),

                          _InfoRow(
                            label: 'Total Payable Amount',
                            value: '৳${_money(_selectedTotal(payableBills))}',
                            isHighlight: true,
                          ),

                          const SizedBox(height: 20),

                          DropdownButtonFormField<PaymentMethod>(
                            initialValue: _method,
                            decoration: InputDecoration(
                              labelText: 'Payment Method',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(
                                Icons.account_balance_wallet_rounded,
                              ),
                              isDense: true,
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
                                      setState(() {
                                        _method = value;
                                      });
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
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(
                                Icons.receipt_long_rounded,
                              ),
                              isDense: true,
                            ),
                          ),

                          const SizedBox(height: 16),

                          TextField(
                            controller: _noteController,
                            enabled: !_submitting,
                            maxLines: 2,
                            decoration: InputDecoration(
                              labelText: 'Note for Owner (Optional)',
                              hintText:
                                  'Add any details regarding this payment...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.note_alt_rounded),
                            ),
                          ),

                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton(
                              onPressed: _submitting
                                  ? null
                                  : () => _submit(payableBills),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_submitting) ...[
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ] else ...[
                                    const Icon(Icons.send_rounded, size: 18),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    _submitting
                                        ? 'Submitting Payments...'
                                        : 'Submit All Selected Payments',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 32),

              // PAYMENT HISTORY HEADER
              Text(
                'Payment History & Status',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // GROUPED PAYMENT HISTORY
              _buildPaymentHistory(bills, paymentHistory),

              const SizedBox(height: 36),
            ],
          );
        },
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

// ------------------------------------------------------------
// PAYMENT GROUP MODEL
// ------------------------------------------------------------

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

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> payments;

  final double totalAmount;

  final String status;

  final String method;

  final String reference;

  final dynamic createdAt;
}

// ------------------------------------------------------------
// STATUS BADGE
// ------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.color});

  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
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

// ------------------------------------------------------------
// INFO ROW
// ------------------------------------------------------------

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
        Text(
          label,
          style: TextStyle(
            color: isHighlight
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
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

// ------------------------------------------------------------
// ERROR STATE
// ------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
