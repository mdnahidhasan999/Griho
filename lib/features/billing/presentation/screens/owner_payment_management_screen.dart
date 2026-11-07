import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/payment_workflow_provider.dart';

typedef PaymentQuerySnapshot = QuerySnapshot<Map<String, dynamic>>;
typedef PaymentDocSnapshot = QueryDocumentSnapshot<Map<String, dynamic>>;

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
  final Set<String> _expandedGroupIds = <String>{};

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
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.green;
      case 'rejected':
        return Theme.of(context).colorScheme.error;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  String _resolveGroupStatus(Set<String> statuses) {
    if (statuses.isEmpty) return 'pending';
    if (statuses.length == 1) return statuses.first;
    if (statuses.every((status) => status == 'confirmed')) return 'confirmed';
    if (statuses.every((status) => status == 'rejected')) return 'rejected';
    if (statuses.contains('pending')) return 'pending';
    return 'partially processed';
  }

  List<_PaymentGroup> _groupPayments(List<PaymentDocSnapshot> docs) {
    final grouped = <String, List<PaymentDocSnapshot>>{};

    for (final doc in docs) {
      final data = doc.data();
      final batchId = (data['batchId'] ?? '').toString().trim();
      final groupKey = batchId.isNotEmpty ? batchId : 'legacy_${doc.id}';

      grouped.putIfAbsent(groupKey, () => []).add(doc);
    }

    final result = grouped.entries.map((entry) {
      final payments = entry.value;

      payments.sort((a, b) {
        final aTime = a.data()['createdAt'];
        final bTime = b.data()['createdAt'];
        final aMillis = aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;
        final bMillis = bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;
        return bMillis.compareTo(aMillis);
      });

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
        grihoId: (firstData['grihoId'] ?? firstData['tenantId'] ?? '—')
            .toString(),
        propertyName: (firstData['propertyName'] ?? 'Property').toString(),
        unitName: (firstData['unitName'] ?? 'Unit').toString(),
        method: (firstData['method'] ?? 'other').toString(),
        reference: (firstData['reference'] ?? '').toString(),
        note: (firstData['note'] ?? '').toString(),
        createdAt: firstData['createdAt'],
      );
    }).toList();

    result.sort((a, b) {
      final aMillis = a.createdAt is Timestamp
          ? (a.createdAt as Timestamp).millisecondsSinceEpoch
          : 0;
      final bMillis = b.createdAt is Timestamp
          ? (b.createdAt as Timestamp).millisecondsSinceEpoch
          : 0;
      return bMillis.compareTo(aMillis);
    });

    return result;
  }

  // Extract billing month from billId (e.g. ..._2026-11) or fallback
  String _formatBillingMonth(String billId) {
    try {
      final parts = billId.split('_');
      for (final part in parts) {
        if (part.contains('-') && part.length == 7) {
          final dateParts = part.split('-');
          final year = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
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
          if (month >= 1 && month <= 12) {
            return '${months[month - 1]} $year';
          }
        }
      }
    } catch (_) {}
    return 'Monthly Charge';
  }

  Future<void> _reviewGroupPayment(_PaymentGroup group, bool confirm) async {
    if (_busy) return;

    String? reason;

    if (!confirm) {
      final controller = TextEditingController();

      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Reject payment group'),
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
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    Navigator.pop(dialogContext, text);
                  }
                },
                child: const Text('Reject All'),
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
            title: const Text('Confirm payment group?'),
            content: Text(
              'Confirm total ৳${_money(group.totalAmount)} '
              'for Griho ID: ${group.grihoId}? '
              'Only confirm after verifying that the money was actually received.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Confirm payments'),
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

      for (final doc in group.payments) {
        if (confirm) {
          await source.confirmPayment(paymentId: doc.id);
        } else {
          await source.rejectPayment(paymentId: doc.id, reason: reason!);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              confirm
                  ? 'Payment group confirmed successfully.'
                  : 'Payment group rejected.',
            ),
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
    final theme = Theme.of(context);

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
                    final docs = snapshot.docs.where((doc) {
                      return _filter == 'all' ||
                          doc.data()['status'] == _filter;
                    }).toList();

                    final groups = _groupPayments(docs);

                    final pendingCount = groups
                        .where((g) => g.status == 'pending')
                        .length;

                    final confirmedTotal = groups
                        .where((g) => g.status == 'confirmed')
                        .fold<double>(0.0, (total, g) => total + g.totalAmount);

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                label: 'Pending Groups',
                                value: '$pendingCount',
                                icon: Icons.hourglass_top,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MetricCard(
                                label: 'Confirmed Total',
                                value: '৳${_money(confirmedTotal)}',
                                icon: Icons.payments_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (groups.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text('No payments in this category yet.'),
                            ),
                          )
                        else
                          ...groups.map((group) {
                            final isExpanded = _expandedGroupIds.contains(
                              group.id,
                            );
                            final statusColor = _statusColor(
                              context,
                              group.status,
                            );

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      setState(() {
                                        if (isExpanded) {
                                          _expandedGroupIds.remove(group.id);
                                        } else {
                                          _expandedGroupIds.add(group.id);
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      '৳${_money(group.totalAmount)}',
                                                      style: theme
                                                          .textTheme
                                                          .titleLarge
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    _StatusBadge(
                                                      status: group.status,
                                                      color: statusColor,
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Griho ID: ${group.grihoId} • ${group.propertyName} / ${group.unitName}',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${group.payments.length} bill(s) • Method: ${group.method.toUpperCase()}',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            isExpanded
                                                ? Icons
                                                      .keyboard_arrow_up_rounded
                                                : Icons
                                                      .keyboard_arrow_down_rounded,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isExpanded)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        16,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Divider(height: 12),
                                          _DetailLine(
                                            label: 'Transaction ID',
                                            value: group.reference.isEmpty
                                                ? 'Not provided'
                                                : group.reference,
                                          ),
                                          _DetailLine(
                                            label: 'Submitted',
                                            value: _date(group.createdAt),
                                          ),
                                          if (group.note.isNotEmpty)
                                            _DetailLine(
                                              label: 'Note',
                                              value: group.note,
                                            ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'Included Bills',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          ...group.payments.map((doc) {
                                            final data = doc.data();
                                            final amount = data['amount'];
                                            final billId =
                                                (data['billId'] ?? '')
                                                    .toString();
                                            final monthTitle =
                                                _formatBillingMonth(billId);
                                            final collection =
                                                (data['billCollection'] ??
                                                        'monthlyBills')
                                                    .toString();

                                            return Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.35),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        monthTitle,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Type: ${collection == 'monthlyRents' ? 'House Rent' : 'Utility Bill'}',
                                                        style: theme
                                                            .textTheme
                                                            .bodySmall,
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    '৳${_money(amount)}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                          if (group.status == 'pending') ...[
                                            const SizedBox(height: 14),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    onPressed: _busy
                                                        ? null
                                                        : () =>
                                                              _reviewGroupPayment(
                                                                group,
                                                                false,
                                                              ),
                                                    icon: const Icon(
                                                      Icons.close,
                                                    ),
                                                    label: const Text('Reject'),
                                                    style:
                                                        OutlinedButton.styleFrom(
                                                          foregroundColor: theme
                                                              .colorScheme
                                                              .error,
                                                        ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: FilledButton.icon(
                                                    onPressed: _busy
                                                        ? null
                                                        : () =>
                                                              _reviewGroupPayment(
                                                                group,
                                                                true,
                                                              ),
                                                    icon: const Icon(
                                                      Icons.check,
                                                    ),
                                                    label: const Text(
                                                      'Confirm',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                ],
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

class _PaymentGroup {
  final String id;
  final List<PaymentDocSnapshot> payments;
  final double totalAmount;
  final String status;
  final String grihoId;
  final String propertyName;
  final String unitName;
  final String method;
  final String reference;
  final String note;
  final dynamic createdAt;

  const _PaymentGroup({
    required this.id,
    required this.payments,
    required this.totalAmount,
    required this.status,
    required this.grihoId,
    required this.propertyName,
    required this.unitName,
    required this.method,
    required this.reference,
    required this.note,
    required this.createdAt,
  });
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
        borderRadius: BorderRadius.circular(6),
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
