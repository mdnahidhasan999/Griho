import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/update_billing_rule_request.dart';
import '../providers/billing_rule_provider.dart';

class EditBillingRuleScreen extends ConsumerStatefulWidget {
  final BillingRule rule;

  const EditBillingRuleScreen({super.key, required this.rule});

  @override
  ConsumerState<EditBillingRuleScreen> createState() =>
      _EditBillingRuleScreenState();
}

class _EditBillingRuleScreenState extends ConsumerState<EditBillingRuleScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _amountController;

  late DateTime _effectiveFrom;
  DateTime? _effectiveTo;

  late bool _isActive;

  bool _isSaving = false;
  bool _isDeactivating = false;

  bool get _isBusy => _isSaving || _isDeactivating;

  BillingRule get _rule => widget.rule;

  bool get _isFixed => _rule.valueType == BillingValueType.fixed;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: _rule.title ?? '');

    _amountController = TextEditingController(text: _rule.amount.toString());

    _effectiveFrom = _normalizeMonth(_rule.effectiveFrom);

    _effectiveTo = _rule.effectiveTo == null
        ? null
        : _normalizeMonth(_rule.effectiveTo!);

    _isActive = _rule.isActive;
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
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _buildHeader(theme),

            const SizedBox(height: 24),

            // TITLE
            TextFormField(
              controller: _titleController,
              enabled: !_isBusy,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Example: Monthly Water Bill',
                prefixIcon: Icon(Icons.title_outlined),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // CHARGE TYPE
            //
            // Charge type is immutable for an existing rule.
            // Create a new billing rule to use another charge type.
            DropdownButtonFormField<BillingChargeType>(
              initialValue: _rule.chargeType,
              decoration: const InputDecoration(
                labelText: 'Charge Type',
                prefixIcon: Icon(Icons.receipt_long_outlined),
                border: OutlineInputBorder(),
              ),
              items: BillingChargeType.values.map((type) {
                return DropdownMenuItem<BillingChargeType>(
                  value: type,
                  child: Text(_chargeTypeLabel(type)),
                );
              }).toList(),
              onChanged: null,
            ),

            const SizedBox(height: 8),

            Text(
              'Charge Type cannot be changed for an existing rule. '
              'Create a new rule to use another charge type.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 16),

            // VALUE TYPE
            //
            // Fixed and Variable are not interchangeable when editing
            // an existing rule. This avoids a mismatch with Firestore
            // validation and recurring-rule versioning.
            DropdownButtonFormField<BillingValueType>(
              initialValue: _rule.valueType,
              decoration: const InputDecoration(
                labelText: 'Value Type',
                prefixIcon: Icon(Icons.tune_outlined),
                border: OutlineInputBorder(),
              ),
              items: BillingValueType.values.map((type) {
                return DropdownMenuItem<BillingValueType>(
                  value: type,
                  child: Text(_valueTypeLabel(type)),
                );
              }).toList(),
              onChanged: null,
            ),

            const SizedBox(height: 8),

            Text(
              _isFixed
                  ? 'Fixed rules recur according to their effective dates.'
                  : 'Variable rules apply to one month only. '
                        'Their amount is entered here and the rule expires '
                        'automatically at the start of the next month.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 20),

            // AMOUNT
            TextFormField(
              controller: _amountController,
              enabled: !_isBusy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
                prefixText: '৳ ',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
              validator: _validateAmount,
            ),

            const SizedBox(height: 24),

            // EFFECTIVE MONTH
            _MonthField(
              label: 'Effective Month',
              month: _effectiveFrom,
              icon: Icons.calendar_month_outlined,
              enabled: !_isBusy,
              onTap: () => _selectEffectiveMonth(context),
            ),

            const SizedBox(height: 16),

            // END MONTH
            //
            // Only Fixed rules can have a manually selected end month.
            // Variable rules always end at the next month's start.
            if (_isFixed) ...[
              _MonthField(
                label: 'End Month',
                month: _effectiveTo,
                icon: Icons.event_busy_outlined,
                enabled: !_isBusy,
                emptyText: 'No end month',
                onTap: () => _selectEffectiveTo(context),
                onClear: _effectiveTo == null
                    ? null
                    : () {
                        setState(() {
                          _effectiveTo = null;
                        });
                      },
              ),
              const SizedBox(height: 8),
              Text(
                'End Month is optional. It represents the exclusive '
                'end date of this rule. For example, an end date of '
                'November 1 means the rule does not apply during November.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ACTIVE STATUS
            Card(
              child: SwitchListTile(
                value: _isActive,
                onChanged: _isBusy
                    ? null
                    : (value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                title: const Text(
                  'Active',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _isActive
                      ? 'This billing rule is marked active.'
                      : 'This billing rule is marked inactive.',
                ),
                secondary: Icon(
                  _isActive
                      ? Icons.check_circle_outline
                      : Icons.pause_circle_outline,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // SAVE BUTTON
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isBusy ? null : _updateBillingRule,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
              ),
            ),

            const SizedBox(height: 12),

            // DEACTIVATE BUTTON
            if (_rule.isActive)
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _isBusy ? null : _confirmDeactivate,
                  icon: _isDeactivating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.pause_circle_outline),
                  label: Text(
                    _isDeactivating ? 'Deactivating...' : 'Deactivate Rule',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // HEADER
  // ========================================================================

  Widget _buildHeader(ThemeData theme) {
    final title = _rule.title?.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _chargeTypeIcon(_rule.chargeType),
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title?.isNotEmpty == true
                        ? title!
                        : _chargeTypeLabel(_rule.chargeType),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_valueTypeLabel(_rule.valueType)} billing rule',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
  // AMOUNT VALIDATION
  // ========================================================================

  String? _validateAmount(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Amount is required.';
    }

    final amount = double.tryParse(text);

    if (amount == null || amount.isNaN || amount.isInfinite) {
      return 'Enter a valid amount.';
    }

    if (amount < 0) {
      return 'Amount cannot be negative.';
    }

    return null;
  }

  // ========================================================================
  // UPDATE BILLING RULE
  // ========================================================================

  Future<void> _updateBillingRule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_effectiveTo != null && !_effectiveTo!.isAfter(_effectiveFrom)) {
      _showError('End Month must be after Effective Month.');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount.isNaN || amount.isInfinite) {
      _showError('Please enter a valid amount.');
      return;
    }

    if (amount < 0) {
      _showError('Amount cannot be negative.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final request = UpdateBillingRuleRequest(
        ruleId: _rule.id,
        ownerId: _rule.ownerId,

        // Immutable fields retain their existing values.
        chargeType: _rule.chargeType,
        valueType: _rule.valueType,

        amount: amount,
        title: _normalizedTitle,
        effectiveFrom: _normalizeMonth(_effectiveFrom),

        // Fixed rules can have an optional end date.
        // Variable rules automatically end next month in the datasource.
        effectiveTo: _isFixed && _effectiveTo != null
            ? _normalizeMonth(_effectiveTo!)
            : null,

        isActive: _isActive,
      );

      await ref.read(updateBillingRuleProvider)(request);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Billing rule updated successfully.')),
      );

      context.pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(_cleanErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ========================================================================
  // DEACTIVATE BILLING RULE
  // ========================================================================

  Future<void> _confirmDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Deactivate Billing Rule?'),
          content: const Text(
            'This billing rule will be marked inactive. '
            'Its record will be retained for historical purposes.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Deactivate'),
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
      await ref.read(deactivateBillingRuleProvider)(
        ruleId: _rule.id,
        ownerId: _rule.ownerId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Billing rule deactivated successfully.')),
      );

      context.pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showError(_cleanErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isDeactivating = false;
        });
      }
    }
  }

  // ========================================================================
  // EFFECTIVE MONTH PICKER
  // ========================================================================

  Future<void> _selectEffectiveMonth(BuildContext context) async {
    final selected = await _showMonthPicker(
      context: context,
      initialMonth: _effectiveFrom,
      firstDate: DateTime(2000, 1),
      lastDate: DateTime(2100, 12),
      title: 'Select Effective Month',
    );

    if (selected == null || !mounted) {
      return;
    }

    final normalized = _normalizeMonth(selected);

    if (_effectiveTo != null && !normalized.isBefore(_effectiveTo!)) {
      _showError('Effective Month must be before End Month.');
      return;
    }

    setState(() {
      _effectiveFrom = normalized;
    });
  }

  // ========================================================================
  // END MONTH PICKER
  // ========================================================================

  Future<void> _selectEffectiveTo(BuildContext context) async {
    final selected = await _showMonthPicker(
      context: context,
      initialMonth: _effectiveTo ?? _nextMonth(_effectiveFrom),
      firstDate: _nextMonth(_effectiveFrom),
      lastDate: DateTime(2100, 12),
      title: 'Select End Month',
    );

    if (selected == null || !mounted) {
      return;
    }

    final normalized = _normalizeMonth(selected);

    if (!normalized.isAfter(_effectiveFrom)) {
      _showError('End Month must be after Effective Month.');
      return;
    }

    setState(() {
      _effectiveTo = normalized;
    });
  }

  // ========================================================================
  // MONTH PICKER
  // ========================================================================

  Future<DateTime?> _showMonthPicker({
    required BuildContext context,
    required DateTime initialMonth,
    required DateTime firstDate,
    required DateTime lastDate,
    required String title,
  }) async {
    final firstMonth = _normalizeMonth(firstDate);
    final lastMonth = _normalizeMonth(lastDate);

    var selectedMonth = _normalizeMonth(initialMonth);

    if (selectedMonth.isBefore(firstMonth)) {
      selectedMonth = firstMonth;
    }

    if (selectedMonth.isAfter(lastMonth)) {
      selectedMonth = lastMonth;
    }

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);

            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // YEAR NAVIGATION
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous year',
                          onPressed: selectedMonth.year <= firstMonth.year
                              ? null
                              : () {
                                  setDialogState(() {
                                    selectedMonth = DateTime(
                                      selectedMonth.year - 1,
                                      selectedMonth.month,
                                      1,
                                    );
                                  });
                                },
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              selectedMonth.year.toString(),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next year',
                          onPressed: selectedMonth.year >= lastMonth.year
                              ? null
                              : () {
                                  setDialogState(() {
                                    selectedMonth = DateTime(
                                      selectedMonth.year + 1,
                                      selectedMonth.month,
                                      1,
                                    );
                                  });
                                },
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // MONTH GRID
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.8,
                          ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final monthNumber = index + 1;

                        final month = DateTime(
                          selectedMonth.year,
                          monthNumber,
                          1,
                        );

                        final isBefore = month.isBefore(firstMonth);
                        final isAfter = month.isAfter(lastMonth);

                        final isSelected =
                            month.year == selectedMonth.year &&
                            month.month == selectedMonth.month;

                        final enabled = !isBefore && !isAfter;

                        return OutlinedButton(
                          onPressed: !enabled
                              ? null
                              : () {
                                  Navigator.of(dialogContext).pop(month);
                                },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isSelected
                                ? theme.colorScheme.primaryContainer
                                : null,
                            foregroundColor: isSelected
                                ? theme.colorScheme.onPrimaryContainer
                                : null,
                            side: BorderSide(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                            ),
                          ),
                          child: Text(_monthShortName(monthNumber)),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ========================================================================
  // HELPERS
  // ========================================================================

  DateTime _normalizeMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  DateTime _nextMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 1);
  }

  String? get _normalizedTitle {
    final value = _titleController.text.trim();

    return value.isEmpty ? null : value;
  }

  String _cleanErrorMessage(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _chargeTypeLabel(BillingChargeType type) {
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

  static IconData _chargeTypeIcon(BillingChargeType type) {
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

  static String _valueTypeLabel(BillingValueType type) {
    switch (type) {
      case BillingValueType.fixed:
        return 'Fixed';
      case BillingValueType.variable:
        return 'Variable';
    }
  }

  static String _monthShortName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return months[month - 1];
  }
}

// ============================================================================
// MONTH FIELD
// ============================================================================

class _MonthField extends StatelessWidget {
  final String label;
  final DateTime? month;
  final IconData icon;
  final bool enabled;
  final String emptyText;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _MonthField({
    required this.label,
    required this.month,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.emptyText = 'Select month',
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
              ? const Icon(Icons.arrow_drop_down)
              : IconButton(
                  tooltip: 'Clear end month',
                  onPressed: enabled ? onClear : null,
                  icon: const Icon(Icons.clear),
                ),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          month == null ? emptyText : _formatMonth(month!),
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }

  static String _formatMonth(DateTime date) {
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
}
