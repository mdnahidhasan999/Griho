// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/monthly_bill.dart';

String formatBillingAmount(num? amount) {
  if (amount == null) {
    return '0';
  }
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toStringAsFixed(2);
}

String formatBillingMonthYear(DateTime date) {
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

String formatBillingShortDate(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

String billingChargeTypeLabel(BillingChargeType type) {
  switch (type) {
    case BillingChargeType.water:
      return 'Water Bill';
    case BillingChargeType.gas:
      return 'Gas Bill';
    case BillingChargeType.garbage:
      return 'Garbage Collection';
    case BillingChargeType.serviceCharge:
      return 'Service / Maintenance';
    case BillingChargeType.electricity:
      return 'Electricity Bill';
    case BillingChargeType.other:
      return 'Other Utility';
  }
}

IconData billingChargeTypeIcon(BillingChargeType type) {
  switch (type) {
    case BillingChargeType.water:
      return Iconsax.drop;
    case BillingChargeType.gas:
      return Iconsax.flash_1;
    case BillingChargeType.garbage:
      return Iconsax.trash;
    case BillingChargeType.serviceCharge:
      return Iconsax.broom;
    case BillingChargeType.electricity:
      return Iconsax.electricity;
    case BillingChargeType.other:
      return Iconsax.receipt_item;
  }
}

String monthlyBillTypeLabel(MonthlyBillType type) {
  switch (type) {
    case MonthlyBillType.rent:
      return 'House Rent';
    case MonthlyBillType.water:
      return 'Water Bill';
    case MonthlyBillType.gas:
      return 'Gas Bill';
    case MonthlyBillType.garbage:
      return 'Garbage Fee';
    case MonthlyBillType.serviceCharge:
      return 'Service Charge';
    case MonthlyBillType.electricity:
      return 'Electricity Bill';
    case MonthlyBillType.other:
      return 'Utility Bill';
  }
}

IconData monthlyBillTypeIcon(MonthlyBillType type) {
  switch (type) {
    case MonthlyBillType.rent:
      return Iconsax.home_2;
    case MonthlyBillType.water:
      return Iconsax.drop;
    case MonthlyBillType.gas:
      return Iconsax.flash_1;
    case MonthlyBillType.garbage:
      return Iconsax.trash;
    case MonthlyBillType.serviceCharge:
      return Iconsax.broom;
    case MonthlyBillType.electricity:
      return Iconsax.electricity;
    case MonthlyBillType.other:
      return Iconsax.receipt_item;
  }
}

String cleanBillingError(Object error) {
  return error.toString().replaceFirst(
    RegExp(r'^(Exception: |Invalid argument\(s\): |Bad state: )'),
    '',
  );
}

class BillingStatusChip extends StatelessWidget {
  const BillingStatusChip({super.key, required this.status});

  final MonthlyBillStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      MonthlyBillStatus.paid => ('PAID', GrihoColors.emerald),
      MonthlyBillStatus.partiallyPaid => ('PARTIAL', GrihoColors.warning),
      MonthlyBillStatus.overdue => ('OVERDUE', GrihoColors.error),
      MonthlyBillStatus.cancelled => ('CANCELLED', Colors.blueGrey),
      MonthlyBillStatus.unpaid => ('UNPAID', GrihoColors.warning),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}
