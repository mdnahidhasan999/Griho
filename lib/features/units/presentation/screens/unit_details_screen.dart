import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../domain/entities/unit.dart';
import '../controllers/unit_controller.dart';
import '../providers/unit_usecase_provider.dart';
import '../providers/property_units_provider.dart';

class UnitDetailsScreen extends ConsumerStatefulWidget {
  final String unitId;

  const UnitDetailsScreen({
    super.key,
    required this.unitId,
  });

  @override
  ConsumerState<UnitDetailsScreen> createState() =>
      _UnitDetailsScreenState();
}

class _UnitDetailsScreenState
    extends ConsumerState<UnitDetailsScreen> {
  Unit? _unit;

  bool _isLoading = true;
  bool _isDeleting = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUnit();
  }

  Future<void> _loadUnit() async {
    try {
      final getUnit = ref.read(
        getUnitProvider,
      );

      final unit = await getUnit(
        widget.unitId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _unit = unit;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _editUnit() async {
    final unit = _unit;

    if (unit == null || _isDeleting) {
      return;
    }

    final updatedUnit = await context.push<Unit>(
      RouteNames.editUnit.replaceFirst(
        ':unitId',
        unit.id,
      ),
      extra: unit,
    );

    if (!mounted || updatedUnit == null) {
      return;
    }

    setState(() {
      _unit = updatedUnit;
    });

    ref.invalidate(
      propertyUnitsProvider(
        updatedUnit.propertyId,
      ),
    );
  }

  Future<void> _deleteUnit() async {
    final unit = _unit;

    if (unit == null || _isDeleting) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Unit?',
          ),
          content: Text(
            'Are you sure you want to delete '
                '"${unit.unitNumber}"?\n\n'
                'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    final controller = ref.read(
      unitControllerProvider.notifier,
    );

    final success = await controller.deleteUnit(
      unitId: unit.id,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ref.invalidate(
        propertyUnitsProvider(
          unit.propertyId,
        ),
      );

      context.pop();

      return;
    }

    setState(() {
      _isDeleting = false;
    });

    final errorMessage = ref.read(
      unitControllerProvider,
    ).errorMessage;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage ??
              'Unable to delete unit.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Unit Details',
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Unit Details',
          ),
        ),
        body: _ErrorView(
          message: _errorMessage!,
          onRetry: _loadUnit,
        ),
      );
    }

    final unit = _unit;

    if (unit == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Unit Details',
          ),
        ),
        body: const _NotFoundView(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Unit Details',
        ),
        actions: [
          IconButton(
            tooltip: 'Edit Unit',
            icon: const Icon(
              Icons.edit_outlined,
            ),
            onPressed:
            _isDeleting ? null : _editUnit,
          ),
          IconButton(
            tooltip: 'Delete Unit',
            icon: const Icon(
              Icons.delete_outline,
            ),
            onPressed:
            _isDeleting ? null : _deleteUnit,
          ),
        ],
      ),
      body: Stack(
        children: [
          _UnitDetails(
            unit: unit,
          ),

          if (_isDeleting)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize:
                        MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Deleting unit...',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UnitDetails extends StatelessWidget {
  final Unit unit;

  const _UnitDetails({
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.apartment_outlined,
                  size: 52,
                ),
                const SizedBox(height: 16),
                Text(
                  unit.unitNumber,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  unit.name?.trim().isNotEmpty == true
                      ? unit.name!
                      : 'Unit',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        _InfoCard(
          title: 'Unit Information',
          children: [
            _InfoRow(
              label: 'Floor',
              value: unit.floorNumber.toString(),
            ),
            _InfoRow(
              label: 'Unit Number',
              value: unit.unitNumber,
            ),
            _InfoRow(
              label: 'Status',
              value: _statusLabel(
                unit.status,
              ),
            ),
            _InfoRow(
              label: 'Monthly Rent',
              value: unit.monthlyRent != null
                  ? '৳ ${unit.monthlyRent!.toStringAsFixed(0)}'
                  : 'Not provided',
            ),
            _InfoRow(
              label: 'Unit Name',
              value: unit.name?.trim().isNotEmpty == true
                  ? unit.name!
                  : 'Not provided',
            ),
          ],
        ),
      ],
    );
  }

  String _statusLabel(
      UnitStatus status,
      ) {
    switch (status) {
      case UnitStatus.available:
        return 'Available';

      case UnitStatus.occupied:
        return 'Occupied';

      case UnitStatus.reserved:
        return 'Reserved';

      case UnitStatus.inactive:
        return 'Inactive';
    }
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Unit not found.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}