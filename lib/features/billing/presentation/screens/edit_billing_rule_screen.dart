import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    _amountController = TextEditingController(
      text: _formatInitialAmount(_rule.amount),
    );

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

  String _formatInitialAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Edit Billing Rule',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              // 1. Hero Rule Overview
              _buildHeader(theme),

              const SizedBox(height: 18),

              // 2. Editable Configuration Section
              _buildSectionCard(
                title: '1. Rate & Description',
                subtitle: 'Modify charge name and monthly cost',
                icon: Icons.payments_outlined,
                children: [
                  TextFormField(
                    controller: _titleController,
                    enabled: !_isBusy,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Rule Title / Description',
                      hintText: 'e.g. Monthly Water Charge',
                      prefixIcon: Icon(Icons.title_rounded),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (_rule.chargeType == BillingChargeType.other &&
                          (value == null || value
                              .trim()
                              .isEmpty)) {
                        return 'Title is required for custom charge types.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    enabled: !_isBusy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Billed Amount',
                      hintText: '0.00',
                      prefixText: '৳ ',
                      prefixIcon: Icon(Icons.currency_exchange_rounded),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateAmount,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 3. Locked Classification Specs
              _buildSectionCard(
                title: '2. Rule Parameters',
                subtitle: 'Fixed classification configured upon creation',
                icon: Icons.lock_outline_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ReadOnlyParamTile(
                          label: 'Category',
                          value: _chargeTypeLabel(_rule.chargeType),
                          icon: _chargeTypeIcon(_rule.chargeType),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ReadOnlyParamTile(
                          label: 'Frequency',
                          value: _valueTypeLabel(_rule.valueType),
                          icon: _isFixed
                              ? Icons.repeat_rounded
                              : Icons.edit_calendar_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: theme.colorScheme.outlineVariant),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isFixed
                                ? 'Fixed charges recur across active billing cycles until the optional end month.'
                                : 'Variable charges apply exclusively to their effective month and expire automatically.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 4. Effective Timeline Section
              _buildSectionCard(
                title: '3. Schedule & Validity',
                subtitle: 'Active timeframe for invoice generation',
                icon: Icons.calendar_month_outlined,
                children: [
                  _MonthField(
                    label: 'Effective Start Month',
                    month: _effectiveFrom,
                    icon: Icons.calendar_today_outlined,
                    enabled: !_isBusy,
                    onTap: () {
                      _selectEffectiveMonth(context);
                    },
                  ),
                  if (_isFixed) ...[
                    const SizedBox(height: 16),
                    _MonthField(
                      label: 'End Month (Exclusive / Optional)',
                      month: _effectiveTo,
                      icon: Icons.event_busy_outlined,
                      enabled: !_isBusy,
                      emptyText: 'No end date (Continuous)',
                      onTap: () {
                        _selectEffectiveTo(context);
                      },
                      onClear: _effectiveTo == null
                          ? null
                          : () {
                        setState(() {
                          _effectiveTo = null;
                        });
                      },
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 18),

              // 5. Activation Toggle Card
              Material(
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 4,
                  ),
                  value: _isActive,
                  onChanged: _isBusy
                      ? null
                      : (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                  title: const Text(
                    'Active Status',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _isActive
                        ? 'Rule is operational and included in bill creation.'
                        : 'Rule is deactivated and ignored during billing.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // 6. Action Buttons
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isBusy ? null : _updateBillingRule,
                  icon: _isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    _isSaving ? 'Saving Changes...' : 'Save Rule Changes',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              if (_rule.isActive) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                    ),
                    onPressed: _isBusy ? null : _confirmDeactivate,
                    icon: _isDeactivating
                        ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.error,
                      ),
                    )
                        : const Icon(Icons.pause_circle_outline_rounded),
                    label: Text(
                      _isDeactivating
                          ? 'Deactivating...'
                          : 'Deactivate Rule',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // HEADER CARD
  // ========================================================================

  Widget _buildHeader(ThemeData theme) {
    final title = _rule.title?.trim();
    final isActive = _isActive;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _chargeTypeIcon(_rule.chargeType),
              size: 26,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title?.isNotEmpty == true
                      ? title!
                      : _chargeTypeLabel(_rule.chargeType),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_valueTypeLabel(_rule.valueType)} • ${_chargeTypeLabel(
                      _rule.chargeType)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.green.shade800 : Colors.orange
                    .shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
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
      return 'Enter a valid numeric amount.';
    }

    if (amount < 0) {
      return 'Amount cannot be negative.';
    }

    return null;
  }

  // ========================================================================
  // UPDATE ACTION
  // ========================================================================

  Future<void> _updateBillingRule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_effectiveTo != null && !_effectiveTo!.isAfter(_effectiveFrom)) {
      _showError('End Month must be strictly after the Effective Month.');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount.isNaN || amount.isInfinite || amount < 0) {
      _showError('Please enter a valid amount.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final request = UpdateBillingRuleRequest(
        ruleId: _rule.id,
        ownerId: _rule.ownerId,
        chargeType: _rule.chargeType,
        valueType: _rule.valueType,
        amount: amount,
        title: _normalizedTitle,
        effectiveFrom: _normalizeMonth(_effectiveFrom),
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
        const SnackBar(
          content: Text('Billing rule updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
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
  // DEACTIVATE ACTION
  // ========================================================================

  Future<void> _confirmDeactivate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Deactivate Billing Rule?'),
          content: const Text(
            'This rule will be marked inactive and skipped during subsequent invoice generation. Previous historical billing records remain unaffected.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme
                    .of(context)
                    .colorScheme
                    .error,
              ),
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
        const SnackBar(
          content: Text('Billing rule deactivated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
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
  // MONTH PICKERS
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
      _showError('Effective Month must be before the specified End Month.');
      return;
    }

    setState(() {
      _effectiveFrom = normalized;
    });
  }

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
      _showError('End Month must be after the Effective Month.');
      return;
    }

    setState(() {
      _effectiveTo = normalized;
    });
  }

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
                width: 340,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous Year',
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
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              selectedMonth.year.toString(),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next Year',
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
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                            selectedMonth.year, monthNumber, 1);

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
                                  : theme.colorScheme.outlineVariant,
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
      return message.substring(11);
    }
    if (message.startsWith('Invalid argument(s): ')) {
      return message.substring(21);
    }
    return message;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String _chargeTypeLabel(BillingChargeType type) {
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

  static IconData _chargeTypeIcon(BillingChargeType type) {
    switch (type) {
      case BillingChargeType.water:
        return Icons.water_drop_outlined;
      case BillingChargeType.gas:
        return Icons.local_fire_department_outlined;
      case BillingChargeType.garbage:
        return Icons.delete_outline_rounded;
      case BillingChargeType.serviceCharge:
        return Icons.cleaning_services_outlined;
      case BillingChargeType.electricity:
        return Icons.bolt_rounded;
      case BillingChargeType.other:
        return Icons.receipt_long_outlined;
    }
  }

  static String _valueTypeLabel(BillingValueType type) {
    switch (type) {
      case BillingValueType.fixed:
        return 'Fixed Recurring';
      case BillingValueType.variable:
        return 'Variable (Month Specific)';
    }
  }

  static String _monthShortName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}

// ============================================================================
// READ ONLY PARAMETER TILE
// ============================================================================

class _ReadOnlyParamTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ReadOnlyParamTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MONTH FIELD COMPONENT
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
              ? const Icon(Icons.chevron_right_rounded)
              : IconButton(
            tooltip: 'Clear End Month',
            icon: const Icon(Icons.clear_rounded, size: 20),
            onPressed: enabled ? onClear : null,
          ),
          border: const OutlineInputBorder(),
        ),
        child: Text(
          month == null ? emptyText : _formatMonth(month!),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: month == null
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  static String _formatMonth(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
