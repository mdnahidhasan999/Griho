// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/services/pdf_receipt_service.dart';
import '../../../rents/presentation/providers/rent_rate_provider.dart';
import '../../../tenants/presentation/providers/tenant_dashboard_provider.dart';
import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/monthly_bill.dart';
import 'billing_ui_helpers.dart';

class TenantCurrentBillsCard extends ConsumerWidget {
  const TenantCurrentBillsCard({super.key});

  Future<void> _exportCurrentInvoicePdf(
    BuildContext context,
    WidgetRef ref, {
    required DateTime periodStart,
    required List<MonthlyBill> bills,
    required double unbilledRentAmount,
    required String unitLabel,
    required bool share,
  }) async {
    try {
      final tenant = ref.read(currentTenantProvider).value;
      final property = ref.read(currentTenantPropertyProvider).value;
      final periodLabel = formatBillingMonthYear(periodStart);

      final items = <ReceiptLineItem>[
        if (unbilledRentAmount > 0)
          ReceiptLineItem(
            title: 'Monthly Unit Rent',
            periodLabel: periodLabel,
            amount: unbilledRentAmount,
          ),
        for (final bill in bills)
          ReceiptLineItem(
            title: bill.title?.trim().isNotEmpty == true
                ? bill.title!.trim()
                : monthlyBillTypeLabel(bill.type),
            periodLabel: periodLabel,
            amount: bill.amount,
          ),
      ];

      final paidAmount = bills.fold<double>(
        0.0,
        (sum, bill) => sum + bill.paidAmount,
      );
      final dueDate = bills.isNotEmpty
          ? bills.first.dueDate
          : DateTime(periodStart.year, periodStart.month, 10);

      final invoiceNo =
          'INV-${periodStart.year}${periodStart.month.toString().padLeft(2, '0')}';

      final invoiceData = MonthlyInvoicePdfData(
        invoiceNumber: invoiceNo,
        billingPeriodLabel: periodLabel,
        status: bills.any((b) => b.isOverdue)
            ? 'overdue'
            : paidAmount > 0 &&
                  bills.fold<double>(0, (s, b) => s + b.remainingAmount) +
                          unbilledRentAmount >
                      0
            ? 'partiallyPaid'
            : bills.fold<double>(0, (s, b) => s + b.remainingAmount) +
                      unbilledRentAmount <=
                  0
            ? 'paid'
            : 'unpaid',
        dueDate: dueDate,
        tenantName: tenant?.name ?? 'Resident',
        tenantPhone: tenant?.phone,
        propertyName: property?.name ?? 'Property',
        propertyAddress: property?.address,
        unitName: unitLabel,
        paidAmount: paidAmount,
        items: items,
      );

      if (share) {
        await PdfReceiptService.shareInvoicePdf(invoiceData);
      } else {
        await PdfReceiptService.previewOrPrintInvoice(invoiceData);
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      GrihoFeedback.showError(
        context,
        'Unable to generate invoice PDF: $error',
      );
    }
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
              ? '${unit.name} (Unit ${unit.unitNumber})'
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
          error: (_, _) => GrihoStatusState(
            icon: Iconsax.warning_2,
            title: 'Unable to load statement',
            subtitle: 'Could not load current month statement.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(currentTenantMonthlyBillsProvider),
          ),
          data: (bills) {
            final activeRentAmount = rentRateAsync?.value?.amount;
            final hasRentInBills = bills.any(
              (bill) => bill.type == MonthlyBillType.rent,
            );
            final unbilledRentAmount =
                (!hasRentInBills &&
                    activeRentAmount != null &&
                    activeRentAmount > 0)
                ? activeRentAmount
                : 0.0;

            final billedTotal = bills.fold<double>(
              0,
              (sum, bill) => sum + bill.amount,
            );
            final totalPayable = billedTotal + unbilledRentAmount;
            final remainingDue = bills.fold<double>(
              0,
              (sum, bill) => sum + bill.remainingAmount,
            );
            final totalDue = remainingDue + unbilledRentAmount;

            final isAllPaid = totalPayable > 0 && totalDue <= 0.001;
            final hasNoCharges = totalPayable <= 0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                              Iconsax.receipt_item,
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
                                  '${formatBillingMonthYear(periodStart)} Statement',
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
                            ? GrihoColors.emerald.withValues(alpha: 0.14)
                            : hasNoCharges
                            ? theme.colorScheme.surfaceContainerHighest
                            : GrihoColors.warning.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isAllPaid
                            ? 'All Paid'
                            : hasNoCharges
                            ? 'No Dues'
                            : 'Due',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isAllPaid
                              ? GrihoColors.emerald
                              : hasNoCharges
                              ? theme.colorScheme.onSurfaceVariant
                              : GrihoColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
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
                            '৳ ${formatBillingAmount(totalPayable)}',
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
                            '৳ ${formatBillingAmount(totalDue)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: totalDue > 0
                                  ? GrihoColors.error
                                  : GrihoColors.emerald,
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
                Text(
                  'Unit Charge Breakdown',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                if (unbilledRentAmount > 0) ...[
                  _BillBreakdownRow(
                    icon: Iconsax.home_2,
                    title: 'Monthly Unit Rent',
                    subtitle: '$unitLabel • Recurring Rent',
                    amount: unbilledRentAmount,
                    remainingAmount: unbilledRentAmount,
                  ),
                  if (bills.isNotEmpty) const Divider(height: 18),
                ],
                if (bills.isEmpty && unbilledRentAmount <= 0)
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
                      icon: monthlyBillTypeIcon(bills[i].type),
                      title: bills[i].title?.trim().isNotEmpty == true
                          ? bills[i].title!.trim()
                          : monthlyBillTypeLabel(bills[i].type),
                      subtitle:
                          '${bills[i].valueType == BillingValueType.fixed ? 'Fixed' : 'Variable'} • Due: ${formatBillingShortDate(bills[i].dueDate)}',
                      amount: bills[i].amount,
                      remainingAmount: bills[i].remainingAmount,
                    ),
                    if (i != bills.length - 1) const Divider(height: 18),
                  ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GrihoPrimaryButton(
                        label: 'Pay a Bill',
                        icon: Iconsax.wallet_3,
                        onPressed: () =>
                            context.push(RouteNames.tenantPayments),
                      ),
                    ),
                    if (!hasNoCharges) ...[
                      const SizedBox(width: 10),
                      IconButton.outlined(
                        tooltip: 'Print / Save Invoice PDF',
                        onPressed: () => _exportCurrentInvoicePdf(
                          context,
                          ref,
                          periodStart: periodStart,
                          bills: bills,
                          unbilledRentAmount: unbilledRentAmount,
                          unitLabel: unitLabel,
                          share: false,
                        ),
                        icon: const Icon(Iconsax.document_text, size: 20),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: 'Share Invoice PDF',
                        onPressed: () => _exportCurrentInvoicePdf(
                          context,
                          ref,
                          periodStart: periodStart,
                          bills: bills,
                          unbilledRentAmount: unbilledRentAmount,
                          unitLabel: unitLabel,
                          share: true,
                        ),
                        icon: const Icon(Iconsax.export_3, size: 20),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BillBreakdownRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double amount;
  final double remainingAmount;

  const _BillBreakdownRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.remainingAmount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPaid = remainingAmount <= 0.001;
    final isPartiallyPaid = !isPaid && remainingAmount < amount;

    final status = isPaid
        ? 'PAID'
        : isPartiallyPaid
        ? 'PARTIAL'
        : 'UNPAID';

    final statusColor = isPaid
        ? GrihoColors.emerald
        : isPartiallyPaid
        ? GrihoColors.warning
        : GrihoColors.error;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: theme.colorScheme.primary),
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
              '৳ ${formatBillingAmount(amount)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
