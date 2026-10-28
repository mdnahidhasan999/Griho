import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/payment_workflow_provider.dart';

class OwnerPaymentManagementScreen extends ConsumerStatefulWidget {
  const OwnerPaymentManagementScreen({super.key});

  @override
  ConsumerState<OwnerPaymentManagementScreen> createState() =>
      _OwnerPaymentManagementScreenState();
}

class _OwnerPaymentManagementScreenState
    extends ConsumerState<OwnerPaymentManagementScreen> {
  String _filter = 'all';

  bool _busy = false;

  String _money(dynamic value) {
    if (value is! num) return '—';

    return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
  }

  String _date(dynamic value) {
    if (value is! Timestamp) {
      return 'Date pending';
    }

    final date = value.toDate().toLocal();

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;

      case 'rejected':
        return Theme.of(context).colorScheme.error;

      default:
        return Colors.orange;
    }
  }

  Future<void> _reviewPayment(
    String paymentId,
    Map<String, dynamic> data,
    bool confirm,
  ) async {
    if (_busy) return;

    String? reason;

    if (!confirm) {
      final controller = TextEditingController();

      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Reject payment'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'e.g. Transaction could not be verified',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final text = controller.text.trim();

                  if (text.isNotEmpty) {
                    Navigator.pop(dialogContext, text);
                  }
                },
                child: const Text('Reject'),
              ),
            ],
          );
        },
      );

      controller.dispose();

      if (reason == null) return;
    } else {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Confirm payment?'),
            content: Text(
              'Confirm ৳${_money(data['amount'])} '
              'for tenant ${data['tenantId'] ?? '—'}? '
              'Only confirm after verifying that the money '
              'was actually received.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Confirm payment'),
              ),
            ],
          );
        },
      );

      if (approved != true) return;
    }

    setState(() {
      _busy = true;
    });

    try {
      final source = ref.read(paymentWorkflowDataSourceProvider);

      if (confirm) {
        await source.confirmPayment(paymentId: paymentId);
      } else {
        await source.rejectPayment(paymentId: paymentId, reason: reason!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(confirm ? 'Payment confirmed.' : 'Payment rejected.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Management')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Unable to load owner profile: $error')),
        data: (profile) {
          if (profile == null || profile.uid.trim().isEmpty) {
            return const Center(child: Text('Owner profile not found.'));
          }

          final paymentsAsync = ref.watch(
            ownerPaymentTransactionsProvider((
              ownerId: profile.uid,
              pendingOnly: false,
            )),
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All')),
                    ButtonSegment(value: 'pending', label: Text('Pending')),
                    ButtonSegment(value: 'confirmed', label: Text('Confirmed')),
                    ButtonSegment(value: 'rejected', label: Text('Rejected')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _filter = selection.first;
                    });
                  },
                ),
              ),

              Expanded(
                child: paymentsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load payments: $error',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  data: (snapshot) {
                    final docs =
                        snapshot.docs.where((doc) {
                          return _filter == 'all' ||
                              doc.data()['status'] == _filter;
                        }).toList()..sort((a, b) {
                          final aTime = a.data()['createdAt'];
                          final bTime = b.data()['createdAt'];

                          final aMillis = aTime is Timestamp
                              ? aTime.millisecondsSinceEpoch
                              : 0;

                          final bMillis = bTime is Timestamp
                              ? bTime.millisecondsSinceEpoch
                              : 0;

                          return bMillis.compareTo(aMillis);
                        });

                    final pendingCount = snapshot.docs
                        .where((doc) => doc.data()['status'] == 'pending')
                        .length;

                    final confirmedTotal = snapshot.docs
                        .where((doc) => doc.data()['status'] == 'confirmed')
                        .fold<double>(0.0, (totalAmount, doc) {
                          final amount = doc.data()['amount'];

                          return totalAmount +
                              (amount is num ? amount.toDouble() : 0.0);
                        });

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                label: 'Pending',
                                value: '$pendingCount',
                                icon: Icons.hourglass_top,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MetricCard(
                                label: 'Confirmed total',
                                value: '৳${_money(confirmedTotal)}',
                                icon: Icons.payments_outlined,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        if (docs.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text('No payments in this category yet.'),
                            ),
                          )
                        else
                          ...docs.map((doc) {
                            final data = doc.data();

                            final status = (data['status'] ?? 'pending')
                                .toString();

                            final reference = (data['reference'] ?? '')
                                .toString();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '৳${_money(data['amount'])}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                        Chip(
                                          label: Text(status.toUpperCase()),
                                          labelStyle: TextStyle(
                                            color: _statusColor(
                                              context,
                                              status,
                                            ),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 6),

                                    _DetailLine(
                                      label: 'Tenant ID',
                                      value: '${data['tenantId'] ?? '—'}',
                                    ),

                                    _DetailLine(
                                      label: 'Property / Unit',
                                      value:
                                          '${data['propertyId'] ?? '—'}'
                                          ' / ${data['unitId'] ?? '—'}',
                                    ),

                                    _DetailLine(
                                      label: 'Bill ID',
                                      value: '${data['billId'] ?? '—'}',
                                    ),

                                    _DetailLine(
                                      label: 'Method',
                                      value: '${data['method'] ?? '—'}',
                                    ),

                                    _DetailLine(
                                      label: 'Transaction ID',
                                      value: reference.isEmpty
                                          ? 'Not provided'
                                          : reference,
                                    ),

                                    _DetailLine(
                                      label: 'Submitted',
                                      value: _date(data['createdAt']),
                                    ),

                                    if ((data['note'] ?? '')
                                        .toString()
                                        .trim()
                                        .isNotEmpty)
                                      _DetailLine(
                                        label: 'Note',
                                        value: '${data['note']}',
                                      ),

                                    if ((data['rejectionReason'] ?? '')
                                        .toString()
                                        .trim()
                                        .isNotEmpty)
                                      _DetailLine(
                                        label: 'Rejection reason',
                                        value: '${data['rejectionReason']}',
                                      ),

                                    if (status == 'pending') ...[
                                      const SizedBox(height: 12),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _reviewPayment(
                                                      doc.id,
                                                      data,
                                                      false,
                                                    ),
                                              icon: const Icon(Icons.close),
                                              label: const Text('Reject'),
                                            ),
                                          ),

                                          const SizedBox(width: 10),

                                          Expanded(
                                            child: FilledButton.icon(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _reviewPayment(
                                                      doc.id,
                                                      data,
                                                      true,
                                                    ),
                                              icon: const Icon(Icons.check),
                                              label: const Text('Confirm'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
