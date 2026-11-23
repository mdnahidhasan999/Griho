// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/monthly_rent.dart';
import '../../domain/entities/rent_rate.dart';

String formatRentAmount(num? amount) {
  if (amount == null) {
    return '0';
  }
  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toStringAsFixed(2);
}

String formatRentDate(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

String formatRentMonth(DateTime dateTime) {
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
  return '${months[dateTime.month - 1]} ${dateTime.year}';
}

String rentRateSourceLabel(RentRateSource source, {bool detailed = false}) {
  switch (source) {
    case RentRateSource.initial:
      return detailed ? 'Initial Tenancy Agreement' : 'Initial Lease';
    case RentRateSource.property:
      return detailed ? 'Property-Wide Adjustment' : 'Property Scope';
    case RentRateSource.floor:
      return detailed ? 'Floor-Level Adjustment' : 'Floor Scope';
    case RentRateSource.unit:
      return detailed ? 'Unit-Specific Adjustment' : 'Unit Scope';
  }
}

class RentOccupancyChip extends StatelessWidget {
  const RentOccupancyChip({super.key, required this.isOccupied});

  final bool isOccupied;

  @override
  Widget build(BuildContext context) {
    final color = isOccupied ? GrihoColors.emerald : Colors.blueAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOccupied ? 'Occupied' : 'Vacant',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class MonthlyRentStatusChip extends StatelessWidget {
  const MonthlyRentStatusChip({super.key, required this.status});

  final MonthlyRentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      MonthlyRentStatus.paid => ('Paid', GrihoColors.emerald),
      MonthlyRentStatus.partiallyPaid => (
        'Partially Paid',
        GrihoColors.warning,
      ),
      MonthlyRentStatus.unpaid => ('Unpaid', Colors.blueAccent),
      MonthlyRentStatus.overdue => ('Overdue', GrihoColors.error),
      MonthlyRentStatus.cancelled => ('Cancelled', Colors.blueGrey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class RentSourceChip extends StatelessWidget {
  const RentSourceChip({super.key, required this.source});

  final RentRateSource source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        rentRateSourceLabel(source),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
