import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../tenants/presentation/providers/tenant_dashboard_provider.dart';
import '../../data/datasources/payment_workflow_datasource.dart';
import '../../domain/entities/monthly_bill.dart';
import '../providers/monthly_bill_provider.dart';
import '../providers/payment_workflow_provider.dart';

typedef _DocList = List<QueryDocumentSnapshot>;
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

  Map<String, dynamic> _docData(QueryDocumentSnapshot doc) {
    final raw = doc.data();
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  double _remaining(MonthlyBill bill) {
    final diff = bill.amount - bill.paidAmount;
    return diff > 0 ? diff : 0.0;
  }

  bool _isPayable(MonthlyBill bill) {
    // 1. যদি বিলটি ইতিমধ্যে সম্পূর্ণ পেইড বা ক্যানসেল হয়, তবে দেখাবে না।
    if (bill.status == MonthlyBillStatus.paid ||
        bill.status == MonthlyBillStatus.cancelled ||
        _remaining(bill) <= 0.001) {
      return false;
    }

    return true;
  }

  String _money(double amount) {
    return amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
  }

  String _billTitle(MonthlyBill bill) {
    if (bill.title != null && bill.title!.trim().isNotEmpty) {
      return bill.title!.trim();
    }

    switch (bill.type) {
      case MonthlyBillType.rent:
        return 'House Rent';
      case MonthlyBillType.water:
        return 'Water Bill';
      case MonthlyBillType.gas:
        return 'Gas Bill';
      case MonthlyBillType.garbage:
        return 'Garbage Bill';
      case MonthlyBillType.serviceCharge:
        return 'Service Charge';
      case MonthlyBillType.electricity:
        return 'Electricity Bill';
      case MonthlyBillType.other:
        return 'Other Charge';
    }
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

  Future<void> _submit(List<MonthlyBill> payableBills, String tenantUid) async {
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
      if (tenantUid.isNotEmpty) {
        ref.invalidate(tenantMonthlyBillHistoryProvider(tenantUid));
      }
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

  List<_PaymentGroup> _groupPayments(_DocList docs) {
    final grouped = <String, _DocList>{};

    for (final doc in docs) {
      final data = _docData(doc);
      final batchId = (data['batchId'] ?? '').toString().trim();
      final groupKey = batchId.isNotEmpty ? batchId : 'legacy_${doc.id}';

      grouped.putIfAbsent(groupKey, () => <QueryDocumentSnapshot>[]).add(doc);
    }

    final result = grouped.entries.map((entry) {
      final payments = entry.value;

      payments.sort((a, b) {
        return _createdAtMillis(
          _docData(b),
        ).compareTo(_createdAtMillis(_docData(a)));
      });

      final totalAmount = payments.fold<double>(0.0, (total, doc) {
        final data = _docData(doc);
        final amount = data['amount'];
        return total + (amount is num ? amount.toDouble() : 0.0);
      });

      final statuses = payments
          .map(
            (doc) =>
                (_docData(doc)['status'] ?? 'pending').toString().toLowerCase(),
          )
          .toSet();

      final overallStatus = _resolveGroupStatus(statuses);
      final firstData = _docData(payments.first);

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
    if (statuses.length == 1) return statuses.first;
    if (statuses.every((status) => status == 'confirmed')) return 'confirmed';
    if (statuses.every((status) => status == 'rejected')) return 'rejected';
    if (statuses.contains('pending')) return 'pending';
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
      return 'House Rent';
    }

    return 'Bill';
  }

  // ------------------------------------------------------------
  // PAYMENT HISTORY WIDGET (CUSTOM COLLAPSIBLE)
  // ------------------------------------------------------------

  Widget _buildPaymentHistory(
    List<MonthlyBill> bills,
    AsyncValue<QuerySnapshot> paymentHistory,
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
            final isExpanded = _expandedPaymentGroupIds.contains(group.id);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
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
                              alpha: 0.15,
                            ),
                            child: Icon(statusIcon, color: statusColor),
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
                                        '৳${_money(group.totalAmount)}',
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
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
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
                            final data = _docData(paymentDoc);
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
                                (data['billCollection'] ?? 'monthlyBills')
                                    .toString();
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
                                        '৳${_money(paidAmount)}',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
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
        appBar: AppBar(
          title: const Text(
            'Property Payments',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (currentBillsAsync.hasError && !currentBillsAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Property Payments',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: _ErrorState(
          message: 'Unable to load your bills: ${currentBillsAsync.error}',
          onRetry: () {
            ref.invalidate(currentTenantMonthlyBillsProvider);
            if (uid.isNotEmpty) {
              ref.invalidate(tenantMonthlyBillHistoryProvider(uid));
            }
          },
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

    // Pre-initialize controllers so no new controller creation happens mid-frame
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
          final billsInMonth = entry.value;

          billsInMonth.sort((a, b) {
            final isRentA = a.type == MonthlyBillType.rent ? 0 : 1;
            final isRentB = b.type == MonthlyBillType.rent ? 0 : 1;
            if (isRentA != isRentB) return isRentA.compareTo(isRentB);
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
      appBar: AppBar(
        title: const Text(
          'Property Payments',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                          'Smart Bill & Rent Payment',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Select previous overdue bills, current month charges, or upcoming invoices below. You can pay partial or full amounts.',
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
                                  ..addAll(payableBills.map((bill) => bill.id));
                                // Auto-expand all months when Select All is pressed
                                _expandedMonthKeys.addAll(
                                  monthlyGroups.map((g) => g.periodKey),
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
                        'All caught up! No outstanding bills or rent found.',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              ...monthlyGroups.map(_buildMonthCollapsibleCard),

              const SizedBox(height: 12),

              if (_selectedBillIds.isNotEmpty)
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
                          label: 'Selected Charges Count',
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
                            prefixIcon: const Icon(Icons.receipt_long_rounded),
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
                                : () => _submit(payableBills, uid),
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

            const SizedBox(height: 32),

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
    );
  }

  // ------------------------------------------------------------
  // CUSTOM COLLAPSIBLE MONTH CARD (NO EXPANSIONTILE CRASH)
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
      badgeText = 'OVERDUE / PREVIOUS';
      badgeColor = Colors.red;
    } else if (monthStart.isAtSameMomentAs(currentMonthStart)) {
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime(
        group.dueDate.year,
        group.dueDate.month,
        group.dueDate.day,
      );

      if (today.isAfter(due)) {
        badgeText = 'CURRENT (OVERDUE)';
        badgeColor = Colors.red.shade700;
      } else {
        badgeText = 'CURRENT MONTH';
        badgeColor = theme.colorScheme.primary;
      }
    } else {
      badgeText = 'UPCOMING / NEXT MONTH';
      badgeColor = Colors.purple;
    }

    final totalMonthAmount = group.bills.fold<double>(
      0.0,
      (s, b) => s + b.amount,
    );
    final totalMonthDue = group.bills.fold<double>(
      0.0,
      (s, b) => s + _remaining(b),
    );

    final allSelectedInMonth = group.bills.every(
      (b) => _selectedBillIds.contains(b.id),
    );

    final isExpanded = _expandedMonthKeys.contains(group.periodKey);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: monthStart.isBefore(currentMonthStart)
              ? Colors.red.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Collapsible Header
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
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      monthStart.isBefore(currentMonthStart)
                          ? Icons.warning_amber_rounded
                          : monthStart.isAfter(currentMonthStart)
                          ? Icons.calendar_month_outlined
                          : Icons.receipt_long_rounded,
                      color: badgeColor,
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
                                _formatMonthYear(group.billingPeriodStart),
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
                                'Due: ${_formatDueDate(group.dueDate)} • ${group.bills.length} charge(s)',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '৳${_money(totalMonthDue)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: totalMonthDue > 0
                                    ? theme.colorScheme.error
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Body
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
                          'Total: ৳${_money(totalMonthAmount)} • Remaining: ৳${_money(totalMonthDue)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
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
                              : 'Select Whole Month',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...group.bills.map((bill) {
                    final selected = _selectedBillIds.contains(bill.id);
                    final controller = _amountControllerFor(bill);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.5)
                            : theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          width: selected ? 2 : 1,
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
                                        'Total: ৳${_money(bill.amount)} • Paid: ৳${_money(bill.paidAmount)}',
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
                                    color: theme.colorScheme.errorContainer
                                        .withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Due: ৳${_money(_remaining(bill))}',
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
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
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDueDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
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
// HELPER MODELS & WIDGETS
// ------------------------------------------------------------

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
