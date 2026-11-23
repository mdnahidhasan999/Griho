// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../../../core/services/pdf_receipt_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../tenants/data/models/tenant_model.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/providers/property_tenants_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';
import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/monthly_bill.dart';
import '../../domain/services/billing_rule_resolver.dart';
import '../controllers/generate_monthly_charges_controller.dart';
import '../providers/billing_rule_provider.dart';
import '../providers/monthly_bill_provider.dart';
import '../providers/tenancy_billing_target_provider.dart';
import '../widgets/billing_ui_helpers.dart';

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
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Billing Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Iconsax.document_text, size: 19),
              text: 'Billing Rules',
            ),
            Tab(
              icon: Icon(Iconsax.receipt_item, size: 19),
              text: 'Generated Invoices',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push(RouteNames.ownerBillingSetup);
          if (!context.mounted || result == null) {
            return;
          }

          final properties =
              ref.read(currentOwnerPropertiesProvider).value ?? [];
          final selectedProperty = properties
              .where((p) => p.id == _selectedPropertyId)
              .firstOrNull;
          if (selectedProperty == null) {
            return;
          }

          await AuditLoggerService.log(
            ownerId: selectedProperty.ownerId,
            propertyId: selectedProperty.id,
            propertyName: selectedProperty.name,
            category: 'billing',
            actionTitle: 'Billing Rule Created',
            details:
                'A new utility billing rule was configured for ${selectedProperty.name}.',
          );

          _invalidatePropertyBillingData(
            ownerId: selectedProperty.ownerId,
            propertyId: selectedProperty.id,
          );
        },
        icon: const Icon(Iconsax.add),
        label: const Text(
          'Add Rule',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: profileAsync.when(
        loading: () => const GrihoLoadingView(message: 'Loading profile...'),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load profile',
              subtitle: 'Please check your connection and try again.',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(currentUserProfileProvider),
            ),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GrihoStatusState(
                  icon: Iconsax.user_remove,
                  title: 'Profile not found',
                  subtitle: 'User profile could not be loaded.',
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(currentUserProfileProvider),
                ),
              ),
            );
          }

          return propertiesAsync.when(
            loading: () =>
                const GrihoLoadingView(message: 'Loading properties...'),
            error: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GrihoStatusState(
                  icon: Iconsax.warning_2,
                  title: 'Unable to load properties',
                  subtitle: 'Please check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: () =>
                      ref.invalidate(currentOwnerPropertiesProvider),
                ),
              ),
            ),
            data: (properties) {
              if (properties.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: GrihoStatusState(
                      icon: Iconsax.buildings_2,
                      title: 'No properties available',
                      subtitle:
                          'Add or get assigned to a property before managing billing rules.',
                    ),
                  ),
                );
              }

              final selectedProperty =
                  properties
                      .where((p) => p.id == _selectedPropertyId)
                      .firstOrNull ??
                  properties.first;

              final selectedPropertyId = selectedProperty.id;
              final effectiveOwnerId = selectedProperty.ownerId.trim();

              if (_selectedPropertyId != selectedPropertyId) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }
                  setState(() => _selectedPropertyId = selectedPropertyId);
                });
              }

              return TabBarView(
                controller: _tabController,
                children: [
                  _RulesTab(
                    ownerId: effectiveOwnerId,
                    propertyId: selectedPropertyId,
                    propertyName: selectedProperty.name,
                    properties: properties,
                    onPropertyChanged: (value) {
                      if (value == null || value.isEmpty) {
                        return;
                      }
                      setState(() => _selectedPropertyId = value);
                    },
                    onGenerateBills: () {
                      _generateMonthlyChargesManually(
                        ownerId: effectiveOwnerId,
                        property: selectedProperty,
                      );
                    },
                  ),
                  _GeneratedBillsTab(
                    ownerId: effectiveOwnerId,
                    propertyId: selectedPropertyId,
                    propertyName: selectedProperty.name,
                    properties: properties,
                    selectedPropertyId: selectedPropertyId,
                    onPropertyChanged: (value) {
                      if (value == null || value.isEmpty) {
                        return;
                      }
                      setState(() => _selectedPropertyId = value);
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

  Future<void> _generateMonthlyChargesManually({
    required String ownerId,
    required Property property,
  }) async {
    final propertyId = property.id;
    final now = DateTime.now();

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
    final billingPeriodEnd = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      1,
    );

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
      helpText: 'Select invoice due date',
    );

    if (dueDate == null || !mounted) {
      return;
    }

    try {
      GrihoFeedback.showInfo(
        context,
        'Calculating charges and resolving tenancies...',
      );

      final results = await Future.wait<dynamic>([
        ref.read(propertyUnitsProvider(propertyId).future),
        ref.read(propertyTenantsProvider(propertyId).future),
      ]);

      final units = results[0] as List<Unit>;
      var tenants = results[1] as List<Tenant>;

      if (tenants.isEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('tenants')
            .where('propertyId', isEqualTo: propertyId)
            .limit(200)
            .get();
        tenants = snap.docs.map(TenantModel.fromFirestore).toList();
      }

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
        GrihoFeedback.showWarning(
          context,
          'No active tenancy found for ${formatBillingMonthYear(billingPeriodStart)}.',
        );
        return;
      }

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
        generateRent: true,
      );

      if (!mounted) {
        return;
      }

      _invalidatePropertyBillingData(ownerId: ownerId, propertyId: propertyId);

      final totalCreated = result.totalGenerated;
      if (totalCreated == 0) {
        GrihoFeedback.showInfo(
          context,
          'Invoices are already up to date for ${formatBillingMonthYear(billingPeriodStart)}.',
        );
        return;
      }

      await AuditLoggerService.log(
        ownerId: ownerId,
        propertyId: propertyId,
        propertyName: property.name,
        category: 'billing',
        actionTitle: 'Monthly Utility Bills Generated',
        details:
            '$totalCreated charge(s) generated/updated for ${formatBillingMonthYear(billingPeriodStart)}.',
      );

      if (!mounted) {
        return;
      }

      GrihoFeedback.showSuccess(
        context,
        '$totalCreated bill(s) generated/updated successfully.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, cleanBillingError(error));
    }
  }
}

