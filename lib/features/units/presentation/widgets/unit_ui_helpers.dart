// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../domain/entities/unit.dart';

String formatUnitFloorLabel(int floor) {
  if (floor == 0) {
    return 'Ground Floor';
  }
  if (floor == 1) {
    return '1st Floor';
  }
  if (floor == 2) {
    return '2nd Floor';
  }
  if (floor == 3) {
    return '3rd Floor';
  }
  return '$floor-th Floor';
}

String unitStatusLabel(UnitStatus status, {bool detailed = false}) {
  switch (status) {
    case UnitStatus.available:
      return detailed ? 'Available / Vacant' : 'Available';
    case UnitStatus.occupied:
      return 'Occupied';
    case UnitStatus.reserved:
      return 'Reserved';
    case UnitStatus.inactive:
      return detailed ? 'Inactive / Maintenance' : 'Inactive';
  }
}

IconData unitStatusIcon(UnitStatus status) {
  switch (status) {
    case UnitStatus.available:
      return Iconsax.tick_circle;
    case UnitStatus.occupied:
      return Iconsax.user;
    case UnitStatus.reserved:
      return Iconsax.bookmark;
    case UnitStatus.inactive:
      return Iconsax.close_circle;
  }
}

Color unitStatusColor(UnitStatus status) {
  switch (status) {
    case UnitStatus.available:
      return Colors.blueAccent;
    case UnitStatus.occupied:
      return GrihoColors.emerald;
    case UnitStatus.reserved:
      return GrihoColors.warning;
    case UnitStatus.inactive:
      return Colors.blueGrey;
  }
}

String unitStatusDescription(UnitStatus status) {
  switch (status) {
    case UnitStatus.available:
      return 'This unit is marked as vacant and can be assigned to new residents in tenancy workflows.';
    case UnitStatus.occupied:
      return 'This unit currently has an active tenancy associated with it.';
    case UnitStatus.reserved:
      return 'This unit is on temporary hold and will be hidden from instant availability.';
    case UnitStatus.inactive:
      return 'This unit is under maintenance or out of service and cannot be allocated.';
  }
}

class UnitStatusChip extends StatelessWidget {
  const UnitStatusChip({super.key, required this.status});

  final UnitStatus status;

  @override
  Widget build(BuildContext context) {
    final color = unitStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.14),
      ),
      child: Text(
        unitStatusLabel(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
