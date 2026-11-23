// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../../../core/services/pdf_receipt_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../providers/payment_workflow_provider.dart';
import '../widgets/billing_ui_helpers.dart';

typedef _JsonMap = Map<String, dynamic>;
typedef _DocSnapshot = QueryDocumentSnapshot<_JsonMap>;
typedef _DocList = List<_DocSnapshot>;


/// Cached stream provider for manager payment views so expanding cards or
/// switching filters never recreates Firestore snapshot listeners.
final _managedPropertyPaymentsProvider =
StreamProvider.family<PaymentQuerySnapshot, String>((ref, propertyIdsKey) {
  ref.watch(authStateProvider);
  if (FirebaseAuth.instance.currentUser == null ||
      propertyIdsKey.trim().isEmpty) {
    return const Stream.empty();
  }
  final ids = propertyIdsKey
      .split(',')
      .where((id) => id.trim().isNotEmpty)
      .toList();
  return ref
      .watch(paymentWorkflowDataSourceProvider)
      .watchManagedPropertyPayments(propertyIds: ids);
});

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

        if (!_tenantGrihoIds.containsKey(userKey) && tenantId.isNotEmpty) {
          final invQuery = await firestore
              .collection('tenantInvitations')
              .where('tenantId', isEqualTo: tenantId)
              .limit(1)
              .get();

          if (invQuery.docs.isNotEmpty) {
            final targetGrihoId =
            (invQuery.docs.first.data()['targetGrihoId'] ?? '')
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

    if (propertyId.isNotEmpty &&
        !_propertyNames.containsKey(propertyId) &&
        !_loadingMetaIds.contains('prop_$propertyId')) {
      _loadingMetaIds.add('prop_$propertyId');
      try {
        final doc = await firestore
            .collection('properties')
            .doc(propertyId)
            .get();
        final name = (doc.data()?['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          _propertyNames[propertyId] = name;
          updated = true;
        }
      } catch (_) {}
    }

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
      final data = doc.data();
      final batchId = (data['batchId'] ?? '').toString().trim();
      final groupKey = batchId.isNotEmpty ? batchId : 'legacy_${doc.id}';
      grouped.putIfAbsent(groupKey, () => []).add(doc);
    }

    final result = grouped.entries.map((entry) {
      final payments = entry.value
        ..sort((a, b) {
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
            (doc) => (doc.data()['status'] ?? 'pending')
            .toString()
            .toLowerCase(),
      )
          .toSet();

      final overallStatus = _resolveGroupStatus(statuses);
      final firstData = payments.first.data();

      final ownerId = (firstData['ownerId'] ?? '').toString().trim();
      final tenantUserId = (firstData['tenantUserId'] ?? '').toString().trim();
      final tenantId = (firstData['tenantId'] ?? '').toString().trim();
      final propertyId = (firstData['propertyId'] ?? '').toString().trim();
      final unitId = (firstData['unitId'] ?? '').toString().trim();

      final rawGrihoId = (firstData['grihoId'] ?? '').toString().trim();
      final rawTenantName = (firstData['tenantName'] ?? '').toString().trim();
      final rawPropName = (firstData['propertyName'] ?? '').toString().trim();
      final rawUnitName = (firstData['unitName'] ?? '').toString().trim();
      final proofUrl = (firstData['proofUrl'] ?? '').toString().trim();

      final userKey = tenantUserId.isNotEmpty ? tenantUserId : tenantId;

      final resolvedGrihoId = rawGrihoId.startsWith('GRI-')
          ? rawGrihoId
          : (_tenantGrihoIds[userKey] ?? 'GRI-MEMBER');

      final resolvedTenantName = rawTenantName.isNotEmpty
          ? rawTenantName
          : (_tenantNames[userKey] ??
          (rawGrihoId.isNotEmpty && !rawGrihoId.startsWith('GRI-')
              ? rawGrihoId
              : 'Resident'));

      final resolvedPropName =
      (rawPropName.isNotEmpty && rawPropName != 'Property')
          ? rawPropName
          : (_propertyNames[propertyId] ?? 'Property');

      final resolvedUnitName = (rawUnitName.isNotEmpty && rawUnitName != 'Unit')
          ? rawUnitName
          : (_unitNames[unitId] ?? 'Unit');

      if ((!_tenantGrihoIds.containsKey(userKey) &&
          !rawGrihoId.startsWith('GRI-')) ||
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
        ownerId: ownerId,
        propertyId: propertyId,
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
        proofUrl: proofUrl,
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
      for (final part in billId.split('_')) {
        if (part.contains('-') && part.length == 7) {
          final dateParts = part.split('-');
          final year = int.tryParse(dateParts[0]);
          final month = int.tryParse(dateParts[1]);
          if (year != null && month != null && month >= 1 && month <= 12) {
            return formatBillingMonthYear(DateTime(year, month, 1));
          }
        }
      }
    } catch (_) {}
    return 'Monthly Charge';
  }

  IconData _chargeIcon(String billId, String collection) {
    if (collection == 'monthlyRents') {
      return Iconsax.home_2;
    }
    final lower = billId.toLowerCase();
    if (lower.contains('_water_')) {
      return Iconsax.drop;
    }
    if (lower.contains('_gas_')) {
      return Iconsax.flash_1;
    }
    if (lower.contains('_electricity_')) {
      return Iconsax.electricity;
    }
    if (lower.contains('_garbage_')) {
      return Iconsax.trash;
    }
    if (lower.contains('_servicecharge_')) {
      return Iconsax.broom;
    }
    return Iconsax.receipt_item;
  }

  Color _chargeColor(String billId, String collection) {
    if (collection == 'monthlyRents') {
      return GrihoColors.emerald;
    }
    final lower = billId.toLowerCase();
    if (lower.contains('_water_')) {
      return Colors.blueAccent;
    }
    if (lower.contains('_gas_')) {
      return Colors.deepOrange;
    }
    if (lower.contains('_electricity_')) {
      return GrihoColors.warning;
    }
    if (lower.contains('_garbage_')) {
      return Colors.teal;
    }
    if (lower.contains('_servicecharge_')) {
      return Colors.purple;
    }
    return Colors.blueGrey;
  }

  String _formatChargeType(String billId, String collection) {
    if (collection == 'monthlyRents') {
      return 'House Rent';
    }
    final lower = billId.toLowerCase();
    if (lower.contains('_water_')) {
      return 'Water Bill';
    }
    if (lower.contains('_gas_')) {
      return 'Gas Bill';
    }
    if (lower.contains('_electricity_')) {
      return 'Electricity Bill';
    }
    if (lower.contains('_garbage_')) {
      return 'Garbage Bill';
    }
    if (lower.contains('_servicecharge_')) {
      return 'Service Charge';
    }
    return 'Utility Bill';
  }

  Future<void> _openPdfReceipt(
      _PaymentGroup group, {
        required bool share,
      }) async {
    try {
      final issuedAt = group.createdAt is Timestamp
          ? (group.createdAt as Timestamp).toDate()
          : DateTime.now();

      final items = group.payments.map((doc) {
        final data = doc.data();
        final amount = (data['amount'] is num)
            ? (data['amount'] as num).toDouble()
            : 0.0;
        final billId = (data['billId'] ?? '').toString();
        final collection = (data['billCollection'] ?? 'monthlyBills')
            .toString();

        return ReceiptLineItem(
          title: _formatChargeType(billId, collection),
          periodLabel: _formatBillingMonth(billId),
          amount: amount,
        );
      }).toList();

      final shortId = group.id.replaceFirst('legacy_', '');
      final receiptNo = shortId.length > 10
          ? shortId.substring(0, 10)
          : shortId;

      final receiptData = PaymentReceiptData(
        receiptNumber: receiptNo,
        status: group.status,
        issuedAt: issuedAt,
        tenantName: group.tenantName,
        tenantGrihoId: group.grihoId,
        propertyName: group.propertyName,
        unitName: group.unitName,
        paymentMethod: group.method,
        referenceNumber: group.reference,
        note: group.note,
        items: items,
      );

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

  void _showProofPreview(String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Payment Screenshot'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Iconsax.close_circle),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) {
                    return child;
                  }
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  );
                },
                errorBuilder: (_, _, _) => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Unable to load screenshot.'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reviewGroupPayment(_PaymentGroup group, bool confirm) async {
    if (_busy) {
      return;
    }

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
                Icon(Iconsax.close_circle, color: GrihoColors.error),
                SizedBox(width: 8),
                Text('Reject Payment Group'),
              ],
            ),
            content: TextField(
              autofocus: true,
              maxLines: 3,
              onChanged: (value) => draftReason = value,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection *',
                hintText: 'e.g. Transaction ID could not be verified',
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
                  backgroundColor: GrihoColors.error,
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

      if (reason == null || reason.isEmpty) {
        return;
      }
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
                Icon(Iconsax.tick_circle, color: GrihoColors.emerald),
                SizedBox(width: 8),
                Text('Confirm Payment?'),
              ],
            ),
            content: Text(
              'Confirm total ৳${formatBillingAmount(group.totalAmount)} received from ${group.tenantName} (${group.grihoId})?\n\n'
                  'Only confirm after verifying the money has reached the account.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: GrihoColors.emerald,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Confirm Received'),
              ),
            ],
          );
        },
      );

      if (approved != true) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() => _busy = true);

    try {
      final source = ref.read(paymentWorkflowDataSourceProvider);

      for (final doc in group.payments) {
        if (doc.data()['status'] != 'pending') {
          continue;
        }
        if (confirm) {
          await source.confirmPayment(paymentId: doc.id);
        } else {
          await source.rejectPayment(paymentId: doc.id, reason: reason!);
        }
      }

      await AuditLoggerService.log(
        ownerId: group.ownerId,
        propertyId: group.propertyId,
        propertyName: group.propertyName,
        category: 'payment',
        actionTitle: confirm
            ? 'Payment Confirmed (৳${formatBillingAmount(group.totalAmount)})'
            : 'Payment Rejected (৳${formatBillingAmount(group.totalAmount)})',
        details: confirm
            ? 'Confirmed ${group.payments.length} charge(s) from ${group.tenantName} (${group.unitName}) via ${group.method.toUpperCase()}.'
            : 'Rejected payment from ${group.tenantName} (${group.unitName}). Reason: $reason',
      );

      if (!mounted) {
        return;
      }

      if (confirm) {
        GrihoFeedback.showSuccess(
          context,
          'Payment group confirmed successfully.',
        );
      } else {
        GrihoFeedback.showWarning(context, 'Payment group rejected.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, cleanBillingError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Payment Management')),
      body: profileAsync.when(
        loading: () => const GrihoLoadingView(message: 'Loading profile...'),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load profile',
              subtitle: error.toString(),
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(currentUserProfileProvider),
            ),
          ),
        ),
        data: (profile) {
          if (profile == null || profile.uid.trim().isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: GrihoStatusState(
                  icon: Iconsax.user_remove,
                  title: 'User profile not found',
                  subtitle: 'Please sign in again.',
                ),
              ),
            );
          }

          return propertiesAsync.when(
            loading: () =>
            const GrihoLoadingView(message: 'Loading properties...'),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GrihoStatusState(
                  icon: Iconsax.warning_2,
                  title: 'Unable to load properties',
                  subtitle: err.toString(),
                  actionLabel: 'Retry',
                  onAction: () =>
                      ref.invalidate(currentOwnerPropertiesProvider),
                ),
              ),
            ),
            data: (properties) {
              final isOwnerDashboard = profile.defaultDashboard == 'owner';
              final sortedPropIds =
              properties.map((p) => p.id.trim()).where((id) => id.isNotEmpty).take(10).toList()
                ..sort();
              final propIdsKey = sortedPropIds.join(',');

              final AsyncValue<PaymentQuerySnapshot> paymentsAsync;
              if (isOwnerDashboard) {
                paymentsAsync = ref.watch(
                  ownerPaymentTransactionsProvider((
                  ownerId: profile.uid,
                  pendingOnly: false,
                  )),
                );
              } else if (propIdsKey.isNotEmpty) {
                paymentsAsync = ref.watch(
                  _managedPropertyPaymentsProvider(propIdsKey),
                );
              } else {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: GrihoStatusState(
                      icon: Iconsax.buildings_2,
                      title: 'No properties assigned',
                      subtitle: 'You have no managed properties to review.',
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'all', label: Text('All')),
                        ButtonSegment(value: 'pending', label: Text('Pending')),
                        ButtonSegment(
                          value: 'confirmed',
                          label: Text('Confirmed'),
                        ),
                        ButtonSegment(
                          value: 'rejected',
                          label: Text('Rejected'),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (selection) =>
                          setState(() => _filter = selection.first),
                    ),
                  ),
                  Expanded(
                    child: paymentsAsync.when(
                      loading: () =>
                      const GrihoLoadingView(message: 'Loading payments...'),
                      error: (error, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: GrihoStatusState(
                            icon: Iconsax.warning_2,
                            title: 'Unable to load payments',
                            subtitle: error.toString(),
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
                            .where((doc) => doc.data()['status'] == 'confirmed')
                            .fold<double>(0.0, (total, doc) {
                          final amount = doc.data()['amount'];
                          return total +
                              (amount is num ? amount.toDouble() : 0.0);
                        });

                        final filteredGroups = allGroups
                            .where(
                              (g) => _filter == 'all' || g.status == _filter,
                        )
                            .toList();

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _MetricCard(
                                    label: 'Pending Batches',
                                    value: '$pendingCount',
                                    icon: Iconsax.clock,
                                    iconColor: GrihoColors.warning,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _MetricCard(
                                    label: 'Confirmed Total',
                                    value:
                                    '৳${formatBillingAmount(confirmedTotal)}',
                                    icon: Iconsax.verify,
                                    iconColor: GrihoColors.emerald,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (filteredGroups.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 32),
                                child: GrihoStatusState(
                                  icon: Iconsax.receipt_item,
                                  title: 'No payments found',
                                  subtitle: 'No payments in this category.',
                                ),
                              )
                            else
                              ...filteredGroups.map((group) {
                                final isExpanded = _expandedGroupIds.contains(
                                  group.id,
                                );
                                final statusColor = _statusColor(group.status);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 14),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isExpanded
                                          ? theme.colorScheme.primary
                                          .withValues(alpha: 0.45)
                                          : theme.colorScheme.outlineVariant,
                                      width: isExpanded ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () {
                                          setState(() {
                                            if (isExpanded) {
                                              _expandedGroupIds.remove(
                                                group.id,
                                              );
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
                                                      CrossAxisAlignment
                                                          .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Text(
                                                              '৳${formatBillingAmount(group.totalAmount)}',
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
                                                              status:
                                                              group.status,
                                                              color:
                                                              statusColor,
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Row(
                                                          children: [
                                                            Icon(
                                                              Iconsax
                                                                  .personalcard,
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
                                                                FontWeight
                                                                    .w900,
                                                                letterSpacing:
                                                                0.5,
                                                                color: theme
                                                                    .colorScheme
                                                                    .primary,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Flexible(
                                                              child: Text(
                                                                '•  ${group.tenantName}',
                                                                overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                                  color: theme
                                                                      .colorScheme
                                                                      .onSurfaceVariant,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(
                                                    isExpanded
                                                        ? Iconsax.arrow_up_2
                                                        : Iconsax.arrow_down_1,
                                                    size: 18,
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              Container(
                                                padding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: theme
                                                      .colorScheme
                                                      .surfaceContainerHighest
                                                      .withValues(alpha: 0.45),
                                                  borderRadius:
                                                  BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Iconsax.buildings_2,
                                                      size: 13,
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
                                                          FontWeight
                                                              .w600,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
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
                                                  GrihoFeedback.showSuccess(
                                                    context,
                                                    'Griho ID copied.',
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
                                              if (group
                                                  .proofUrl
                                                  .isNotEmpty) ...[
                                                const SizedBox(height: 8),
                                                OutlinedButton.icon(
                                                  onPressed: () =>
                                                      _showProofPreview(
                                                        group.proofUrl,
                                                      ),
                                                  icon: const Icon(
                                                    Iconsax.gallery,
                                                    size: 17,
                                                  ),
                                                  label: const Text(
                                                    'View Payment Screenshot',
                                                  ),
                                                ),
                                              ],
                                              const SizedBox(height: 10),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: OutlinedButton.icon(
                                                      onPressed: () =>
                                                          _openPdfReceipt(
                                                            group,
                                                            share: false,
                                                          ),
                                                      icon: const Icon(
                                                        Iconsax.document_text,
                                                        size: 17,
                                                      ),
                                                      label: const Text(
                                                        'PDF Receipt',
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child:
                                                    FilledButton.tonalIcon(
                                                      onPressed: () =>
                                                          _openPdfReceipt(
                                                            group,
                                                            share: true,
                                                          ),
                                                      icon: const Icon(
                                                        Iconsax.export_3,
                                                        size: 17,
                                                      ),
                                                      label: const Text(
                                                        'Share Receipt',
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 14),
                                              Text(
                                                'Included Charges (${group.payments.length})',
                                                style: theme
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                  fontWeight:
                                                  FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
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
                                                (data['rejectionReason'] ??
                                                    '')
                                                    .toString();

                                                return Container(
                                                  margin: const EdgeInsets.only(
                                                    bottom: 8,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: theme
                                                        .colorScheme
                                                        .surfaceContainerHighest
                                                        .withValues(
                                                      alpha: 0.35,
                                                    ),
                                                    borderRadius:
                                                    BorderRadius.circular(
                                                      14,
                                                    ),
                                                    border: Border.all(
                                                      color: theme
                                                          .colorScheme
                                                          .outlineVariant
                                                          .withValues(
                                                        alpha: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
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
                                                                alpha: 0.14,
                                                              ),
                                                              borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                            ),
                                                            child: Icon(
                                                              icon,
                                                              size: 17,
                                                              color: color,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
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
                                                                    fontSize:
                                                                    14,
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
                                                            '৳${formatBillingAmount(amount is num ? amount : 0)}',
                                                            style:
                                                            const TextStyle(
                                                              fontWeight:
                                                              FontWeight
                                                                  .w900,
                                                              fontSize: 15,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (reason
                                                          .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Text(
                                                          'Rejection reason: $reason',
                                                          style: const TextStyle(
                                                            color: GrihoColors
                                                                .error,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                );
                                              }),
                                              if (group.status ==
                                                  'pending') ...[
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
                                                          Iconsax.close_circle,
                                                          size: 17,
                                                        ),
                                                        label: const Text(
                                                          'Reject',
                                                        ),
                                                        style: OutlinedButton.styleFrom(
                                                          foregroundColor:
                                                          GrihoColors.error,
                                                          side: BorderSide(
                                                            color: GrihoColors
                                                                .error
                                                                .withValues(
                                                              alpha: 0.6,
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
                                                          Iconsax.tick_circle,
                                                          size: 17,
                                                        ),
                                                        label: const Text(
                                                          'Confirm',
                                                        ),
                                                        style: FilledButton.styleFrom(
                                                          backgroundColor:
                                                          GrihoColors
                                                              .emerald,
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
          );
        },
      ),
    );
  }
}

class _PaymentGroup {
  final String id;
  final String ownerId;
  final String propertyId;
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
  final String proofUrl;
  final dynamic createdAt;

  const _PaymentGroup({
    required this.id,
    required this.ownerId,
    required this.propertyId,
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
    required this.proofUrl,
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
        color: color.withValues(alpha: 0.14),
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
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 19),
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
                  Iconsax.copy,
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