// ============================================================================
// RULE GENERATION PROGRESS EVALUATION
// ============================================================================

enum _RuleSyncState {
  pendingGeneration,
  pendingVariableOverride,
  partiallyGenerated,
  fullyGenerated,
  overriddenByHigherRule,
  noEligibleTargets,
  inactiveOrOutsidePeriod,
}

class _RuleMonthEvaluation {
  final _RuleSyncState state;
  final int scopedTargetCount;
  final int effectiveTargetCount;
  final int generatedCount;
  final int pendingOverrideCount;
  final int overriddenByOtherCount;
  final int historicalTotalBills;

  const _RuleMonthEvaluation({
    required this.state,
    required this.scopedTargetCount,
    required this.effectiveTargetCount,
    required this.generatedCount,
    required this.pendingOverrideCount,
    required this.overriddenByOtherCount,
    required this.historicalTotalBills,
  });

  bool get isPendingAction =>
      state == _RuleSyncState.pendingGeneration ||
      state == _RuleSyncState.pendingVariableOverride ||
      state == _RuleSyncState.partiallyGenerated;

  bool get isSyncedOrCovered =>
      state == _RuleSyncState.fullyGenerated ||
      state == _RuleSyncState.overriddenByHigherRule;

  String get statusSummaryText {
    switch (state) {
      case _RuleSyncState.fullyGenerated:
        return 'Synced for current month ($generatedCount/$effectiveTargetCount target(s) billed)';
      case _RuleSyncState.partiallyGenerated:
        final remaining = effectiveTargetCount - generatedCount;
        return 'Partial: $generatedCount/$effectiveTargetCount billed ($remaining remaining)';
      case _RuleSyncState.pendingVariableOverride:
        return 'Pending Override: $pendingOverrideCount Fixed bill(s) ready to be overridden';
      case _RuleSyncState.pendingGeneration:
        return 'Pending: 0/$effectiveTargetCount target(s) generated this month';
      case _RuleSyncState.overriddenByHigherRule:
        return 'Overridden this month by higher-priority / Variable rule';
      case _RuleSyncState.noEligibleTargets:
        return 'No active tenants in scope for current month';
      case _RuleSyncState.inactiveOrOutsidePeriod:
        return historicalTotalBills == 0
            ? 'Not applicable in current month'
            : '$historicalTotalBills historical bill(s) generated';
    }
  }
}

// ============================================================================
// RULES TAB
// ============================================================================

