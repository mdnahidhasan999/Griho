import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../rents/presentation/providers/rent_rate_provider.dart';
import '../../../tenants/presentation/providers/tenant_dashboard_provider.dart';
import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/monthly_bill.dart';

class TenantCurrentBillsCard extends ConsumerWidget {
  const TenantCurrentBillsCard({super.key});

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
    // Fixed space between month and year
    return '${months[date.month - 1]}${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final periodStart = ref.watch(currentBillingPeriodStartProvider);
    final billsAsync = ref.watch(currentTenantMonthlyBillsProvider);
    final tenantAsync = ref.watch(currentTenantProvider);
    final unitAsync = ref.watch(currentTenantUnitProvider);

    final unit = unitAsync.value;
    final tenant = tenantAsync.value;
    final unitId = tenant?.unitId.trim() ?? '';

    final rentRateAsync = unitId.isNotEmpty
        ? ref.watch(currentTenantRentRateProvider(unitId))
        : null;

    final unitLabel = unit != null
        ? (unit.name?.trim().isNotEmpty == true
              ? '${unit.name} (Unit${unit.unitNumber})'
              : 'Unit ${unit.unitNumber} • Floor ${unit.floorNumber}')
        : 'Assigned Unit';

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: billsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 36,
              ),
              const SizedBox(height: 8),
              const Text(
                'Unable to load current month statement.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(currentTenantMonthlyBillsProvider);
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
          data: (bills) {
            final activeRentAmount = rentRateAsync?.value?.amount;

            final hasRentInBills = bills.any(
              (b) => b.type == MonthlyBillType.rent,
            );

            final unbilledRentAmount =
                (!hasRentInBills &&
                    activeRentAmount != null &&
                    activeRentAmount > 0)
                ? activeRentAmount
                : 0.0;

            final billedTotal = bills.fold<double>(
              0,
              (sum, item) => sum + item.amount,
            );
            final totalPayable = billedTotal + unbilledRentAmount;

            final unpaidBilledTotal = bills
                .where((b) => b.status != MonthlyBillStatus.paid)
                .fold<double>(0, (sum, item) => sum + item.amount);
            final totalDue = unpaidBilledTotal + unbilledRentAmount;

            final isAllPaid = totalPayable > 0 && totalDue == 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Cycle & Unit Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              size: 20,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_formatMonthYear(periodStart)} Statement',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  unitLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isAllPaid
                            ? Colors.green.withValues(alpha: 0.14)
                            : Colors.amber.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isAllPaid
                            ? 'All Paid'
                            : totalPayable == 0
                            ? 'No Dues'
                            : 'Due',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isAllPaid
                              ? Colors.green.shade800
                              : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 2. Total Summary Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Monthly Charges',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '৳ ${_formatAmount(totalPayable)}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Remaining Due',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '৳ ${_formatAmount(totalDue)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: totalDue > 0
                                  ? theme.colorScheme.error
                                  : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // 3. Itemized Unit Rent & Utility Breakdown
                Text(
                  'Unit Charge Breakdown',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),

                // Show Unit Rent row if not yet inside `bills`
                if (!hasRentInBills &&
                    activeRentAmount != null &&
                    activeRentAmount > 0) ...[
                  _BillBreakdownRow(
                    icon: Icons.house_outlined,
                    title: 'Monthly Unit Rent',
                    subtitle: '$unitLabel • Recurring Rent',
                    amount: activeRentAmount,
                    isPaid: false,
                  ),
                  if (bills.isNotEmpty) const Divider(height: 18),
                ],

                if (bills.isEmpty &&
                    (activeRentAmount == null || activeRentAmount <= 0))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No rent or utility charges have been posted for this unit yet.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < bills.length; i++) ...[
                    _BillBreakdownRow(
                      icon: _billIcon(bills[i].type),
                      title: _billLabel(bills[i].type),
                      subtitle:
                          '${bills[i].valueType == BillingValueType.fixed ? 'Fixed' : 'Variable'} • Due: ${_formatShortDate(bills[i].dueDate)}',
                      amount: bills[i].amount,
                      isPaid: bills[i].status == MonthlyBillStatus.paid,
                    ),
                    if (i != bills.length - 1) const Divider(height: 18),
                  ],

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      context.push(RouteNames.tenantPayments);
                    },
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Pay a Bill'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static IconData _billIcon(MonthlyBillType type) {
    switch (type) {
      case MonthlyBillType.rent:
        return Icons.house_outlined;
      case MonthlyBillType.water:
        return Icons.water_drop_outlined;
      case MonthlyBillType.gas:
        return Icons.local_fire_department_outlined;
      case MonthlyBillType.electricity:
        return Icons.bolt_rounded;
      case MonthlyBillType.serviceCharge:
        return Icons.cleaning_services_outlined;
      case MonthlyBillType.garbage:
        return Icons.delete_outline_rounded;
      case MonthlyBillType.other:
        return Icons.receipt_outlined;
    }
  }

  static String _billLabel(MonthlyBillType type) {
    switch (type) {
      case MonthlyBillType.rent:
        return 'Monthly Unit Rent';
      case MonthlyBillType.water:
        return 'Water Bill';
      case MonthlyBillType.gas:
        return 'Gas Bill';
      case MonthlyBillType.electricity:
        return 'Electricity Bill';
      case MonthlyBillType.serviceCharge:
        return 'Service Charge';
      case MonthlyBillType.garbage:
        return 'Garbage Collection';
      case MonthlyBillType.other:
        return 'Other Utility Charge';
    }
  }

  static String _formatShortDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  static String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toStringAsFixed(2);
  }
}

class _BillBreakdownRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double amount;
  final bool isPaid;

  const _BillBreakdownRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isPaid,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '৳ ${amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isPaid ? 'PAID' : 'UNPAID',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isPaid ? Colors.green.shade700 : theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
