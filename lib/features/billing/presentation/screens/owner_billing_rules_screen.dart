import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/providers/property_tenants_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';

import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/monthly_bill.dart';
import '../controllers/generate_monthly_charges_controller.dart';
import '../providers/billing_rule_provider.dart';
import '../providers/monthly_bill_provider.dart';
import '../providers/tenancy_billing_target_provider.dart';

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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          message: 'Unable to load your profile.',
          onRetry: () => ref.invalidate(currentUserProfileProvider),
        ),
        data: (profile) {
          if (profile == null) {
            return _ErrorView(
              message: 'User profile not found.',
              onRetry: () => ref.invalidate(currentUserProfileProvider),
            );
          }

          final ownerId = profile.uid.trim();
          if (ownerId.isEmpty) {
            return const _ErrorView(message: 'Unable to determine owner ID.');
          }

          return propertiesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _ErrorView(
              message: 'Unable to load properties.',
              onRetry: () => ref.invalidate(currentOwnerPropertiesProvider),
            ),
            data: (properties) {
              if (properties.isEmpty) {
                return const _EmptyState(
                  icon: Icons.home_work_outlined,
                  title: 'No properties found',
                  message: 'Add a property before creating billing rules.',
                );
              }

              final selectedPropertyId =
                  properties.any((p) => p.id == _selectedPropertyId)
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
                      setState(() => _selectedPropertyId = value);
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

  Future<void> _generateMonthlyCharges({
    required String ownerId,
    required String propertyId,
  }) async {
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
      helpText: 'Select bill due date',
    );

    if (dueDate == null || !mounted) {
      return;
    }

    try {
      _showMessage('Checking and generating charges...');

      final units = await ref.read(propertyUnitsProvider(propertyId).future);
      final tenants = await ref.read(
        propertyTenantsProvider(propertyId).future,
      );

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
          'No tenancy found for ${_formatMonth(billingPeriodStart)}.',
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
      );

      if (!mounted) {
        return;
      }

      _invalidatePropertyBillingData(ownerId: ownerId, propertyId: propertyId);

      final rentCount = result.generatedRents.length;
      final billCount = result.generatedBills.length;

      if (rentCount == 0 && billCount == 0) {
        _showMessage(
          'Bills are already up to date for ${_formatMonth(billingPeriodStart)}.',
        );
        return;
      }

      _showMessage(
        '$rentCount rent & $billCount bill(s) generated successfully.',
      );
    } catch (error, stackTrace) {
      debugPrint('BILLING ERROR: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      _showMessage(_cleanErrorMessage(error));
    }
  }

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
    return message.startsWith('Exception: ') ? message.substring(11) : message;
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
// RULES TAB (ফিল্টারিং ও পরিচ্ছন্ন ভিউ)
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
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        children: [
          Text(
            'Billing Rules',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage rules and generate monthly charges.',
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _ErrorCard(
              message: 'Unable to load billing rules.',
              onRetry: () => ref.invalidate(
                propertyBillingRulesProvider((
                  ownerId: ownerId,
                  propertyId: propertyId,
                )),
              ),
            ),
            data: (rules) {
              if (rules.isEmpty) {
                return const _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No billing rules',
                  message:
                      'No billing rules have been created for this property yet.',
                );
              }

              final bills = billHistoryAsync.value ?? [];

              // যে রুলগুলো থেকে এখনো কোনো বিল তৈরি হয়নি
              final pendingRules = rules.where((rule) {
                final hasBills = bills.any((b) => b.sourceRuleId == rule.id);
                return !hasBills;
              }).toList();

              // যে রুলগুলো ইতিমধ্যে বিল জেনারেট করে ফেলেছে
              final processedRules = rules.where((rule) {
                final hasBills = bills.any((b) => b.sourceRuleId == rule.id);
                return hasBills;
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Ready to Generate',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
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
                          '${pendingRules.length}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (pendingRules.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'All rules have been processed or no pending rules available.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    for (final rule in pendingRules) ...[
                      _BillingRuleCard(
                        rule: rule,
                        ownerId: ownerId,
                        generatedBillCount: 0,
                      ),
                      const SizedBox(height: 12),
                    ],

                  // ইতিমধ্যে জেনারেটেড রুলগুলো কোলাপ্সিবল রাখা
                  if (processedRules.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Theme(
                      data: theme.copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          'Already Generated Rules (${processedRules.length})',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        children: [
                          for (final rule in processedRules) ...[
                            _BillingRuleCard(
                              rule: rule,
                              ownerId: ownerId,
                              generatedBillCount: bills
                                  .where((b) => b.sourceRuleId == rule.id)
                                  .length,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
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
// GENERATED BILLS TAB (মাসভিত্তিক গ্রুপ ও বিস্তারিত ভিউ)
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
            'Monthly batches generated for this property.',
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorCard(
              message: 'Unable to load bills.',
              onRetry: () => ref.invalidate(
                propertyMonthlyBillHistoryProvider((
                  ownerId: ownerId,
                  propertyId: propertyId,
                )),
              ),
            ),
            data: (bills) {
              if (bills.isEmpty) {
                return const _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No generated bills',
                  message: 'No bills generated for this property yet.',
                );
              }

              final units = unitsAsync.value ?? [];
              final tenants = tenantsAsync.value ?? [];

              // মাস অনুযায়ী গ্রুপ করা (Grouping bills by month)
              final Map<String, List<MonthlyBill>> monthlyGroups = {};
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
                        'Billing Batches',
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
                          '${monthlyGroups.length} Month(s)',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final entry in monthlyGroups.entries) ...[
                    _MonthBatchCard(
                      periodKey: entry.key,
                      bills: entry.value,
                      units: units,
                      tenants: tenants,
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
// MONTH BATCH CARD (ক্লিক করলে সব বিল দেখাবে)
// ============================================================================

class _MonthBatchCard extends StatelessWidget {
  final String periodKey;
  final List<MonthlyBill> bills;
  final List<Unit> units;
  final List<Tenant> tenants;

  const _MonthBatchCard({
    required this.periodKey,
    required this.bills,
    required this.units,
    required this.tenants,
  });

  String _formatMonthYear(DateTime date) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstBill = bills.first;
    final totalAmount = bills.fold<double>(0, (sum, b) => sum + b.amount);

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // BottomSheet-এ ওই মাসের সব বিল বিস্তারিত দেখানো
          _showBatchDetails(context);
        },
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
                      Icons.folder_outlined,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatMonthYear(firstBill.billingPeriodStart),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${bills.length} charges generated',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
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
                        'Total Billed',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '৳${totalAmount.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => _showBatchDetails(context),
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: const Text('View All Bills'),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatMonthYear(bills.first.billingPeriodStart),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'All Unit & Tenant Charges (${bills.length})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
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
                      final bill = bills[index];
                      return _DetailedBillItem(
                        bill: bill,
                        units: units,
                        tenants: tenants,
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
// DETAILED BILL ITEM (ইনডিভিজুয়াল আইটেম ভিউ)
// ============================================================================

class _DetailedBillItem extends StatelessWidget {
  final MonthlyBill bill;
  final List<Unit> units;
  final List<Tenant> tenants;

  const _DetailedBillItem({
    required this.bill,
    required this.units,
    required this.tenants,
  });

  String _resolveTargetLabel() {
    final matchedUnit = units.where((u) => u.id == bill.unitId).firstOrNull;
    final unitText = matchedUnit != null
        ? (matchedUnit.name?.isNotEmpty == true
              ? '${matchedUnit.name} (Unit ${matchedUnit.unitNumber})'
              : 'Unit ${matchedUnit.unitNumber}')
        : 'Unit ${bill.unitId}';

    final matchedTenant = tenants
        .where((t) => t.id == bill.tenantId)
        .firstOrNull;
    final tenantText = matchedTenant != null ? ' • ${matchedTenant.name}' : '';

    return '$unitText$tenantText';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _billTypeIcon(bill.type),
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _billTypeLabel(bill.type),
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '৳${bill.amount.toStringAsFixed(2)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              _BillStatusChip(status: bill.status),
            ],
          ),
        ],
      ),
    );
  }

  static IconData _billTypeIcon(MonthlyBillType type) {
    switch (type) {
      case MonthlyBillType.rent:
        return Icons.house_outlined;
      case MonthlyBillType.water:
        return Icons.water_drop_outlined;
      case MonthlyBillType.gas:
        return Icons.local_fire_department_outlined;
      case MonthlyBillType.garbage:
        return Icons.delete_outline;
      case MonthlyBillType.serviceCharge:
        return Icons.build_outlined;
      case MonthlyBillType.electricity:
        return Icons.bolt_outlined;
      case MonthlyBillType.other:
        return Icons.receipt_long_outlined;
    }
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
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.payments_outlined,
                    label: 'Amount',
                    value: '৳${rule.amount.toStringAsFixed(2)}',
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.tune_outlined,
                    label: 'Type',
                    value: rule.valueType == BillingValueType.fixed
                        ? 'Fixed'
                        : 'Variable',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.account_tree_outlined,
                    label: 'Scope',
                    value: rule.scopeType.name.toUpperCase(),
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.calendar_month_outlined,
                    label: 'Effective',
                    value:
                        '${rule.effectiveFrom.month}/${rule.effectiveFrom.year}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                generatedBillCount == 0
                    ? 'No bills generated yet'
                    : '$generatedBillCount bill(s) generated from this rule',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
}

enum _RuleStatus { active, scheduled, historical, inactive }

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
        break;
      case _RuleStatus.scheduled:
        label = 'Scheduled';
        icon = Icons.schedule_outlined;
        break;
      case _RuleStatus.historical:
        label = 'Historical';
        icon = Icons.history_outlined;
        break;
      case _RuleStatus.inactive:
        label = 'Inactive';
        icon = Icons.block_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
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

class _BillStatusChip extends StatelessWidget {
  final MonthlyBillStatus status;

  const _BillStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color bg = status == MonthlyBillStatus.paid
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.errorContainer;
    final Color fg = status == MonthlyBillStatus.paid
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onErrorContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
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
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

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

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorView({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          Text(message),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}

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
            Text(message),
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
