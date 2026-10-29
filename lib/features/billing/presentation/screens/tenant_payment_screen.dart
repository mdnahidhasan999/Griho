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

  PaymentMethod _method = PaymentMethod.bkash;

  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();

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
      MonthlyBillType.serviceCharge: 'Service charge',
      MonthlyBillType.electricity: 'Electricity',
      MonthlyBillType.other: 'Other charge',
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
      _message('Select at least one bill.');
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
          'Payment cannot exceed the remaining balance '
          'for ${_billTitle(bill)}.',
        );
        return;
      }

      amountsByBillId[bill.id] = amount;

      // This assumes the provider returns MonthlyBill objects from
      // monthlyBills. Rent entries must carry their source collection.
      //
      // Until the entity/provider is extended with billCollection,
      // this fallback supports existing non-rent bills only.
      collectionsByBillId[bill.id] = 'monthlyBills';
    }

    final reference = _referenceController.text.trim();

    if (_method != PaymentMethod.cash && reference.isEmpty) {
      _message('Enter the transaction/reference ID.');
      return;
    }

    setState(() {
      _submitting = true;
    });

    var submittedCount = 0;

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

      submittedCount = createdPayments.length;

      if (!mounted) return;

      _selectedBillIds.clear();

      for (final bill in selectedBills) {
        _amountControllers[bill.id]?.text = _remaining(bill).toStringAsFixed(2);
      }

      _referenceController.clear();
      _noteController.clear();

      _message(
        '$submittedCount payment request(s) submitted. '
        'They remain pending until the owner verifies them.',
      );
    } catch (error) {
      if (!mounted) return;

      _message(
        submittedCount > 0
            ? '$submittedCount payment request(s) were submitted, '
                  'but another request failed: '
                  '${_friendlyError(error)}'
            : 'Unable to submit payment: ${_friendlyError(error)}',
      );
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

          _selectedBillIds.removeWhere(
            (id) => !payableBills.any((bill) => bill.id == id),
          );

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
                        'Pay bills',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Select one or more outstanding bills and enter '
                        'the amount you are paying for each bill. '
                        'The owner must verify every payment request '
                        'before the bill balance changes.',
                      ),
                      const SizedBox(height: 16),
                      if (payableBills.isEmpty)
                        const Text(
                          'There are no outstanding bills '
                          'available for payment.',
                        )
                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Outstanding bills',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
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
                                              payableBills.map(
                                                (bill) => bill.id,
                                              ),
                                            );
                                        }
                                      });
                                    },
                              child: Text(
                                _selectedBillIds.length == payableBills.length
                                    ? 'Deselect all'
                                    : 'Select all',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...payableBills.map((bill) {
                          final selected = _selectedBillIds.contains(bill.id);

                          final controller = _amountControllerFor(bill);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    value: selected,
                                    onChanged: _submitting
                                        ? null
                                        : (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedBillIds.add(bill.id);
                                              } else {
                                                _selectedBillIds.remove(
                                                  bill.id,
                                                );
                                              }
                                            });
                                          },
                                    title: Text(_billTitle(bill)),
                                    subtitle: Text(
                                      'Bill: ৳${_money(bill.amount)}\n'
                                      'Paid: ৳${_money(bill.paidAmount)}\n'
                                      'Due: ৳${_money(_remaining(bill))}',
                                    ),
                                    isThreeLine: true,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                  if (selected) ...[
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: controller,
                                      enabled: !_submitting,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        labelText: 'Payment amount (৳)',
                                        helperText:
                                            'Maximum: ৳${_money(_remaining(bill))}',
                                        border: const OutlineInputBorder(),
                                      ),
                                      onChanged: (_) {
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _InfoRow(
                                  label: 'Selected bills',
                                  value: '${_selectedBillIds.length}',
                                ),
                                _InfoRow(
                                  label: 'Selected payment total',
                                  value:
                                      '৳${_money(_selectedTotal(payableBills))}',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                          controller: _referenceController,
                          enabled: !_submitting,
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
                          enabled: !_submitting,
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
                                  : 'Submit selected payments',
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
                      final collection =
                          (data['billCollection'] ?? 'monthlyBills').toString();

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
                            'Status: ${status.toUpperCase()}\n'
                            'Bill source: $collection'
                            '${reference.isNotEmpty ? '\nReference: $reference' : ''}'
                            '${reason.isNotEmpty ? '\nReason: $reason' : ''}',
                          ),
                          isThreeLine: true,
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
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
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
