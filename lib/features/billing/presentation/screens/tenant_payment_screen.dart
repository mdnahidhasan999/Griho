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
  String? _selectedBillId;

  PaymentMethod _method = PaymentMethod.bkash;

  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
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
      MonthlyBillType.serviceCharge: 'Service charge',
      MonthlyBillType.electricity: 'Electricity',
      MonthlyBillType.other: 'Other charge',
    };

    return names[bill.type] ?? bill.type.name;
  }

  Future<void> _submit(List<MonthlyBill> bills) async {
    final matchingBills = bills.where((bill) => bill.id == _selectedBillId);

    final selected = matchingBills.isEmpty ? null : matchingBills.first;

    if (selected == null) {
      _message('Select a bill first.');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || !amount.isFinite || amount <= 0) {
      _message('Enter a valid payment amount.');
      return;
    }

    if (amount > _remaining(selected) + 0.001) {
      _message('Payment cannot exceed the remaining balance.');
      return;
    }

    final reference = _referenceController.text.trim();

    if (_method != PaymentMethod.cash && reference.isEmpty) {
      _message('Enter the transaction/reference ID.');
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await ref
          .read(paymentWorkflowDataSourceProvider)
          .submitPayment(
            billId: selected.id,
            amount: amount,
            method: _method,
            reference: reference.isEmpty ? null : reference,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );

      if (!mounted) return;

      _amountController.clear();
      _referenceController.clear();
      _noteController.clear();

      _message(
        'Payment submitted. It will remain pending until '
        'the owner verifies it.',
      );
    } catch (error) {
      if (mounted) {
        _message(error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(currentTenantMonthlyBillsProvider);

    final paymentHistory = ref.watch(tenantPaymentTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
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

          if (_selectedBillId == null ||
              !payableBills.any((bill) => bill.id == _selectedBillId)) {
            _selectedBillId = payableBills.isEmpty
                ? null
                : payableBills.first.id;

            final selected = payableBills.isEmpty ? null : payableBills.first;

            if (selected != null && _amountController.text.isEmpty) {
              _amountController.text = _remaining(selected).toStringAsFixed(2);
            }
          }

          final selectedBillMatches = payableBills.where(
            (bill) => bill.id == _selectedBillId,
          );

          final selectedBill = selectedBillMatches.isEmpty
              ? null
              : selectedBillMatches.first;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pay a bill',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Submit your payment details after sending '
                        'the money to the account provided by your '
                        'property owner. A submitted payment is not '
                        'considered paid until it is verified.',
                      ),
                      const SizedBox(height: 16),

                      if (payableBills.isEmpty)
                        const Text(
                          'There are no outstanding bills '
                          'available for payment.',
                        )
                      else ...[
                        DropdownButtonFormField<String>(
                          initialValue: _selectedBillId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Select bill',
                            border: OutlineInputBorder(),
                          ),
                          items: payableBills.map((bill) {
                            return DropdownMenuItem<String>(
                              value: bill.id,
                              child: Text(
                                '${_billTitle(bill)} • '
                                'Due ৳${_money(_remaining(bill))}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: _submitting
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedBillId = value;

                                    final matching = payableBills.where(
                                      (bill) => bill.id == value,
                                    );

                                    final bill = matching.isEmpty
                                        ? null
                                        : matching.first;

                                    _amountController.text = bill == null
                                        ? ''
                                        : _remaining(bill).toStringAsFixed(2);
                                  });
                                },
                        ),

                        if (selectedBill != null) ...[
                          const SizedBox(height: 10),
                          _InfoRow(
                            label: 'Bill amount',
                            value: '৳${_money(selectedBill.amount)}',
                          ),
                          _InfoRow(
                            label: 'Already paid',
                            value: '৳${_money(selectedBill.paidAmount)}',
                          ),
                          _InfoRow(
                            label: 'Remaining due',
                            value: '৳${_money(_remaining(selectedBill))}',
                          ),
                        ],

                        const SizedBox(height: 12),

                        DropdownButtonFormField<PaymentMethod>(
                          initialValue: _method,
                          decoration: const InputDecoration(
                            labelText: 'Payment method',
                            border: OutlineInputBorder(),
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

                        const SizedBox(height: 12),

                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount paid (৳)',
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 12),

                        TextField(
                          controller: _referenceController,
                          decoration: InputDecoration(
                            labelText: _method == PaymentMethod.cash
                                ? 'Reference / receipt number (optional)'
                                : 'Transaction / reference ID *',
                            hintText: _method == PaymentMethod.bkash
                                ? 'bKash TrxID'
                                : _method == PaymentMethod.nagad
                                ? 'Nagad TrxID'
                                : 'Bank transaction/reference number',
                            border: const OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 12),

                        TextField(
                          controller: _noteController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Note (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _submitting
                                ? null
                                : () => _submit(payableBills),
                            icon: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                            label: Text(
                              _submitting
                                  ? 'Submitting…'
                                  : 'Submit payment for verification',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Payment history',
                style: Theme.of(context).textTheme.titleLarge,
              ),

              const SizedBox(height: 8),

              paymentHistory.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) =>
                    Text('Unable to load payment history: $error'),
                data: (snapshot) {
                  final docs = snapshot.docs.toList()
                    ..sort((a, b) {
                      final aDate = a.data()['createdAt'];
                      final bDate = b.data()['createdAt'];

                      final aMillis = aDate is Timestamp
                          ? aDate.millisecondsSinceEpoch
                          : 0;

                      final bMillis = bDate is Timestamp
                          ? bDate.millisecondsSinceEpoch
                          : 0;

                      return bMillis.compareTo(aMillis);
                    });

                  if (docs.isEmpty) {
                    return const Text('No payment submissions yet.');
                  }

                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data();

                      final amount = data['amount'];

                      final status = (data['status'] ?? 'pending').toString();

                      final method = (data['method'] ?? 'other').toString();

                      final reference = (data['reference'] ?? '').toString();

                      final reason = (data['rejectionReason'] ?? '').toString();

                      return Card(
                        child: ListTile(
                          leading: Icon(
                            status == 'confirmed'
                                ? Icons.check_circle_outline
                                : status == 'rejected'
                                ? Icons.cancel_outlined
                                : Icons.hourglass_top_rounded,
                          ),
                          title: Text(
                            '৳${amount is num ? _money(amount.toDouble()) : '—'}'
                            ' • ${method.toUpperCase()}',
                          ),
                          subtitle: Text(
                            'Status: ${status.toUpperCase()}'
                            '${reference.isNotEmpty ? '\nReference: $reference' : ''}'
                            '${reason.isNotEmpty ? '\nReason: $reason' : ''}',
                          ),
                          isThreeLine:
                              reference.isNotEmpty || reason.isNotEmpty,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _methodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bank:
        return 'Bank transfer';
      case PaymentMethod.bkash:
        return 'bKash';
      case PaymentMethod.nagad:
        return 'Nagad';
      case PaymentMethod.other:
        return 'Other';
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
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
