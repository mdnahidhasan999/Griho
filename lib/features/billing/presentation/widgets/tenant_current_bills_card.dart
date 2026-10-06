import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/monthly_bill.dart';
import '../providers/monthly_bill_provider.dart';

class TenantCurrentBillsCard extends ConsumerWidget {
  const TenantCurrentBillsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();

    final billingPeriodStart = DateTime(now.year, now.month, 1);

    final tenantUserId = FirebaseAuth.instance.currentUser?.uid.trim();

    if (tenantUserId == null || tenantUserId.isEmpty) {
      return const Card(
        elevation: 0,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: _BillsErrorMessage(message: 'You are not authenticated.'),
        ),
      );
    }

    final billsProvider = monthlyBillsByTenantAndPeriodProvider((
      tenantUserId: tenantUserId,
      billingPeriodStart: billingPeriodStart,
    ));

    final billsAsync = ref.watch(billsProvider);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: billsAsync.when(
          loading: () => const _BillsLoading(),
          error: (error, stackTrace) {
            return _BillsError(
              onRetry: () {
                ref.invalidate(billsProvider);
              },
            );
          },
          data: (bills) {
            return _BillsContent(
              bills: bills,
              billingPeriodStart: billingPeriodStart,
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// BILLS CONTENT
// ============================================================================

class _BillsContent extends StatelessWidget {
  final List<MonthlyBill> bills;
  final DateTime billingPeriodStart;

  const _BillsContent({required this.bills, required this.billingPeriodStart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final totalAmount = bills.fold<double>(
      0,
      (total, bill) => total + bill.amount,
    );

    if (bills.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BillsHeader(billingPeriodStart: billingPeriodStart, totalAmount: 0),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 34,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  'No bills for this month',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your monthly bills will appear here when they are generated.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BillsHeader(
          billingPeriodStart: billingPeriodStart,
          totalAmount: totalAmount,
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < bills.length; index++) ...[
          _BillItem(bill: bills[index]),
          if (index != bills.length - 1) const Divider(height: 20),
        ],
      ],
    );
  }
}

// ============================================================================
// HEADER
// ============================================================================

class _BillsHeader extends StatelessWidget {
  final DateTime billingPeriodStart;
  final double totalAmount;

  const _BillsHeader({
    required this.billingPeriodStart,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.receipt_long_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Bills',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatMonth(billingPeriodStart),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Text(
          '৳ ${_formatAmount(totalAmount)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// BILL ITEM
// ============================================================================

class _BillItem extends StatelessWidget {
  final MonthlyBill bill;

  const _BillItem({required this.bill});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final typeLabel = _billTypeLabel(bill.type);
    final statusLabel = _billStatusLabel(bill.status);
    final statusColor = _billStatusColor(context, bill.status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            _billTypeIcon(bill.type),
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                typeLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Due ${_formatDate(bill.dueDate)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '৳ ${_formatAmount(bill.amount)}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// LOADING
// ============================================================================

class _BillsLoading extends StatelessWidget {
  const _BillsLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 90,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

// ============================================================================
// ERROR
// ============================================================================

class _BillsError extends StatelessWidget {
  final VoidCallback onRetry;

  const _BillsError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(
          Icons.receipt_long_outlined,
          size: 34,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 8),
        Text(
          'Could not load your bills.',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

// ============================================================================
// SIMPLE ERROR MESSAGE
// ============================================================================

class _BillsErrorMessage extends StatelessWidget {
  final String message;

  const _BillsErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

// ============================================================================
// BILL TYPE
// ============================================================================

String _billTypeLabel(MonthlyBillType type) {
  switch (type) {
    case MonthlyBillType.rent:
      return 'Rent';

    case MonthlyBillType.water:
      return 'Water';

    case MonthlyBillType.electricity:
      return 'Electricity';

    case MonthlyBillType.gas:
      return 'Gas';

    case MonthlyBillType.garbage:
      return 'Garbage';

    case MonthlyBillType.serviceCharge:
      return 'Service Charge';

    case MonthlyBillType.other:
      return 'Other';
  }
}

IconData _billTypeIcon(MonthlyBillType type) {
  switch (type) {
    case MonthlyBillType.rent:
      return Icons.home_work_outlined;

    case MonthlyBillType.water:
      return Icons.water_drop_outlined;

    case MonthlyBillType.electricity:
      return Icons.bolt_outlined;

    case MonthlyBillType.gas:
      return Icons.local_fire_department_outlined;

    case MonthlyBillType.garbage:
      return Icons.delete_outline;

    case MonthlyBillType.serviceCharge:
      return Icons.miscellaneous_services_outlined;

    case MonthlyBillType.other:
      return Icons.receipt_long_outlined;
  }
}

// ============================================================================
// BILL STATUS
// ============================================================================

String _billStatusLabel(MonthlyBillStatus status) {
  switch (status) {
    case MonthlyBillStatus.pending:
      return 'Amount Required';

    case MonthlyBillStatus.paid:
      return 'Paid';

    case MonthlyBillStatus.cancelled:
      return 'Cancelled';

    case MonthlyBillStatus.overdue:
      return 'Overdue';

    case MonthlyBillStatus.partiallyPaid:
      return 'Partially Paid';

    case MonthlyBillStatus.unpaid:
      return 'Unpaid';
  }
}

Color _billStatusColor(BuildContext context, MonthlyBillStatus status) {
  final theme = Theme.of(context);

  switch (status) {
    case MonthlyBillStatus.pending:
      return theme.colorScheme.primary;

    case MonthlyBillStatus.paid:
      return Colors.green;

    case MonthlyBillStatus.overdue:
      return theme.colorScheme.error;

    case MonthlyBillStatus.cancelled:
      return theme.colorScheme.onSurfaceVariant;

    case MonthlyBillStatus.partiallyPaid:
      return Colors.orange;

    case MonthlyBillStatus.unpaid:
      return Colors.orange;
  }
}

// ============================================================================
// FORMATTERS
// ============================================================================

String _formatMonth(DateTime date) {
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

String _formatDate(DateTime date) {
  final local = date.toLocal();

  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year}';
}

String _formatAmount(double amount) {
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }

  return amount.toStringAsFixed(2);
}
