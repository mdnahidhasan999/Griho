// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/update_billing_rule_request.dart';
import '../controllers/generate_monthly_charges_controller.dart';
import '../providers/billing_rule_provider.dart';
import '../widgets/billing_ui_helpers.dart';

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
      text: formatBillingAmount(_rule.amount),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Edit Billing Rule')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              _buildHeader(theme),
              const SizedBox(height: 18),
              GrihoSectionCard(
                title: '1. Rate & Description',
                subtitle: 'Modify charge name and monthly cost',
                icon: Iconsax.wallet_3,
                children: [
                  TextFormField(
                    controller: _titleController,
                    enabled: !_isBusy,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Rule Title / Description',
                      hintText: 'e.g. Monthly Water Charge',
                      prefixIcon: Icon(
                        Iconsax.edit_2,
                        color: GrihoColors.emerald,
                        size: 19,
                      ),
                    ),
                    validator: (value) {
                      if (_rule.chargeType == BillingChargeType.other &&
                          (value == null || value.trim().isEmpty)) {
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
                      prefixIcon: Icon(
                        Iconsax.money_2,
                        color: GrihoColors.emerald,
                        size: 19,
                      ),
                    ),
                    validator: _validateAmount,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GrihoSectionCard(
                title: '2. Rule Parameters',
                subtitle: 'Fixed classification configured upon creation',
                icon: Iconsax.lock,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ReadOnlyParamTile(
                          label: 'Category',
                          value: billingChargeTypeLabel(_rule.chargeType),
                          icon: billingChargeTypeIcon(_rule.chargeType),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ReadOnlyParamTile(
                          label: 'Frequency',
                          value: _isFixed
                              ? 'Fixed Recurring'
                              : 'Variable (1 Month)',
                          icon: _isFixed ? Iconsax.repeat : Iconsax.calendar_1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Iconsax.info_circle,
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
              GrihoSectionCard(
                title: '3. Schedule & Validity',
                subtitle: 'Active timeframe for invoice generation',
                icon: Iconsax.calendar_1,
                children: [
                  _MonthField(
                    label: 'Effective Start Month',
                    month: _effectiveFrom,
                    icon: Iconsax.calendar_1,
                    enabled: !_isBusy,
                    onTap: _selectEffectiveMonth,
                  ),
                  if (_isFixed) ...[
                    const SizedBox(height: 16),
                    _MonthField(
                      label: 'End Month (Exclusive / Optional)',
                      month: _effectiveTo,
                      icon: Iconsax.calendar_remove,
                      enabled: !_isBusy,
                      emptyText: 'No end date (Continuous)',
                      onTap: _selectEffectiveTo,
                      onClear: _effectiveTo == null
                          ? null
                          : () => setState(() => _effectiveTo = null),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
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
                      : (value) => setState(() => _isActive = value),
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
              GrihoPrimaryButton(
                label: _isSaving ? 'Saving Changes...' : 'Save Rule Changes',
                icon: Iconsax.tick_circle,
                isLoading: _isSaving,
                onPressed: _isBusy ? null : _updateBillingRule,
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
                        : const Icon(Iconsax.pause_circle, size: 19),
                    label: Text(
                      _isDeactivating ? 'Deactivating...' : 'Deactivate Rule',
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

  Widget _buildHeader(ThemeData theme) {
    final title = _rule.title?.trim();
    final statusColor = _isActive ? GrihoColors.emerald : GrihoColors.warning;

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
              billingChargeTypeIcon(_rule.chargeType),
              size: 24,
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
                      : billingChargeTypeLabel(_rule.chargeType),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_isFixed ? 'Fixed Recurring' : 'Variable'} • ${billingChargeTypeLabel(_rule.chargeType)}',
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
              color: statusColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  Future<void> _updateBillingRule() async {
    if (_isBusy) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_isFixed &&
        _effectiveTo != null &&
        !_effectiveTo!.isAfter(_effectiveFrom)) {
      GrihoFeedback.showError(
        context,
        'End Month must be strictly after the Effective Month.',
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount.isNaN || amount.isInfinite || amount < 0) {
      GrihoFeedback.showError(context, 'Please enter a valid amount.');
      return;
    }

    final normalizedEffectiveFrom = _normalizeMonth(_effectiveFrom);
    final normalizedEffectiveTo = _isFixed
        ? (_effectiveTo == null ? null : _normalizeMonth(_effectiveTo!))
        : _nextMonth(normalizedEffectiveFrom);

    // Skip Firestore write if nothing changed.
    final unchanged =
        (amount - _rule.amount).abs() < 0.001 &&
        (_normalizedTitle ?? '') == (_rule.title?.trim() ?? '') &&
        normalizedEffectiveFrom.isAtSameMomentAs(
          _normalizeMonth(_rule.effectiveFrom),
        ) &&
        ((normalizedEffectiveTo == null && _rule.effectiveTo == null) ||
            (normalizedEffectiveTo != null &&
                _rule.effectiveTo != null &&
                normalizedEffectiveTo.isAtSameMomentAs(
                  _normalizeMonth(_rule.effectiveTo!),
                ))) &&
        _isActive == _rule.isActive;

    if (unchanged) {
      GrihoFeedback.showInfo(context, 'No changes to save.');
      context.pop(false);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final request = UpdateBillingRuleRequest(
        ruleId: _rule.id,
        ownerId: _rule.ownerId,
        chargeType: _rule.chargeType,
        valueType: _rule.valueType,
        amount: amount,
        title: _normalizedTitle,
        effectiveFrom: normalizedEffectiveFrom,
        effectiveTo: normalizedEffectiveTo,
        isActive: _isActive,
      );

      await ref.read(updateBillingRuleProvider)(request);

      ref
          .read(generateMonthlyChargesControllerProvider.notifier)
          .invalidateMonthSyncLock(
            ownerId: _rule.ownerId,
            propertyId: _rule.propertyId,
          );

      await AuditLoggerService.log(
        ownerId: _rule.ownerId,
        propertyId: _rule.propertyId,
        category: 'billing',
        actionTitle: 'Billing Rule Updated',
        details:
            '${billingChargeTypeLabel(_rule.chargeType)} rate updated to ৳${formatBillingAmount(amount)} (${_isActive ? "Active" : "Inactive"}).',
      );

      if (!mounted) {
        return;
      }

      GrihoFeedback.showSuccess(context, 'Billing rule updated successfully.');
      context.pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, cleanBillingError(error));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDeactivate() async {
    if (_isBusy) {
      return;
    }
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
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
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
    setState(() => _isDeactivating = true);

    try {
      await ref.read(deactivateBillingRuleProvider)(
        ruleId: _rule.id,
        ownerId: _rule.ownerId,
      );

      ref
          .read(generateMonthlyChargesControllerProvider.notifier)
          .invalidateMonthSyncLock(
            ownerId: _rule.ownerId,
            propertyId: _rule.propertyId,
          );

      await AuditLoggerService.log(
        ownerId: _rule.ownerId,
        propertyId: _rule.propertyId,
        category: 'billing',
        actionTitle: 'Billing Rule Deactivated',
        details:
            '${billingChargeTypeLabel(_rule.chargeType)} rule (৳${formatBillingAmount(_rule.amount)}) was deactivated.',
      );

      if (!mounted) {
        return;
      }

      GrihoFeedback.showSuccess(
        context,
        'Billing rule deactivated successfully.',
      );
      context.pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, cleanBillingError(error));
    } finally {
      if (mounted) {
        setState(() => _isDeactivating = false);
      }
    }
  }

  Future<void> _selectEffectiveMonth() async {
    final selected = await _showMonthPicker(
      initialMonth: _effectiveFrom,
      firstDate: DateTime(2000, 1),
      lastDate: DateTime(2100, 12),
      title: 'Select Effective Month',
    );

    if (selected == null || !mounted) {
      return;
    }

    final normalized = _normalizeMonth(selected);
    if (_isFixed &&
        _effectiveTo != null &&
        !normalized.isBefore(_effectiveTo!)) {
      GrihoFeedback.showError(
        context,
        'Effective Month must be before the specified End Month.',
      );
      return;
    }

    setState(() => _effectiveFrom = normalized);
  }

  Future<void> _selectEffectiveTo() async {
    final selected = await _showMonthPicker(
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
      GrihoFeedback.showError(
        context,
        'End Month must be after the Effective Month.',
      );
      return;
    }

    setState(() => _effectiveTo = normalized);
  }

  Future<DateTime?> _showMonthPicker({
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
                          icon: const Icon(Iconsax.arrow_left_2, size: 19),
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
                          icon: const Icon(Iconsax.arrow_right_3, size: 19),
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
                          selectedMonth.year,
                          monthNumber,
                          1,
                        );
                        final enabled =
                            !month.isBefore(firstMonth) &&
                            !month.isAfter(lastMonth);
                        final isSelected =
                            month.year == selectedMonth.year &&
                            month.month == selectedMonth.month;

                        return OutlinedButton(
                          onPressed: !enabled
                              ? null
                              : () => Navigator.of(dialogContext).pop(month),
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
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  DateTime _normalizeMonth(DateTime date) => DateTime(date.year, date.month, 1);

  DateTime _nextMonth(DateTime date) => DateTime(date.year, date.month + 1, 1);

  String? get _normalizedTitle {
    final value = _titleController.text.trim();
    return value.isEmpty ? null : value;
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
              Icon(icon, size: 15, color: theme.colorScheme.primary),
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
          prefixIcon: Icon(icon, color: GrihoColors.emerald, size: 19),
          suffixIcon: onClear == null
              ? const Icon(Iconsax.arrow_right_3, size: 16)
              : IconButton(
                  tooltip: 'Clear End Month',
                  icon: const Icon(Iconsax.close_circle, size: 19),
                  onPressed: enabled ? onClear : null,
                ),
        ),
        child: Text(
          month == null ? emptyText : formatBillingMonthYear(month!),
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
}
