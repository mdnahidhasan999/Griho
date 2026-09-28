import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/update_billing_rule_request.dart';
import '../providers/billing_rule_provider.dart';

class EditBillingRuleScreen extends ConsumerStatefulWidget {
  final BillingRule rule;

  const EditBillingRuleScreen({
    super.key,
    required this.rule,
  });

  @override
  ConsumerState<EditBillingRuleScreen> createState() =>
      _EditBillingRuleScreenState();
}

class _EditBillingRuleScreenState
    extends ConsumerState<EditBillingRuleScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _amountController;

  late BillingChargeType _chargeType;
  late BillingValueType _valueType;

  late DateTime _effectiveFrom;
  DateTime? _effectiveTo;

  bool _isActive = true;
  bool _isSaving = false;
  bool _isDeactivating = false;

  @override
  void initState() {
    super.initState();

    final rule = widget.rule;

    _titleController = TextEditingController(
      text: rule.title ?? '',
    );

    _amountController = TextEditingController(
      text: rule.amount?.toString() ?? '',
    );

    _chargeType = rule.chargeType;
    _valueType = rule.valueType;
    _effectiveFrom = rule.effectiveFrom;
    _effectiveTo = rule.effectiveTo;
    _isActive = rule.isActive;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Billing Rule',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            32,
          ),
          children: [
            _buildHeader(theme),

            const SizedBox(height: 24),

            // ============================================================
            // TITLE
            // ============================================================

            TextFormField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Example: Monthly Water Bill',
                prefixIcon: Icon(
                  Icons.title_outlined,
                ),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // ============================================================
            // CHARGE TYPE
            // ============================================================

            DropdownButtonFormField<BillingChargeType>(
              initialValue: _chargeType,
              decoration: const InputDecoration(
                labelText: 'Charge Type',
                prefixIcon: Icon(
                  Icons.receipt_long_outlined,
                ),
                border: OutlineInputBorder(),
              ),
              items: BillingChargeType.values.map(
                    (type) {
                  return DropdownMenuItem<BillingChargeType>(
                    value: type,
                    child: Text(
                      _chargeTypeLabel(type),
                    ),
                  );
                },
              ).toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _chargeType = value;
                });
              },
            ),

            const SizedBox(height: 16),

            // ============================================================
            // VALUE TYPE
            // ============================================================

            DropdownButtonFormField<BillingValueType>(
              initialValue: _valueType,
              decoration: const InputDecoration(
                labelText: 'Value Type',
                prefixIcon: Icon(
                  Icons.tune_outlined,
                ),
                border: OutlineInputBorder(),
              ),
              items: BillingValueType.values.map(
                    (type) {
                  return DropdownMenuItem<BillingValueType>(
                    value: type,
                    child: Text(
                      _valueTypeLabel(type),
                    ),
                  );
                },
              ).toList(),
              onChanged: _isSaving
                  ? null
                  : (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _valueType = value;

                  if (value ==
                      BillingValueType.variable) {
                    _amountController.clear();
                  }
                });
              },
            ),

            const SizedBox(height: 16),

            // ============================================================
            // AMOUNT
            // ============================================================

            if (_valueType == BillingValueType.fixed)
              TextFormField(
                controller: _amountController,
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction:
                TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                  prefixText: '৳ ',
                  prefixIcon: Icon(
                    Icons.payments_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_valueType ==
                      BillingValueType.variable) {
                    return null;
                  }

                  final text =
                      value?.trim() ?? '';

                  if (text.isEmpty) {
                    return 'Amount is required.';
                  }

                  final amount =
                  double.tryParse(text);

                  if (amount == null) {
                    return 'Enter a valid amount.';
                  }

                  if (amount < 0) {
                    return 'Amount cannot be negative.';
                  }

                  return null;
                },
              ),

            if (_valueType == BillingValueType.fixed)
              const SizedBox(height: 24),

            // ============================================================
            // EFFECTIVE FROM
            // ============================================================

            _DateField(
              label: 'Effective From',
              date: _effectiveFrom,
              icon: Icons.calendar_month_outlined,
              enabled: !_isSaving,
              onTap: () => _selectEffectiveFrom(
                context,
              ),
            ),

            const SizedBox(height: 16),

            // ============================================================
            // EFFECTIVE TO
            // ============================================================

            _DateField(
              label: 'Effective To',
              date: _effectiveTo,
              icon: Icons.event_busy_outlined,
              enabled: !_isSaving,
              emptyText: 'No end date',
              onTap: () => _selectEffectiveTo(
                context,
              ),
              onClear: _effectiveTo == null
                  ? null
                  : () {
                setState(() {
                  _effectiveTo = null;
                });
              },
            ),

            const SizedBox(height: 20),

            // ============================================================
            // ACTIVE STATUS
            // ============================================================

            Card(
              child: SwitchListTile(
                value: _isActive,
                onChanged: _isSaving
                    ? null
                    : (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
                title: const Text(
                  'Active',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _isActive
                      ? 'This billing rule is currently active.'
                      : 'This billing rule is inactive.',
                ),
                secondary: Icon(
                  _isActive
                      ? Icons.check_circle_outline
                      : Icons.pause_circle_outline,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ============================================================
            // UPDATE BUTTON
            // ============================================================

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isSaving ||
                    _isDeactivating
                    ? null
                    : _updateBillingRule,
                icon: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.save_outlined,
                ),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : 'Save Changes',
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ============================================================
            // DEACTIVATE BUTTON
            // ============================================================

            if (widget.rule.isActive)
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed:
                  _isSaving ||
                      _isDeactivating
                      ? null
                      : _confirmDeactivate,
                  icon: _isDeactivating
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(
                    Icons.pause_circle_outline,
                  ),
                  label: Text(
                    _isDeactivating
                        ? 'Deactivating...'
                        : 'Deactivate Rule',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final title = widget.rule.title?.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color:
                theme.colorScheme.primaryContainer,
                borderRadius:
                BorderRadius.circular(12),
              ),
              child: Icon(
                _chargeTypeIcon(_chargeType),
                color:
                theme.colorScheme
                    .onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    title?.isNotEmpty == true
                        ? title!
                        : _chargeTypeLabel(
                      _chargeType,
                    ),
                    style: theme
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Edit billing rule details',
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
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // UPDATE
  // ========================================================================

  Future<void> _updateBillingRule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_effectiveTo != null &&
        _effectiveTo!.isBefore(_effectiveFrom)) {
      _showError(
        'Effective To cannot be before Effective From.',
      );
      return;
    }

    double? amount;

    if (_valueType == BillingValueType.fixed) {
      amount = double.tryParse(
        _amountController.text.trim(),
      );

      if (amount == null) {
        _showError(
          'Please enter a valid amount.',
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final request = UpdateBillingRuleRequest(
        ruleId: widget.rule.id,
        ownerId: widget.rule.ownerId,
        chargeType: _chargeType,
        valueType: _valueType,
        amount: amount,
        title: _normalizedTitle,
        effectiveFrom: _effectiveFrom,
        effectiveTo: _effectiveTo,
        isActive: _isActive,
      );

      await ref.read(
        updateBillingRuleProvider,
      )(request);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Billing rule updated successfully.',
          ),
        ),
      );

      context.pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        'Unable to update billing rule.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ========================================================================
  // DEACTIVATE
  // ========================================================================

  Future<void> _confirmDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Deactivate Billing Rule?',
          ),
          content: const Text(
            'This billing rule will no longer be active. '
                'You can keep its record for historical purposes.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(true);
              },
              child: const Text(
                'Deactivate',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _deactivateBillingRule();
  }

  Future<void> _deactivateBillingRule() async {
    setState(() {
      _isDeactivating = true;
    });

    try {
      await ref.read(
        deactivateBillingRuleProvider,
      )(
        ruleId: widget.rule.id,
        ownerId: widget.rule.ownerId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Billing rule deactivated successfully.',
          ),
        ),
      );

      context.pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(
        'Unable to deactivate billing rule.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeactivating = false;
        });
      }
    }
  }

  // ========================================================================
  // DATE PICKERS
  // ========================================================================

  Future<void> _selectEffectiveFrom(
      BuildContext context,
      ) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _effectiveFrom = selected;
    });
  }

  Future<void> _selectEffectiveTo(
      BuildContext context,
      ) async {
    final selected = await showDatePicker(
      context: context,
      initialDate:
      _effectiveTo ?? _effectiveFrom,
      firstDate: _effectiveFrom,
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _effectiveTo = selected;
    });
  }

  // ========================================================================
  // HELPERS
  // ========================================================================

  String? get _normalizedTitle {
    final value = _titleController.text.trim();

    return value.isEmpty ? null : value;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  static String _chargeTypeLabel(
      BillingChargeType type,
      ) {
    switch (type) {
      case BillingChargeType.water:
        return 'Water';

      case BillingChargeType.gas:
        return 'Gas';

      case BillingChargeType.garbage:
        return 'Garbage';

      case BillingChargeType.serviceCharge:
        return 'Service Charge';

      case BillingChargeType.electricity:
        return 'Electricity';

      case BillingChargeType.other:
        return 'Other';
    }
  }

  static IconData _chargeTypeIcon(
      BillingChargeType type,
      ) {
    switch (type) {
      case BillingChargeType.water:
        return Icons.water_drop_outlined;

      case BillingChargeType.gas:
        return Icons.local_fire_department_outlined;

      case BillingChargeType.garbage:
        return Icons.delete_outline;

      case BillingChargeType.serviceCharge:
        return Icons.build_outlined;

      case BillingChargeType.electricity:
        return Icons.bolt_outlined;

      case BillingChargeType.other:
        return Icons.receipt_long_outlined;
    }
  }

  static String _valueTypeLabel(
      BillingValueType type,
      ) {
    switch (type) {
      case BillingValueType.fixed:
        return 'Fixed';

      case BillingValueType.variable:
        return 'Variable';
    }
  }
}

// ============================================================================
// DATE FIELD
// ============================================================================

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final IconData icon;
  final bool enabled;
  final String emptyText;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateField({
    required this.label,
    required this.date,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.emptyText = 'Select date',
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: onClear == null
              ? null
              : IconButton(
            tooltip: 'Clear',
            onPressed: enabled
                ? onClear
                : null,
            icon: const Icon(
              Icons.clear,
            ),
          ),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          date == null
              ? emptyText
              : _formatDate(date!),
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final day =
    date.day.toString().padLeft(2, '0');

    final month =
    date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }
}