class _RulesTab extends ConsumerWidget {
  final String ownerId;
  final String propertyId;
  final String propertyName;
  final List<Property> properties;
  final ValueChanged<String?> onPropertyChanged;
  final VoidCallback onGenerateBills;

  const _RulesTab({
    required this.ownerId,
    required this.propertyId,
    required this.propertyName,
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
    final unitsAsync = ref.watch(propertyUnitsProvider(propertyId));
    final tenantsAsync = ref.watch(propertyTenantsProvider(propertyId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(
          propertyBillingRulesProvider((
            ownerId: ownerId,
            propertyId: propertyId,
          )),
        );
        ref.invalidate(
          propertyMonthlyBillHistoryProvider((
            ownerId: ownerId,
            propertyId: propertyId,
          )),
        );
        ref.invalidate(propertyUnitsProvider(propertyId));
        ref.invalidate(propertyTenantsProvider(propertyId));
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Iconsax.info_circle,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Rent and Fixed bills are generated automatically by the monthly billing service. Variable bills (including overrides on Fixed bills) are generated manually below.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Property',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: propertyId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(
                      Iconsax.buildings_2,
                      color: GrihoColors.emerald,
                      size: 19,
                    ),
                  ),
                  items: [
                    for (final property in properties)
                      DropdownMenuItem<String>(
                        value: property.id,
                        child: Text(
                          property.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: onPropertyChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GrihoSecondaryButton(
            label: 'Generate Pending Bills / Override Fixed',
            icon: Iconsax.calendar_1,
            onPressed: onGenerateBills,
          ),
          const SizedBox(height: 20),
          rulesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load rules',
              subtitle: 'Unable to load billing rules for this property.',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(
                propertyBillingRulesProvider((
                  ownerId: ownerId,
                  propertyId: propertyId,
                )),
              ),
            ),
            data: (rules) {
              if (rules.isEmpty) {
                return const GrihoStatusState(
                  icon: Iconsax.receipt_item,
                  title: 'No billing rules configured',
                  subtitle:
                      'Create Fixed rules for automatic monthly bills, or Variable rules to generate one-month bills manually.',
                );
              }

              final bills = billHistoryAsync.value ?? [];
              final units = unitsAsync.value ?? [];
              final tenants = tenantsAsync.value ?? [];

              final now = DateTime.now();
              final currentMonthStart = DateTime(now.year, now.month, 1);
              final currentMonthEnd = DateTime(now.year, now.month + 1, 1);

              final activeCurrentMonthRules = rules
                  .where((rule) => rule.isEffectiveForMonth(currentMonthStart))
                  .toList();

              final currentMonthUtilityBills = bills.where((b) {
                return b.type != MonthlyBillType.rent &&
                    b.status != MonthlyBillStatus.cancelled &&
                    b.billingPeriodStart.year == currentMonthStart.year &&
                    b.billingPeriodStart.month == currentMonthStart.month;
              }).toList();

              final activeTargets = _resolveActiveMonthTargets(
                propertyId: propertyId,
                units: units,
                tenants: tenants,
                billingPeriodEndExclusive: currentMonthEnd,
              );

              final evaluationsByRuleId = <String, _RuleMonthEvaluation>{};
              for (final rule in rules) {
                evaluationsByRuleId[rule.id] = _evaluateRuleMonthProgress(
                  rule: rule,
                  activeCurrentMonthRules: activeCurrentMonthRules,
                  activeTargets: activeTargets,
                  currentMonthBills: currentMonthUtilityBills,
                  allPropertyBills: bills,
                  propertyId: propertyId,
                  currentMonthStart: currentMonthStart,
                );
              }

              final pendingThisMonthRules = rules
                  .where(
                    (rule) =>
                        evaluationsByRuleId[rule.id]?.isPendingAction ?? false,
                  )
                  .toList();

              final syncedOrOtherRules = rules
                  .where(
                    (rule) =>
                        !(evaluationsByRuleId[rule.id]?.isPendingAction ??
                            false),
                  )
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Pending This Month',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${pendingThisMonthRules.length}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (pendingThisMonthRules.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Iconsax.tick_circle,
                            color: GrihoColors.emerald,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'All applicable rules for active tenancies are up to date for this month.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    for (final rule in pendingThisMonthRules) ...[
                      _BillingRuleCard(
                        rule: rule,
                        ownerId: ownerId,
                        evaluation: evaluationsByRuleId[rule.id]!,
                      ),
                      const SizedBox(height: 12),
                    ],
                  if (syncedOrOtherRules.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Active, Synced & Other Rules (${syncedOrOtherRules.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final rule in syncedOrOtherRules) ...[
                      _BillingRuleCard(
                        rule: rule,
                        ownerId: ownerId,
                        evaluation: evaluationsByRuleId[rule.id]!,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<({String unitId, String floorId, String tenantId})>
  _resolveActiveMonthTargets({
    required String propertyId,
    required List<Unit> units,
    required List<Tenant> tenants,
    required DateTime billingPeriodEndExclusive,
  }) {
    final floorByUnitId = <String, String>{
      for (final unit in units)
        unit.id.trim(): unit.floorNumber.toString().trim(),
    };

    final result = <({String unitId, String floorId, String tenantId})>[];
    for (final tenant in tenants) {
      if (tenant.status != TenantStatus.active) {
        continue;
      }
      if (tenant.propertyId.trim() != propertyId.trim()) {
        continue;
      }

      final unitId = tenant.unitId.trim();
      final floorId = floorByUnitId[unitId];
      if (unitId.isEmpty || floorId == null || floorId.isEmpty) {
        continue;
      }

      final startedAt = tenant.tenancyStartedAt;
      if (startedAt != null && !startedAt.isBefore(billingPeriodEndExclusive)) {
        continue;
      }

      result.add((
        unitId: unitId,
        floorId: floorId,
        tenantId: tenant.id.trim(),
      ));
    }

    return result;
  }

  bool _ruleMatchesTarget({
    required BillingRule rule,
    required String propertyId,
    required ({String unitId, String floorId, String tenantId}) target,
  }) {
    switch (rule.scopeType) {
      case BillingScopeType.property:
        return rule.scopeId.trim().isEmpty ||
            rule.scopeId.trim() == propertyId.trim();
      case BillingScopeType.floor:
        return rule.scopeId.trim() == target.floorId;
      case BillingScopeType.unit:
        return rule.scopeId.trim() == target.unitId;
      case BillingScopeType.tenant:
        return rule.scopeId.trim() == target.tenantId;
    }
  }

  _RuleMonthEvaluation _evaluateRuleMonthProgress({
    required BillingRule rule,
    required List<BillingRule> activeCurrentMonthRules,
    required List<({String unitId, String floorId, String tenantId})>
    activeTargets,
    required List<MonthlyBill> currentMonthBills,
    required List<MonthlyBill> allPropertyBills,
    required String propertyId,
    required DateTime currentMonthStart,
  }) {
    final historicalTotal = allPropertyBills
        .where(
          (b) => b.sourceRuleId == rule.id || b.overriddenFromRuleId == rule.id,
        )
        .length;

    if (!rule.isEffectiveForMonth(currentMonthStart)) {
      return _RuleMonthEvaluation(
        state: _RuleSyncState.inactiveOrOutsidePeriod,
        scopedTargetCount: 0,
        effectiveTargetCount: 0,
        generatedCount: 0,
        pendingOverrideCount: 0,
        overriddenByOtherCount: 0,
        historicalTotalBills: historicalTotal,
      );
    }

    final scopedTargets = activeTargets
        .where(
          (target) => _ruleMatchesTarget(
            rule: rule,
            propertyId: propertyId,
            target: target,
          ),
        )
        .toList();

    if (scopedTargets.isEmpty) {
      final generatedDirectly = currentMonthBills
          .where((b) => b.sourceRuleId == rule.id)
          .length;

      return _RuleMonthEvaluation(
        state: generatedDirectly > 0
            ? _RuleSyncState.fullyGenerated
            : _RuleSyncState.noEligibleTargets,
        scopedTargetCount: 0,
        effectiveTargetCount: generatedDirectly,
        generatedCount: generatedDirectly,
        pendingOverrideCount: 0,
        overriddenByOtherCount: 0,
        historicalTotalBills: historicalTotal,
      );
    }

    int effectiveTargetCount = 0;
    int generatedCount = 0;
    int pendingOverrideCount = 0;
    int overriddenByOtherCount = 0;

    for (final target in scopedTargets) {
      final candidateRules = activeCurrentMonthRules.where((candidate) {
        return candidate.chargeType == rule.chargeType &&
            _ruleMatchesTarget(
              rule: candidate,
              propertyId: propertyId,
              target: target,
            );
      }).toList()..sort(BillingRuleResolver.compareRulesByPriority);

      final winningRule = candidateRules.isEmpty ? null : candidateRules.first;

      final existingBill = currentMonthBills
          .where(
            (b) =>
                b.unitId == target.unitId &&
                b.tenantId == target.tenantId &&
                b.type.name == rule.chargeType.name,
          )
          .firstOrNull;

      if (rule.valueType == BillingValueType.variable) {
        if (winningRule?.id != rule.id) {
          overriddenByOtherCount++;
          continue;
        }
        effectiveTargetCount++;

        if (existingBill != null && existingBill.sourceRuleId == rule.id) {
          generatedCount++;
        } else if (existingBill != null &&
            existingBill.valueType == BillingValueType.fixed) {
          pendingOverrideCount++;
        }
      } else {
        final isProducedOrOverriddenFromThisRule =
            existingBill != null &&
            (existingBill.sourceRuleId == rule.id ||
                existingBill.overriddenFromRuleId == rule.id);

        if (winningRule?.id == rule.id) {
          effectiveTargetCount++;
          if (isProducedOrOverriddenFromThisRule || existingBill != null) {
            generatedCount++;
          }
        } else if (existingBill != null &&
            existingBill.sourceRuleId == rule.id) {
          effectiveTargetCount++;
          generatedCount++;
        } else {
          overriddenByOtherCount++;
        }
      }
    }

    final _RuleSyncState resolvedState;
    if (effectiveTargetCount == 0 && overriddenByOtherCount > 0) {
      resolvedState = _RuleSyncState.overriddenByHigherRule;
    } else if (generatedCount >= effectiveTargetCount &&
        effectiveTargetCount > 0) {
      resolvedState = _RuleSyncState.fullyGenerated;
    } else if (pendingOverrideCount > 0 && generatedCount == 0) {
      resolvedState = _RuleSyncState.pendingVariableOverride;
    } else if (generatedCount > 0 && generatedCount < effectiveTargetCount) {
      resolvedState = _RuleSyncState.partiallyGenerated;
    } else {
      resolvedState = _RuleSyncState.pendingGeneration;
    }

    return _RuleMonthEvaluation(
      state: resolvedState,
      scopedTargetCount: scopedTargets.length,
      effectiveTargetCount: effectiveTargetCount,
      generatedCount: generatedCount,
      pendingOverrideCount: pendingOverrideCount,
      overriddenByOtherCount: overriddenByOtherCount,
      historicalTotalBills: historicalTotal,
    );
  }
}

// ============================================================================
// GENERATED BILLS TAB (WITH MONTHLY STATEMENT PDF & SAFE REPOSITORY CANCEL)
// ============================================================================

class _GeneratedBillsTab extends ConsumerWidget {
  final String ownerId;
  final String propertyId;
  final String propertyName;
  final List<Property> properties;
  final String selectedPropertyId;
  final ValueChanged<String?> onPropertyChanged;

  const _GeneratedBillsTab({
    required this.ownerId,
    required this.propertyId,
    required this.propertyName,
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
    final unitsAsync = ref.watch(propertyUnitsProvider(propertyId));
    final tenantsAsync = ref.watch(propertyTenantsProvider(propertyId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(
          propertyMonthlyBillHistoryProvider((
            ownerId: ownerId,
            propertyId: propertyId,
          )),
        );
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Property',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedPropertyId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(
                      Iconsax.buildings_2,
                      color: GrihoColors.emerald,
                      size: 19,
                    ),
                  ),
                  items: [
                    for (final property in properties)
                      DropdownMenuItem<String>(
                        value: property.id,
                        child: Text(
                          property.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: onPropertyChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          billsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load invoices',
              subtitle: 'Unable to load invoice batches for this property.',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(
                propertyMonthlyBillHistoryProvider((
                  ownerId: ownerId,
                  propertyId: propertyId,
                )),
              ),
            ),
            data: (bills) {
              if (bills.isEmpty) {
                return const GrihoStatusState(
                  icon: Iconsax.receipt_item,
                  title: 'No invoices generated yet',
                  subtitle:
                      'Rent and Fixed invoices are generated by the monthly billing service. Variable invoices are created manually from the Billing Rules tab.',
                );
              }

              final units = unitsAsync.value ?? [];
              final tenants = tenantsAsync.value ?? [];

              final monthlyGroups = <String, List<MonthlyBill>>{};
              for (final bill in bills) {
                final key =
                    '${bill.billingPeriodStart.year}-${bill.billingPeriodStart.month.toString().padLeft(2, '0')}';
                monthlyGroups.putIfAbsent(key, () => []).add(bill);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Monthly Batches (Rent + Bills)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
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
                          '${monthlyGroups.length} Month(s)',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final entry in monthlyGroups.entries) ...[
                    _MonthBatchCard(
                      ownerId: ownerId,
                      propertyId: propertyId,
                      propertyName: propertyName,
                      periodKey: entry.key,
                      bills: entry.value,
                      units: units,
                      tenants: tenants,
                      onBillChanged: () {
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
// MONTH BATCH CARD (WITH STATEMENT PDF EXPORT)
// ============================================================================

class _MonthBatchCard extends StatelessWidget {
  final String ownerId;
  final String propertyId;
  final String propertyName;
  final String periodKey;
  final List<MonthlyBill> bills;
  final List<Unit> units;
  final List<Tenant> tenants;
  final VoidCallback onBillChanged;

  const _MonthBatchCard({
    required this.ownerId,
    required this.propertyId,
    required this.propertyName,
    required this.periodKey,
    required this.bills,
    required this.units,
    required this.tenants,
    required this.onBillChanged,
  });

  String _unitAndTenantLabel(MonthlyBill bill) {
    final unit = units.where((u) => u.id == bill.unitId).firstOrNull;
    final unitText = unit != null ? 'Unit ${unit.unitNumber}' : bill.unitId;
    final tenant = tenants.where((t) => t.id == bill.tenantId).firstOrNull;
    return tenant != null ? '$unitText (${tenant.name})' : unitText;
  }

  Future<void> _exportBatchStatementPdf(
    BuildContext context, {
    required bool share,
  }) async {
    try {
      final monthLabel = formatBillingMonthYear(bills.first.billingPeriodStart);
      final activeBills = bills
          .where((b) => b.status != MonthlyBillStatus.cancelled)
          .toList();
      final totalBilled = activeBills.fold<double>(0, (s, b) => s + b.amount);
      final totalPaid = activeBills.fold<double>(0, (s, b) => s + b.paidAmount);
      final totalDue = (totalBilled - totalPaid).clamp(0.0, double.infinity);

      final rows = bills.map((bill) {
        final label = bill.title?.trim().isNotEmpty == true
            ? bill.title!.trim()
            : monthlyBillTypeLabel(bill.type);
        return [
          _unitAndTenantLabel(bill),
          label,
          'BDT ${formatBillingAmount(bill.amount)}',
          'BDT ${formatBillingAmount(bill.paidAmount)}',
          bill.effectiveStatus.name.toUpperCase(),
        ];
      }).toList();

      final fileName =
          'Griho_Billing_${propertyName.replaceAll(' ', '_')}_$periodKey';
      final summary =
          'Total Active Billed: BDT ${formatBillingAmount(totalBilled)}   |   '
          'Collected: BDT ${formatBillingAmount(totalPaid)}   |   '
          'Remaining Due: BDT ${formatBillingAmount(totalDue)}';

      if (share) {
        await PdfReceiptService.shareStatementPdf(
          fileName: fileName,
          title: 'Monthly Billing Statement',
          subtitle: '$propertyName • $monthLabel (${bills.length} records)',
          headers: const [
            'Unit / Tenant',
            'Charge',
            'Amount',
            'Paid',
            'Status',
          ],
          rows: rows,
          summaryText: summary,
        );
      } else {
        await PdfReceiptService.previewOrPrintStatement(
          fileName: fileName,
          title: 'Monthly Billing Statement',
          subtitle: '$propertyName • $monthLabel (${bills.length} records)',
          headers: const [
            'Unit / Tenant',
            'Charge',
            'Amount',
            'Paid',
            'Status',
          ],
          rows: rows,
          summaryText: summary,
        );
      }
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      GrihoFeedback.showError(
        context,
        'Unable to generate statement PDF: $error',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstBill = bills.first;
    final activeBills = bills
        .where((b) => b.status != MonthlyBillStatus.cancelled)
        .toList();
    final totalAmount = activeBills.fold<double>(
      0.0,
      (total, b) => total + b.amount,
    );
    final rentCount = bills.where((b) => b.type == MonthlyBillType.rent).length;
    final utilityCount = bills.length - rentCount;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showBatchDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Iconsax.folder_open,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatBillingMonthYear(firstBill.billingPeriodStart),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$rentCount rent(s) • $utilityCount utility bill(s)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Iconsax.arrow_right_3, size: 16),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Billed Total',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '৳${formatBillingAmount(totalAmount)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton.outlined(
                        tooltip: 'Print / Save Statement PDF',
                        onPressed: () =>
                            _exportBatchStatementPdf(context, share: false),
                        icon: const Icon(Iconsax.document_text, size: 18),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: () => _showBatchDetails(context),
                        icon: const Icon(Iconsax.eye, size: 16),
                        label: const Text('Inspect'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBatchDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            final theme = Theme.of(ctx);
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatBillingMonthYear(
                                bills.first.billingPeriodStart,
                              ),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Unit & Tenant Rent + Bills (${bills.length})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Print / Save PDF',
                        onPressed: () =>
                            _exportBatchStatementPdf(ctx, share: false),
                        icon: const Icon(Iconsax.document_text, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Share Statement PDF',
                        onPressed: () =>
                            _exportBatchStatementPdf(ctx, share: true),
                        icon: const Icon(Iconsax.export_3, size: 20),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Iconsax.close_circle),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: bills.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      return _DetailedBillItem(
                        ownerId: ownerId,
                        propertyId: propertyId,
                        propertyName: propertyName,
                        bill: bills[index],
                        units: units,
                        tenants: tenants,
                        onCancelled: () {
                          Navigator.pop(ctx);
                          onBillChanged();
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// DETAILED BILL ITEM (USES REPOSITORY CANCEL WITH PENDING-PAYMENT GUARDRAIL)
// ============================================================================

class _DetailedBillItem extends ConsumerStatefulWidget {
  final String ownerId;
  final String propertyId;
  final String propertyName;
  final MonthlyBill bill;
  final List<Unit> units;
  final List<Tenant> tenants;
  final VoidCallback onCancelled;

  const _DetailedBillItem({
    required this.ownerId,
    required this.propertyId,
    required this.propertyName,
    required this.bill,
    required this.units,
    required this.tenants,
    required this.onCancelled,
  });

  @override
  ConsumerState<_DetailedBillItem> createState() => _DetailedBillItemState();
}

class _DetailedBillItemState extends ConsumerState<_DetailedBillItem> {
  bool _cancelling = false;

  String _resolveTargetLabel() {
    final matchedUnit = widget.units
        .where((u) => u.id == widget.bill.unitId)
        .firstOrNull;
    final unitText = matchedUnit != null
        ? (matchedUnit.name?.isNotEmpty == true
              ? '${matchedUnit.name} (Unit ${matchedUnit.unitNumber})'
              : 'Unit ${matchedUnit.unitNumber}')
        : 'Unit ${widget.bill.unitId}';

    final matchedTenant = widget.tenants
        .where((t) => t.id == widget.bill.tenantId)
        .firstOrNull;
    final tenantText = matchedTenant != null ? ' • ${matchedTenant.name}' : '';

    return '$unitText$tenantText';
  }

  Future<void> _cancelUnpaidBill() async {
    if (_cancelling) {
      return;
    }

    final bill = widget.bill;
    final customTitle = bill.title?.trim();
    final displayTitle = (customTitle != null && customTitle.isNotEmpty)
        ? customTitle
        : monthlyBillTypeLabel(bill.type);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Unpaid Bill?'),
        content: Text(
          'Cancel "$displayTitle" (৳${formatBillingAmount(bill.amount)}) for ${_resolveTargetLabel()}?\n\n'
          'Note: Only unpaid bills with zero payment and no pending verification can be cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Bill'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _cancelling = true);

    try {
      await ref
          .read(monthlyBillRepositoryProvider)
          .cancelMonthlyBill(billId: bill.id);

      await AuditLoggerService.log(
        ownerId: widget.ownerId,
        propertyId: widget.propertyId,
        propertyName: widget.propertyName,
        category: 'billing',
        actionTitle: 'Unpaid Bill Cancelled',
        details:
            '$displayTitle (৳${formatBillingAmount(bill.amount)}) cancelled for ${_resolveTargetLabel()}.',
      );

      if (!mounted) {
        return;
      }

      GrihoFeedback.showSuccess(context, 'Unpaid bill cancelled successfully.');
      widget.onCancelled();
    } catch (e) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, cleanBillingError(e));
    } finally {
      if (mounted) {
        setState(() => _cancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bill = widget.bill;
    final customTitle = bill.title?.trim();
    final displayTitle = (customTitle != null && customTitle.isNotEmpty)
        ? customTitle
        : monthlyBillTypeLabel(bill.type);

    final canCancel =
        bill.type != MonthlyBillType.rent &&
        bill.status == MonthlyBillStatus.unpaid &&
        bill.paidAmount == 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  monthlyBillTypeIcon(bill.type),
                  size: 19,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _resolveTargetLabel(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (bill.isOverriddenByVariable) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Variable Override (Replaced Fixed ৳${formatBillingAmount(bill.overriddenFromAmount)})',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '৳${formatBillingAmount(bill.amount)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  BillingStatusChip(status: bill.effectiveStatus),
                ],
              ),
            ],
          ),
          if (canCancel) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _cancelling ? null : _cancelUnpaidBill,
                icon: Icon(
                  Iconsax.close_circle,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                label: Text(
                  _cancelling ? 'Cancelling...' : 'Cancel Unpaid Bill',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
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
  final _RuleMonthEvaluation evaluation;

  const _BillingRuleCard({
    required this.rule,
    required this.ownerId,
    required this.evaluation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = _resolveRuleStatus(rule);
    final chargeName = billingChargeTypeLabel(rule.chargeType);
    final isSynced = evaluation.isSyncedOrCovered;
    final isPending = evaluation.isPendingAction;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final result = await context.push<bool>(
            RouteNames.editBillingRule,
            extra: rule,
          );
          // EditBillingRuleScreen already logs the audit entry; just invalidate cache here.
          if (result == true) {
            ref.invalidate(
              propertyBillingRulesProvider((
                ownerId: ownerId,
                propertyId: rule.propertyId,
              )),
            );
          }
        },
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
                      billingChargeTypeIcon(rule.chargeType),
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
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
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
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      icon: Iconsax.wallet_3,
                      label: 'Amount',
                      value: '৳${formatBillingAmount(rule.amount)}',
                    ),
                  ),
                  Expanded(
                    child: _InfoItem(
                      icon: Iconsax.repeat,
                      label: 'Recurrence',
                      value: rule.valueType == BillingValueType.fixed
                          ? 'Fixed (Monthly)'
                          : 'Variable (1 Month)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      icon: Iconsax.hierarchy,
                      label: 'Scope',
                      value: rule.scopeType.name.toUpperCase(),
                    ),
                  ),
                  Expanded(
                    child: _InfoItem(
                      icon: Iconsax.calendar_1,
                      label: 'Effective From',
                      value:
                          '${rule.effectiveFrom.month}/${rule.effectiveFrom.year}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSynced
                      ? GrihoColors.emerald.withValues(alpha: 0.12)
                      : isPending
                      ? GrihoColors.warning.withValues(alpha: 0.14)
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSynced
                          ? Iconsax.verify
                          : isPending
                          ? Iconsax.clock
                          : Iconsax.info_circle,
                      size: 16,
                      color: isSynced
                          ? GrihoColors.emerald
                          : isPending
                          ? GrihoColors.warning
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        evaluation.statusSummaryText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSynced
                              ? GrihoColors.emerald
                              : isPending
                              ? GrihoColors.warning
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(
                      Iconsax.arrow_right_3,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static _RuleStatus _resolveRuleStatus(BillingRule rule) {
    if (!rule.isActive) {
      return _RuleStatus.inactive;
    }
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final effectiveStart = DateTime(
      rule.effectiveFrom.year,
      rule.effectiveFrom.month,
      1,
    );

    if (currentMonthStart.isBefore(effectiveStart)) {
      return _RuleStatus.scheduled;
    }
    if (!rule.isEffectiveForMonth(currentMonthStart)) {
      return _RuleStatus.historical;
    }
    return _RuleStatus.active;
  }
}

enum _RuleStatus { active, scheduled, historical, inactive }

class _RuleStatusChip extends StatelessWidget {
  final _RuleStatus status;

  const _RuleStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, icon) = switch (status) {
      _RuleStatus.active => ('Active', Iconsax.tick_circle),
      _RuleStatus.scheduled => ('Scheduled', Iconsax.clock),
      _RuleStatus.historical => ('Expired', Iconsax.timer_1),
      _RuleStatus.inactive => ('Inactive', Iconsax.close_circle),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

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
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
