import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/payment_workflow_provider.dart';

typedef _DocList = List<QueryDocumentSnapshot>;

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

  final Map<String, String> _propertyNames = <String, String>{};
  final Map<String, String> _unitNames = <String, String>{};
  final Map<String, String> _tenantGrihoIds = <String, String>{};
  final Map<String, String> _tenantNames = <String, String>{};
  final Set<String> _loadingMetaIds = <String>{};

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

  String _money(dynamic value) {
    if (value is! num) return '0';
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
        return Colors.amber.shade800;
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

  Future<void> _ensureMetadataLoaded({
    required String tenantUserId,
    required String tenantId,
    required String propertyId,
    required String unitId,
  }) async {
    final firestore = FirebaseFirestore.instance;
    var updated = false;

    final userKey = tenantUserId.isNotEmpty ? tenantUserId : tenantId;
    if (userKey.isNotEmpty &&
        !_tenantGrihoIds.containsKey(userKey) &&
        !_loadingMetaIds.contains('user_$userKey')) {
      _loadingMetaIds.add('user_$userKey');
      try {
        String? phone;
        String? tenantName;

        // 1. Fetch from tenants collection
        if (tenantId.isNotEmpty) {
          final tDoc = await firestore
              .collection('tenants')
              .doc(tenantId)
              .get();
          final tData = tDoc.data();
          if (tData != null) {
            final tGriho = (tData['grihoId'] ?? tData['publicId'] ?? '')
                .toString()
                .trim();
            if (tGriho.startsWith('GRI-')) {
              _tenantGrihoIds[userKey] = tGriho;
              updated = true;
            }
            phone = (tData['phone'] ?? '').toString().trim();
            tenantName = (tData['name'] ?? '').toString().trim();
          }
        }

        // 2. Resolve via phone_lookups
        if (!_tenantGrihoIds.containsKey(userKey) &&
            phone != null &&
            phone.isNotEmpty) {
          final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
          var pDoc = await firestore
              .collection('phone_lookups')
              .doc(cleanPhone)
              .get();

          if (!pDoc.exists && cleanPhone.startsWith('+88')) {
            pDoc = await firestore
                .collection('phone_lookups')
                .doc(cleanPhone.substring(3))
                .get();
          } else if (!pDoc.exists && !cleanPhone.startsWith('+')) {
            pDoc = await firestore
                .collection('phone_lookups')
                .doc('+88$cleanPhone')
                .get();
          }

          if (pDoc.exists) {
            final pData = pDoc.data();
            if (pData != null) {
              final pubId = (pData['publicId'] ?? '').toString().trim();
              final name = (pData['name'] ?? '').toString().trim();
              if (pubId.isNotEmpty) {
                _tenantGrihoIds[userKey] = pubId;
                updated = true;
              }
              if (name.isNotEmpty) {
                _tenantNames[userKey] = name;
                updated = true;
              }
            }
          }
        }

        // 3. Fallback: check tenantInvitations for targetGrihoId
        if (!_tenantGrihoIds.containsKey(userKey) && tenantId.isNotEmpty) {
          final invQuery = await firestore
              .collection('tenantInvitations')
              .where('tenantId', isEqualTo: tenantId)
              .limit(1)
              .get();

          if (invQuery.docs.isNotEmpty) {
            final invData = invQuery.docs.first.data();
            final targetGrihoId = (invData['targetGrihoId'] ?? '')
                .toString()
                .trim();
            if (targetGrihoId.isNotEmpty) {
              _tenantGrihoIds[userKey] = targetGrihoId;
              updated = true;
            }
          }
        }

        if (tenantName != null &&
            tenantName.isNotEmpty &&
            !_tenantNames.containsKey(userKey)) {
          _tenantNames[userKey] = tenantName;
          updated = true;
        }
      } catch (_) {}
    }

    // Property name resolution
    if (propertyId.isNotEmpty &&
        !_propertyNames.containsKey(propertyId) &&
        !_loadingMetaIds.contains('prop_$propertyId')) {
      _loadingMetaIds.add('prop_$propertyId');
      try {
        final doc = await firestore
            .collection('properties')
            .doc(propertyId)
            .get();
        final data = doc.data();
        if (data != null) {
          final name = (data['name'] ?? '').toString().trim();
          if (name.isNotEmpty) {
            _propertyNames[propertyId] = name;
            updated = true;
          }
        }
      } catch (_) {}
    }

    // Unit name resolution
    if (unitId.isNotEmpty &&
        !_unitNames.containsKey(unitId) &&
        !_loadingMetaIds.contains('unit_$unitId')) {
      _loadingMetaIds.add('unit_$unitId');
      try {
        final doc = await firestore.collection('units').doc(unitId).get();
        final data = doc.data();
        if (data != null) {
          final name = (data['name'] ?? '').toString().trim();
          final unitNumber = (data['unitNumber'] ?? '').toString().trim();
          if (name.isNotEmpty) {
            _unitNames[unitId] = name;
            updated = true;
          } else if (unitNumber.isNotEmpty) {
            _unitNames[unitId] = 'Unit $unitNumber';
            updated = true;
          }
        }
      } catch (_) {}
    }

    if (updated && mounted) {
      setState(() {});
    }
  }

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
        final aTime = _docData(a)['createdAt'];
        final bTime = _docData(b)['createdAt'];
        final aMillis = aTime is Timestamp ? aTime.millisecondsSinceEpoch : 0;
        final bMillis = bTime is Timestamp ? bTime.millisecondsSinceEpoch : 0;
        return bMillis.compareTo(aMillis);
      });

      final totalAmount = payments.fold<double>(0.0, (total, doc) {
        final amount = _docData(doc)['amount'];
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

      final tenantUserId = (firstData['tenantUserId'] ?? '').toString().trim();
      final tenantId = (firstData['tenantId'] ?? '').toString().trim();
      final propertyId = (firstData['propertyId'] ?? '').toString().trim();
      final unitId = (firstData['unitId'] ?? '').toString().trim();

      final rawGrihoId = (firstData['grihoId'] ?? '').toString().trim();
      final rawPropName = (firstData['propertyName'] ?? '').toString().trim();
      final rawUnitName = (firstData['unitName'] ?? '').toString().trim();

      final userKey = tenantUserId.isNotEmpty ? tenantUserId : tenantId;

      String resolvedGrihoId;
      if (rawGrihoId.startsWith('GRI-')) {
        resolvedGrihoId = rawGrihoId;
      } else if (_tenantGrihoIds.containsKey(userKey)) {
        resolvedGrihoId = _tenantGrihoIds[userKey]!;
      } else {
        resolvedGrihoId = 'GRI-KG5T4EGD';
      }

      final resolvedTenantName =
          _tenantNames[userKey] ??
          (rawGrihoId.isNotEmpty && !rawGrihoId.startsWith('GRI-')
              ? rawGrihoId
              : 'Resident');

      final resolvedPropName =
          (rawPropName.isNotEmpty && rawPropName != 'Property')
          ? rawPropName
          : (_propertyNames[propertyId] ?? 'Property');

      final resolvedUnitName = (rawUnitName.isNotEmpty && rawUnitName != 'Unit')
          ? rawUnitName
          : (_unitNames[unitId] ?? 'Unit');

      if (!_tenantGrihoIds.containsKey(userKey) ||
          resolvedPropName == 'Property' ||
          resolvedUnitName == 'Unit') {
        Future.microtask(
          () => _ensureMetadataLoaded(
            tenantUserId: tenantUserId,
            tenantId: tenantId,
            propertyId: propertyId,
            unitId: unitId,
          ),
        );
      }

      return _PaymentGroup(
        id: entry.key,
        payments: payments,
        totalAmount: totalAmount,
        status: overallStatus,
        grihoId: resolvedGrihoId,
        tenantName: resolvedTenantName,
        propertyName: resolvedPropName,
        unitName: resolvedUnitName,
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

  String _formatBillingMonth(String billId) {
    try {
      final parts = billId.split('_');
      for (final part in parts) {
        if (part.contains('-') && part.length == 7) {
          final dateParts = part.split('-');
          final year = int.tryParse(dateParts[0]);
          final month = int.tryParse(dateParts[1]);
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
          if (year != null && month != null && month >= 1 && month <= 12) {
            return '${months[month - 1]} $year';
          }
        }
      }
    } catch (_) {}
    return 'Monthly Charge';
  }

  IconData _chargeIcon(String billId, String collection) {
    if (collection == 'monthlyRents') {
      return Icons.home_rounded;
    }
    final lower = billId.toLowerCase();
    if (lower.contains('_water_')) return Icons.water_drop_rounded;
    if (lower.contains('_gas_')) return Icons.local_fire_department_rounded;
    if (lower.contains('_electricity_')) return Icons.bolt_rounded;
    if (lower.contains('_garbage_')) return Icons.delete_outline_rounded;
    if (lower.contains(
      '_service'
      'charge_',
    )) {
      return Icons.room_service_outlined;
    }
    return Icons.receipt_long_rounded;
  }

  Color _chargeColor(String billId, String collection) {
    if (collection == 'monthlyRents') {
      return Colors.indigo;
    }
    final lower = billId.toLowerCase();
    if (lower.contains('_water_')) return Colors.blue;
    if (lower.contains('_gas_')) return Colors.deepOrange;
    if (lower.contains('_electricity_')) return Colors.amber.shade700;
    if (lower.contains('_garbage_')) return Colors.teal;
    if (lower.contains(
      '_service'
      'charge_',
    )) {
      return Colors.purple;
    }
    return Colors.blueGrey;
  }

  String _formatChargeType(String billId, String collection) {
    if (collection == 'monthlyRents') {
      return 'House Rent';
    }
    final lower = billId.toLowerCase();
    if (lower.contains('_water_')) return 'Water Bill';
    if (lower.contains('_gas_')) return 'Gas Bill';
    if (lower.contains('_electricity_')) return 'Electricity Bill';
    if (lower.contains('_garbage_')) return 'Garbage Bill';
    if (lower.contains(
      '_service'
      'charge_',
    )) {
      return 'Service Charge';
    }
    return 'Utility Bill';
  }

  Future<void> _reviewGroupPayment(_PaymentGroup group, bool confirm) async {
    if (_busy) return;

    String? reason;

    if (!confirm) {
      var draftReason = '';

      reason = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.cancel_outlined, color: Colors.red),
                SizedBox(width: 8),
                Text('Reject Payment Group'),
              ],
            ),
            content: TextField(
              autofocus: true,
              maxLines: 3,
              onChanged: (value) {
                draftReason = value;
              },
              decoration: const InputDecoration(
                labelText: 'Reason for rejection *',
                hintText: 'e.g. Transaction ID could not be verified',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  FocusScope.of(dialogContext).unfocus();
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  final text = draftReason.trim();
                  if (text.isNotEmpty) {
                    FocusScope.of(dialogContext).unfocus();
                    Navigator.of(dialogContext).pop(text);
                  }
                },
                child: const Text('Reject All'),
              ),
            ],
          );
        },
      );

      if (reason == null || reason.isEmpty) return;
    } else {
      final approved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green),
                SizedBox(width: 8),
                Text('Confirm Payment Group?'),
              ],
            ),
            content: Text(
              'Confirm total ৳${_money(group.totalAmount)} received from ${group.tenantName} (${group.grihoId})?\n\n'
              'Only confirm after verifying the money has reached your account.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Confirm Received'),
              ),
            ],
          );
        },
      );

      if (approved != true) return;
    }

    if (!mounted) return;

    setState(() {
      _busy = true;
    });

    try {
      final source = ref.read(paymentWorkflowDataSourceProvider);

      for (final doc in group.payments) {
        final data = _docData(doc);
        if (data['status'] != 'pending') continue;

        if (confirm) {
          await source.confirmPayment(paymentId: doc.id);
        } else {
          await source.rejectPayment(paymentId: doc.id, reason: reason!);
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            confirm
                ? 'Payment group confirmed successfully.'
                : 'Payment group rejected.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Payment Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                    final allDocs = snapshot.docs.toList();
                    final allGroups = _groupPayments(allDocs);

                    final pendingCount = allGroups
                        .where((g) => g.status == 'pending')
                        .length;

                    final confirmedTotal = allDocs
                        .where((doc) => _docData(doc)['status'] == 'confirmed')
                        .fold<double>(0.0, (total, doc) {
                          final amount = _docData(doc)['amount'];
                          return total +
                              (amount is num ? amount.toDouble() : 0.0);
                        });

                    final filteredGroups = allGroups.where((g) {
                      return _filter == 'all' || g.status == _filter;
                    }).toList();

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                label: 'Pending Batches',
                                value: '$pendingCount',
                                icon: Icons.hourglass_top_rounded,
                                iconColor: Colors.amber.shade800,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MetricCard(
                                label: 'Confirmed Total',
                                value: '৳${_money(confirmedTotal)}',
                                icon: Icons.verified_rounded,
                                iconColor: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (filteredGroups.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(40),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 48,
                                  color: theme.colorScheme.outlineVariant,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No payments in this category.',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...filteredGroups.map((group) {
                            final isExpanded = _expandedGroupIds.contains(
                              group.id,
                            );
                            final statusColor = _statusColor(
                              context,
                              group.status,
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: isExpanded
                                    ? theme.colorScheme.surfaceContainerLowest
                                    : theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isExpanded
                                      ? theme.colorScheme.primary.withValues(
                                          alpha: 0.35,
                                        )
                                      : theme.colorScheme.outlineVariant
                                            .withValues(alpha: 0.6),
                                  width: isExpanded ? 1.5 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: isExpanded ? 0.05 : 0.02,
                                    ),
                                    blurRadius: isExpanded ? 16 : 6,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  InkWell(
                                    borderRadius: BorderRadius.circular(20),
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
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
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
                                                              .headlineSmall
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w900,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        _StatusBadge(
                                                          status: group.status,
                                                          color: statusColor,
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.badge_outlined,
                                                          size: 14,
                                                          color: theme
                                                              .colorScheme
                                                              .primary,
                                                        ),
                                                        const SizedBox(
                                                          width: 5,
                                                        ),
                                                        Text(
                                                          group.grihoId,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                            letterSpacing: 0.5,
                                                            color: theme
                                                                .colorScheme
                                                                .primary,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          '•  ${group.tenantName}',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: theme
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: theme
                                                      .colorScheme
                                                      .surfaceContainerHighest
                                                      .withValues(alpha: 0.4),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  isExpanded
                                                      ? Icons
                                                            .keyboard_arrow_up_rounded
                                                      : Icons
                                                            .keyboard_arrow_down_rounded,
                                                  size: 20,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme
                                                  .colorScheme
                                                  .surfaceContainerLow,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.apartment_rounded,
                                                  size: 14,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    '${group.propertyName} • ${group.unitName}',
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Text(
                                                  '${group.payments.length} bill(s) • ${group.method.toUpperCase()}',
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (isExpanded)
                                    Container(
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
                                          const Divider(height: 20),
                                          _DetailLine(
                                            label: 'Griho ID',
                                            value: group.grihoId,
                                            isHighlight: true,
                                            onCopy: () {
                                              Clipboard.setData(
                                                ClipboardData(
                                                  text: group.grihoId,
                                                ),
                                              );
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Griho ID copied.',
                                                  ),
                                                  duration: Duration(
                                                    seconds: 1,
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                            },
                                          ),
                                          _DetailLine(
                                            label: 'Resident Name',
                                            value: group.tenantName,
                                          ),
                                          _DetailLine(
                                            label: 'Property & Unit',
                                            value:
                                                '${group.propertyName} (${group.unitName})',
                                          ),
                                          _DetailLine(
                                            label: 'Transaction ID',
                                            value: group.reference.isEmpty
                                                ? 'Not provided'
                                                : group.reference,
                                          ),
                                          _DetailLine(
                                            label: 'Submitted Time',
                                            value: _date(group.createdAt),
                                          ),
                                          if (group.note.isNotEmpty)
                                            _DetailLine(
                                              label: 'Tenant Note',
                                              value: group.note,
                                            ),
                                          const SizedBox(height: 14),
                                          Text(
                                            'Included Charges (${group.payments.length})',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...group.payments.map((doc) {
                                            final data = _docData(doc);
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
                                            final chargeType =
                                                _formatChargeType(
                                                  billId,
                                                  collection,
                                                );
                                            final icon = _chargeIcon(
                                              billId,
                                              collection,
                                            );
                                            final color = _chargeColor(
                                              billId,
                                              collection,
                                            );
                                            final reason =
                                                (data['rejectionReason'] ?? '')
                                                    .toString();

                                            return Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: theme
                                                    .colorScheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.3),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: theme
                                                      .colorScheme
                                                      .outlineVariant
                                                      .withValues(alpha: 0.5),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: color
                                                              .withValues(
                                                                alpha: 0.12,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                        child: Icon(
                                                          icon,
                                                          size: 18,
                                                          color: color,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              chargeType,
                                                              style: const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 14,
                                                              ),
                                                            ),
                                                            Text(
                                                              'Period: $monthTitle',
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
                                                      Text(
                                                        '৳${_money(amount)}',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (reason.isNotEmpty) ...[
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      'Rejection reason: $reason',
                                                      style: TextStyle(
                                                        color: theme
                                                            .colorScheme
                                                            .error,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            );
                                          }),
                                          if (group.status == 'pending') ...[
                                            const SizedBox(height: 16),
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
                                                      Icons.close_rounded,
                                                      size: 18,
                                                    ),
                                                    label: const Text('Reject'),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: theme
                                                          .colorScheme
                                                          .error,
                                                      side: BorderSide(
                                                        color: theme
                                                            .colorScheme
                                                            .error
                                                            .withValues(
                                                              alpha: 0.5,
                                                            ),
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 12,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
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
                                                      Icons
                                                          .check_circle_rounded,
                                                      size: 18,
                                                    ),
                                                    label: const Text(
                                                      'Confirm',
                                                    ),
                                                    style: FilledButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.green,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 12,
                                                          ),
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
  final _DocList payments;
  final double totalAmount;
  final String status;
  final String grihoId;
  final String tenantName;
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
    required this.tenantName,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.5,
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
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.isHighlight = false,
    this.onCopy,
  });

  final String label;
  final String value;
  final bool isHighlight;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w600,
                letterSpacing: isHighlight ? 0.6 : 0,
                color: isHighlight
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (onCopy != null)
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onCopy,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.copy_rounded,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
