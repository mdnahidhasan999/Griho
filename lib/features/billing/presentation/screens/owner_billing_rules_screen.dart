import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../tenants/presentation/providers/property_tenants_provider.dart';
import '../../../units/presentation/providers/property_units_provider.dart';

import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/monthly_bill.dart';
import '../controllers/generate_monthly_charges_controller.dart';
import '../providers/billing_rule_provider.dart';
import '../providers/monthly_bill_provider.dart';
import '../providers/tenancy_billing_target_provider.dart';
import '../widgets/variable_bill_amount_dialog.dart';

class OwnerBillingRulesScreen extends ConsumerStatefulWidget {
  const OwnerBillingRulesScreen({super.key});

  @override
  ConsumerState<OwnerBillingRulesScreen> createState() =>
      _OwnerBillingRulesScreenState();
}

class _OwnerBillingRulesScreenState
    extends ConsumerState<OwnerBillingRulesScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedPropertyId;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Billing Management',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.rule_outlined), text: 'Rules'),
            Tab(
              icon: Icon(Icons.receipt_long_outlined),
              text: 'Generated Bills',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push(RouteNames.ownerBillingSetup);

          if (!context.mounted) {
            return;
          }

          if (result != null) {
            final propertyId = _selectedPropertyId;

            if (propertyId != null && propertyId.isNotEmpty) {
              final ownerId =
                  ref.read(currentUserProfileProvider).value?.uid ?? '';

              _invalidatePropertyBillingData(
                ownerId: ownerId,
                propertyId: propertyId,
              );
            }
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Rule'),
      ),
      body: profileAsync.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stackTrace) {
          return _ErrorView(
            message: 'Unable to load your profile.',
            onRetry: () {
              ref.invalidate(currentUserProfileProvider);
            },
          );
        },
        data: (profile) {
          if (profile == null) {
            return _ErrorView(
              message: 'User profile not found.',
              onRetry: () {
                ref.invalidate(currentUserProfileProvider);
              },
            );
          }

          final ownerId = profile.uid.trim();

          if (ownerId.isEmpty) {
            return const _ErrorView(message: 'Unable to determine owner ID.');
          }

          return propertiesAsync.when(
            loading: () {
              return const Center(child: CircularProgressIndicator());
            },
            error: (error, stackTrace) {
              return _ErrorView(
                message: 'Unable to load properties.',
                onRetry: () {
                  ref.invalidate(currentOwnerPropertiesProvider);
                },
              );
            },
            data: (properties) {
              if (properties.isEmpty) {
                return const _EmptyState(
                  icon: Icons.home_work_outlined,
                  title: 'No properties found',
                  message: 'Add a property before creating billing rules.',
                );
              }

              final selectedPropertyId =
                  properties.any(
                    (property) => property.id == _selectedPropertyId,
                  )
                  ? _selectedPropertyId!
                  : properties.first.id;

              if (_selectedPropertyId != selectedPropertyId) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }

                  setState(() {
                    _selectedPropertyId = selectedPropertyId;
                  });
                });
              }

              return TabBarView(
                controller: _tabController,
                children: [
                  _RulesTab(
                    ownerId: ownerId,
                    propertyId: selectedPropertyId,
                    properties: properties,
                    onPropertyChanged: (value) {
                      if (value == null || value.isEmpty) {
                        return;
                      }

                      setState(() {
                        _selectedPropertyId = value;
                      });
                    },
                    onGenerateBills: () {
                      _generateMonthlyCharges(
                        ownerId: ownerId,
                        propertyId: selectedPropertyId,
                      );
                    },
                  ),
                  _GeneratedBillsTab(
                    ownerId: ownerId,
                    propertyId: selectedPropertyId,
                    properties: properties,
                    selectedPropertyId: selectedPropertyId,
                    onPropertyChanged: (value) {
                      if (value == null || value.isEmpty) {
                        return;
                      }

                      setState(() {
                        _selectedPropertyId = value;
                      });
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ==========================================================================
  // PROPERTY BILLING DATA INVALIDATION
  // ==========================================================================

  void _invalidatePropertyBillingData({
    required String ownerId,
    required String propertyId,
  }) {
    ref.invalidate(
      propertyBillingRulesProvider((ownerId: ownerId, propertyId: propertyId)),
    );

    ref.invalidate(
      propertyMonthlyBillHistoryProvider((
        ownerId: ownerId,
        propertyId: propertyId,
      )),
    );
  }

  // ==========================================================================
  // GENERATE MONTHLY CHARGES
  // ==========================================================================

  Future<void> _generateMonthlyCharges({
    required String ownerId,
    required String propertyId,
  }) async {
    final now = DateTime.now();

    // =========================================================================
    // STEP 1 — SELECT BILLING MONTH
    // =========================================================================

    final selectedMonth = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, 1),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select billing month',
    );

    if (selectedMonth == null || !mounted) {
      return;
    }

    final billingPeriodStart = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      1,
    );

    // Billing period end is EXCLUSIVE.
    //
    // Example:
    // October 2026
    // 2026-10-01 → 2026-11-01
    final billingPeriodEnd = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      1,
    );

    // =========================================================================
    // STEP 2 — SELECT DUE DATE
    // =========================================================================

    final dueYear = selectedMonth.month == 12
        ? selectedMonth.year + 1
        : selectedMonth.year;

    final dueMonth = selectedMonth.month == 12 ? 1 : selectedMonth.month + 1;

    final dueMonthStart = DateTime(dueYear, dueMonth, 1);

    final dueMonthEnd = DateTime(dueYear, dueMonth + 1, 0);

    final defaultDueDateDay = dueMonthEnd.day >= 10 ? 10 : dueMonthEnd.day;

    final dueDate = await showDatePicker(
      context: context,
      initialDate: DateTime(dueYear, dueMonth, defaultDueDateDay),
      firstDate: dueMonthStart,
      lastDate: dueMonthEnd,
      helpText: 'Select bill due date',
    );

    if (dueDate == null || !mounted) {
      return;
    }

    try {
      _showMessage('Preparing tenancy history and units...');

      // =======================================================================
      // STEP 3 — LOAD UNITS
      // =======================================================================

      final units = await ref.read(propertyUnitsProvider(propertyId).future);

      // =======================================================================
      // STEP 4 — LOAD CURRENT TENANTS
      // =======================================================================

      final tenants = await ref.read(
        propertyTenantsProvider(propertyId).future,
      );

      // =======================================================================
      // STEP 5 — RESOLVE HISTORICAL TENANCY TARGETS
      // =======================================================================
      //
      // The resolver combines:
      //
      // 1. Historical ended tenancies
      // 2. Current active tenancies
      //
      // Example:
      //
      // Tenant A → 01 Oct to 14 Oct
      // Tenant B → 15 Oct to 31 Oct
      //
      // Both become separate billing targets.
      //

      final tenancyResolver = ref.read(tenancyBillingTargetResolverProvider);

      final tenancyTargets = await tenancyResolver.resolve(
        ownerId: ownerId,
        propertyId: propertyId,
        billingPeriodStart: billingPeriodStart,
        billingPeriodEnd: billingPeriodEnd,
        currentTenants: tenants,
        units: [
          for (final unit in units)
            (unitId: unit.id.trim(), floorId: unit.floorNumber.toString()),
        ],
      );

      if (!mounted) {
        return;
      }

      if (tenancyTargets.isEmpty) {
        _showMessage(
          'No tenancy found for this property '
          'during ${_formatMonth(billingPeriodStart)}.',
        );
        return;
      }

      // =======================================================================
      // STEP 6 — GENERATE RENT + NON-RENT BILLS
      // =======================================================================
      //
      // The same historical tenancy targets are passed to the orchestration
      // layer.
      //
      // Rent:
      //   Uses tenancyStart / tenancyEnd
      //   Uses rent-rate history
      //   Uses calendar-day proration
      //
      // Non-rent:
      //   Uses the same tenant/unit/floor targets
      //   Uses applicable billing rules
      //

      _showMessage(
        'Generating rent and monthly bills for '
        '${tenancyTargets.length} tenancy segment(s)...',
      );

      final controller = ref.read(
        generateMonthlyChargesControllerProvider.notifier,
      );

      final result = await controller.generate(
        ownerId: ownerId,
        propertyId: propertyId,
        tenancyTargets: tenancyTargets,
        billingPeriodStart: billingPeriodStart,
        billingPeriodEnd: billingPeriodEnd,
        dueDate: dueDate,
      );

      if (!mounted) {
        return;
      }

      // =======================================================================
      // STEP 7 — REFRESH GENERATED BILL HISTORY
      // =======================================================================

      ref.invalidate(
        propertyMonthlyBillHistoryProvider((
          ownerId: ownerId,
          propertyId: propertyId,
        )),
      );

      final rentCount = result.generatedRents.length;
      final billCount = result.generatedBills.length;

      // =======================================================================
      // STEP 8 — RESULT MESSAGE
      // =======================================================================

      if (rentCount == 0 && billCount == 0) {
        _showMessage(
          'No new rent or monthly bills were generated for '
          '${_formatMonth(billingPeriodStart)}.',
        );
        return;
      }

      _showMessage(
        '$rentCount rent record(s) and '
        '$billCount monthly bill(s) generated successfully.',
      );
    } catch (error, stackTrace) {
      debugPrint('BILLING: Failed to generate monthly charges.');

      debugPrint('BILLING ERROR: $error');

      debugPrint('BILLING STACK: $stackTrace');

      if (!mounted) {
        return;
      }

      _showMessage(_cleanErrorMessage(error));
    }
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  String _formatMonth(DateTime date) {
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

  String _cleanErrorMessage(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

// ============================================================================
// RULES TAB
// ============================================================================

class _RulesTab extends ConsumerWidget {
  final String ownerId;
  final String propertyId;
  final List<dynamic> properties;
  final ValueChanged<String?> onPropertyChanged;
  final VoidCallback onGenerateBills;

  const _RulesTab({
    required this.ownerId,
    required this.propertyId,
    required this.properties,
    required this.onPropertyChanged,
    required this.onGenerateBills,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final rulesAsync = ref.watch(
      propertyBillingRulesProvider((ownerId: ownerId, propertyId: propertyId)),
    );

    final billHistoryAsync = ref.watch(
      propertyMonthlyBillHistoryProvider((
        ownerId: ownerId,
        propertyId: propertyId,
      )),
    );

    return RefreshIndicator(
      onRefresh: () async {
        final rulesProvider = propertyBillingRulesProvider((
          ownerId: ownerId,
          propertyId: propertyId,
        ));

        final billsProvider = propertyMonthlyBillHistoryProvider((
          ownerId: ownerId,
          propertyId: propertyId,
        ));

        ref.invalidate(rulesProvider);
        ref.invalidate(billsProvider);

        await ref.read(rulesProvider.future);
        await ref.read(billsProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          Text(
            'Billing Management',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'View and manage billing rules for this property.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: propertyId,
            decoration: const InputDecoration(
              labelText: 'Property',
              prefixIcon: Icon(Icons.apartment_outlined),
              border: OutlineInputBorder(),
            ),
            items: [
              for (final property in properties)
                DropdownMenuItem<String>(
                  value: property.id,
                  child: Text(property.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onPropertyChanged,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onGenerateBills,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Generate Monthly Charges'),
            ),
          ),
          const SizedBox(height: 24),
          rulesAsync.when(
            loading: () {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            },
            error: (error, stackTrace) {
              return _ErrorCard(
                message: 'Unable to load billing rules.',
                onRetry: () {
                  ref.invalidate(
                    propertyBillingRulesProvider((
                      ownerId: ownerId,
                      propertyId: propertyId,
                    )),
                  );
                },
              );
            },
            data: (rules) {
              if (rules.isEmpty) {
                return const _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No billing rules',
                  message:
                      'No billing rules have been created '
                      'for this property yet.',
                );
              }

              return billHistoryAsync.when(
                loading: () {
                  return _RulesList(
                    rules: rules,
                    bills: const [],
                    ownerId: ownerId,
                    titleSuffix: '${rules.length}',
                  );
                },
                error: (error, stackTrace) {
                  return _RulesList(
                    rules: rules,
                    bills: const [],
                    ownerId: ownerId,
                    titleSuffix: '${rules.length}',
                  );
                },
                data: (bills) {
                  return _RulesList(
                    rules: rules,
                    bills: bills,
                    ownerId: ownerId,
                    titleSuffix: '${rules.length}',
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// RULES LIST
// ============================================================================

class _RulesList extends StatelessWidget {
  final List<BillingRule> rules;
  final List<MonthlyBill> bills;
  final String ownerId;
  final String titleSuffix;

  const _RulesList({
    required this.rules,
    required this.bills,
    required this.ownerId,
    required this.titleSuffix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Billing Rules',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                titleSuffix,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final rule in rules) ...[
          _BillingRuleCard(
            rule: rule,
            ownerId: ownerId,
            generatedBillCount: bills
                .where((bill) => bill.sourceRuleId == rule.id)
                .length,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// ============================================================================
// GENERATED BILLS TAB
// ============================================================================

class _GeneratedBillsTab extends ConsumerWidget {
  final String ownerId;
  final String propertyId;
  final List<dynamic> properties;
  final String selectedPropertyId;
  final ValueChanged<String?> onPropertyChanged;

  const _GeneratedBillsTab({
    required this.ownerId,
    required this.propertyId,
    required this.properties,
    required this.selectedPropertyId,
    required this.onPropertyChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final billsAsync = ref.watch(
      propertyMonthlyBillHistoryProvider((
        ownerId: ownerId,
        propertyId: propertyId,
      )),
    );

    return RefreshIndicator(
      onRefresh: () async {
        final provider = propertyMonthlyBillHistoryProvider((
          ownerId: ownerId,
          propertyId: propertyId,
        ));

        ref.invalidate(provider);

        await ref.read(provider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          Text(
            'Generated Bills',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'View bills already generated for this property.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: selectedPropertyId,
            decoration: const InputDecoration(
              labelText: 'Property',
              prefixIcon: Icon(Icons.apartment_outlined),
              border: OutlineInputBorder(),
            ),
            items: [
              for (final property in properties)
                DropdownMenuItem<String>(
                  value: property.id,
                  child: Text(property.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onPropertyChanged,
          ),
          const SizedBox(height: 24),
          billsAsync.when(
            loading: () {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            },
            error: (error, stackTrace) {
              return _ErrorCard(
                message: 'Unable to load generated bills.',
                onRetry: () {
                  ref.invalidate(
                    propertyMonthlyBillHistoryProvider((
                      ownerId: ownerId,
                      propertyId: propertyId,
                    )),
                  );
                },
              );
            },
            data: (bills) {
              if (bills.isEmpty) {
                return const _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No generated bills',
                  message:
                      'No monthly bills have been generated '
                      'for this property yet.',
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'All Generated Bills',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${bills.length}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final bill in bills) ...[
                    _GeneratedBillCard(
                      bill: bill,
                      onUpdated: () {
                        ref.invalidate(
                          propertyMonthlyBillHistoryProvider((
                            ownerId: ownerId,
                            propertyId: propertyId,
                          )),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BILLING RULE CARD
// ============================================================================

class _BillingRuleCard extends ConsumerWidget {
  final BillingRule rule;
  final String ownerId;
  final int generatedBillCount;

  const _BillingRuleCard({
    required this.rule,
    required this.ownerId,
    required this.generatedBillCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final status = _resolveRuleStatus(rule);

    final chargeName = _chargeTypeLabel(rule.chargeType);

    final amountText = rule.valueType == BillingValueType.variable
        ? 'Variable'
        : '৳${rule.amount?.toStringAsFixed(2) ?? '0.00'}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _chargeTypeIcon(rule.chargeType),
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rule.title?.trim().isNotEmpty == true
                            ? rule.title!
                            : chargeName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chargeName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _RuleStatusChip(status: status),
                PopupMenuButton<String>(
                  tooltip: 'Manage billing rule',
                  onSelected: (value) async {
                    if (value != 'edit') {
                      return;
                    }

                    final result = await context.push(
                      RouteNames.editBillingRule.replaceFirst(
                        ':ruleId',
                        rule.id,
                      ),
                      extra: rule,
                    );

                    if (!context.mounted) {
                      return;
                    }

                    if (result == true) {
                      ref.invalidate(
                        propertyBillingRulesProvider((
                          ownerId: ownerId,
                          propertyId: rule.propertyId,
                        )),
                      );

                      ref.invalidate(
                        propertyMonthlyBillHistoryProvider((
                          ownerId: ownerId,
                          propertyId: rule.propertyId,
                        )),
                      );
                    }
                  },
                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 12),
                            Text('Edit'),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.payments_outlined,
                    label: 'Amount',
                    value: amountText,
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.tune_outlined,
                    label: 'Type',
                    value: _valueTypeLabel(rule.valueType),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.account_tree_outlined,
                    label: 'Scope',
                    value: _scopeTypeLabel(rule.scopeType),
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.calendar_month_outlined,
                    label: 'Effective',
                    value: _formatDate(rule.effectiveFrom),
                  ),
                ),
              ],
            ),
            if (rule.effectiveTo != null) ...[
              const SizedBox(height: 14),
              _InfoItem(
                icon: Icons.event_busy_outlined,
                label: 'Ends',
                value: _formatDate(rule.effectiveTo!),
              ),
            ],
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      generatedBillCount == 0
                          ? 'No bills generated from this rule yet'
                          : '$generatedBillCount bill(s) generated from this rule',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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

  static _RuleStatus _resolveRuleStatus(BillingRule rule) {
    if (!rule.isActive) {
      return _RuleStatus.inactive;
    }

    final now = DateTime.now();

    if (now.isBefore(rule.effectiveFrom)) {
      return _RuleStatus.scheduled;
    }

    if (rule.effectiveTo != null && !now.isBefore(rule.effectiveTo!)) {
      return _RuleStatus.historical;
    }

    return _RuleStatus.active;
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

  static String _scopeTypeLabel(BillingScopeType type) {
    switch (type) {
      case BillingScopeType.property:
        return 'Property';
      case BillingScopeType.floor:
        return 'Floor';
      case BillingScopeType.unit:
        return 'Unit';
      case BillingScopeType.tenant:
        return 'Tenant';
    }
  }

  static String _formatDate(DateTime date) {
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

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }
}

// ============================================================================
// RULE STATUS
// ============================================================================

enum _RuleStatus { active, scheduled, historical, inactive }

// ============================================================================
// RULE STATUS CHIP
// ============================================================================

class _RuleStatusChip extends StatelessWidget {
  final _RuleStatus status;

  const _RuleStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String label;
    final IconData icon;

    switch (status) {
      case _RuleStatus.active:
        label = 'Active';
        icon = Icons.check_circle_outline;

      case _RuleStatus.scheduled:
        label = 'Scheduled';
        icon = Icons.schedule_outlined;

      case _RuleStatus.historical:
        label = 'Historical';
        icon = Icons.history_outlined;

      case _RuleStatus.inactive:
        label = 'Inactive';
        icon = Icons.block_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// GENERATED BILL CARD
// ============================================================================

class _GeneratedBillCard extends StatelessWidget {
  final MonthlyBill bill;
  final VoidCallback? onUpdated;

  const _GeneratedBillCard({required this.bill, this.onUpdated});

  Future<void> _openAmountDialog(BuildContext context) async {
    final updatedBill = await showDialog<MonthlyBill>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return VariableBillAmountDialog(
          billId: bill.id,
          title: '${_billTypeLabel(bill.type)} Amount',
        );
      },
    );

    if (updatedBill == null || !context.mounted) {
      return;
    }

    onUpdated?.call();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Bill amount updated successfully.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isPendingVariableBill =
        bill.status == MonthlyBillStatus.pending &&
        bill.valueType == BillingValueType.variable;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.receipt_long_outlined,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _billTypeLabel(bill.type),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unit: ${bill.unitId}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Period: '
                        '${_formatMonth(bill.billingPeriodStart)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _BillStatusChip(status: bill.status),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            if (isPendingVariableBill)
              _PendingVariableBillContent(
                onEnterAmount: () {
                  _openAmountDialog(context);
                },
              )
            else
              _FinalizedBillContent(bill: bill),
          ],
        ),
      ),
    );
  }

  static String _billTypeLabel(MonthlyBillType type) {
    switch (type) {
      case MonthlyBillType.rent:
        return 'Rent';
      case MonthlyBillType.water:
        return 'Water';
      case MonthlyBillType.gas:
        return 'Gas';
      case MonthlyBillType.garbage:
        return 'Garbage';
      case MonthlyBillType.serviceCharge:
        return 'Service Charge';
      case MonthlyBillType.electricity:
        return 'Electricity';
      case MonthlyBillType.other:
        return 'Other';
    }
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

// ============================================================================
// PENDING VARIABLE BILL CONTENT
// ============================================================================

class _PendingVariableBillContent extends StatelessWidget {
  final VoidCallback onEnterAmount;

  const _PendingVariableBillContent({required this.onEnterAmount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_note_outlined,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Amount Required',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the actual amount before the tenant can be charged.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onEnterAmount,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Enter Amount'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FINALIZED BILL CONTENT
// ============================================================================

class _FinalizedBillContent extends StatelessWidget {
  final MonthlyBill bill;

  const _FinalizedBillContent({required this.bill});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Amount',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '৳${bill.amount.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (bill.valueType == BillingValueType.variable) ...[
                const SizedBox(height: 2),
                Text(
                  'Variable',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        _BillStatusChip(status: bill.status),
      ],
    );
  }
}

// ============================================================================
// BILL STATUS CHIP
// ============================================================================

class _BillStatusChip extends StatelessWidget {
  final MonthlyBillStatus status;

  const _BillStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color backgroundColor;
    final Color foregroundColor;

    switch (status) {
      case MonthlyBillStatus.pending:
        backgroundColor = theme.colorScheme.primaryContainer;
        foregroundColor = theme.colorScheme.onPrimaryContainer;

      case MonthlyBillStatus.unpaid:
        backgroundColor = theme.colorScheme.errorContainer;
        foregroundColor = theme.colorScheme.onErrorContainer;

      case MonthlyBillStatus.partiallyPaid:
        backgroundColor = theme.colorScheme.secondaryContainer;
        foregroundColor = theme.colorScheme.onSecondaryContainer;

      case MonthlyBillStatus.paid:
        backgroundColor = theme.colorScheme.tertiaryContainer;
        foregroundColor = theme.colorScheme.onTertiaryContainer;

      case MonthlyBillStatus.overdue:
        backgroundColor = theme.colorScheme.errorContainer;
        foregroundColor = theme.colorScheme.onErrorContainer;

      case MonthlyBillStatus.cancelled:
        backgroundColor = theme.colorScheme.surfaceContainerHighest;
        foregroundColor = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: theme.textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _statusLabel(MonthlyBillStatus status) {
    switch (status) {
      case MonthlyBillStatus.pending:
        return 'Amount Required';
      case MonthlyBillStatus.unpaid:
        return 'Unpaid';
      case MonthlyBillStatus.partiallyPaid:
        return 'Partially Paid';
      case MonthlyBillStatus.paid:
        return 'Paid';
      case MonthlyBillStatus.overdue:
        return 'Overdue';
      case MonthlyBillStatus.cancelled:
        return 'Cancelled';
    }
  }
}

// ============================================================================
// INFO ITEM
// ============================================================================

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// EMPTY STATE
// ============================================================================

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR VIEW
// ============================================================================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorView({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR CARD
// ============================================================================

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
