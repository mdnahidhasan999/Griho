import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../domain/entities/billing_rule.dart';
import '../providers/billing_rule_provider.dart';

class OwnerBillingRulesScreen extends ConsumerStatefulWidget {
  const OwnerBillingRulesScreen({
    super.key,
  });

  @override
  ConsumerState<OwnerBillingRulesScreen> createState() =>
      _OwnerBillingRulesScreenState();
}

class _OwnerBillingRulesScreenState
    extends ConsumerState<OwnerBillingRulesScreen> {
  String? _selectedPropertyId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final profileAsync = ref.watch(
      currentUserProfileProvider,
    );

    final propertiesAsync = ref.watch(
      currentOwnerPropertiesProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Billing Rules',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push(
            RouteNames.ownerBillingSetup,
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Rule'),
      ),
      body: profileAsync.when(
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stackTrace) {
          return _ErrorView(
            message: 'Unable to load your profile.',
            onRetry: () {
              ref.invalidate(
                currentUserProfileProvider,
              );
            },
          );
        },
        data: (profile) {
          if (profile == null) {
            return _ErrorView(
              message: 'User profile not found.',
              onRetry: () {
                ref.invalidate(
                  currentUserProfileProvider,
                );
              },
            );
          }

          final ownerId = profile.uid.trim();

          if (ownerId.isEmpty) {
            return const _ErrorView(
              message: 'Unable to determine owner ID.',
            );
          }

          return propertiesAsync.when(
            loading: () {
              return const Center(
                child: CircularProgressIndicator(),
              );
            },
            error: (error, stackTrace) {
              return _ErrorView(
                message: 'Unable to load properties.',
                onRetry: () {
                  ref.invalidate(
                    currentOwnerPropertiesProvider,
                  );
                },
              );
            },
            data: (properties) {
              if (properties.isEmpty) {
                return const _EmptyState(
                  icon: Icons.home_work_outlined,
                  title: 'No properties found',
                  message:
                  'Add a property before creating billing rules.',
                );
              }

              final selectedPropertyId = properties.any(
                    (property) =>
                property.id == _selectedPropertyId,
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

              final rulesAsync = ref.watch(
                propertyBillingRulesProvider(
                  (
                  ownerId: ownerId,
                  propertyId: selectedPropertyId,
                  ),
                ),
              );

              return RefreshIndicator(
                onRefresh: () async {
                  final provider = propertyBillingRulesProvider(
                    (
                    ownerId: ownerId,
                    propertyId: selectedPropertyId,
                    ),
                  );

                  ref.invalidate(provider);

                  await ref.read(provider.future);
                },
                child: ListView(
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    100,
                  ),
                  children: [
                    Text(
                      'Billing Management',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'View and manage billing rules for your properties.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                        theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ========================================================
                    // PROPERTY SELECTOR
                    // ========================================================

                    DropdownButtonFormField<String>(
                      initialValue: selectedPropertyId,
                      decoration: const InputDecoration(
                        labelText: 'Property',
                        prefixIcon: Icon(
                          Icons.apartment_outlined,
                        ),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final property in properties)
                          DropdownMenuItem<String>(
                            value: property.id,
                            child: Text(
                              property.name,
                              overflow:
                              TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null ||
                            value.isEmpty) {
                          return;
                        }

                        setState(() {
                          _selectedPropertyId = value;
                        });
                      },
                    ),

                    const SizedBox(height: 24),

                    // ========================================================
                    // RULES
                    // ========================================================

                    rulesAsync.when(
                      loading: () {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child:
                            CircularProgressIndicator(),
                          ),
                        );
                      },
                      error: (error, stackTrace) {
                        return _ErrorCard(
                          message:
                          'Unable to load billing rules.',
                          onRetry: () {
                            ref.invalidate(
                              propertyBillingRulesProvider(
                                (
                                ownerId: ownerId,
                                propertyId:
                                selectedPropertyId,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      data: (rules) {
                        if (rules.isEmpty) {
                          return const _EmptyState(
                            icon:
                            Icons.receipt_long_outlined,
                            title: 'No billing rules',
                            message:
                            'No billing rules have been created for this property yet.',
                          );
                        }

                        return Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Billing Rules',
                                  style: theme
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                    fontWeight:
                                    FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius:
                                    BorderRadius.circular(
                                      20,
                                    ),
                                  ),
                                  child: Text(
                                    '${rules.length}',
                                    style: theme
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                      fontWeight:
                                      FontWeight.w700,
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
            },
          );
        },
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

  const _BillingRuleCard({
    required this.rule,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context,
      WidgetRef ref,) {
    final theme = Theme.of(context);

    final chargeName =
    _chargeTypeLabel(rule.chargeType);

    final amountText =
    rule.valueType == BillingValueType.variable
        ? 'Variable'
        : '৳${rule.amount?.toStringAsFixed(2) ?? '0.00'}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // ================================================================
            // HEADER
            // ================================================================

            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                    theme.colorScheme.primaryContainer,
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _chargeTypeIcon(
                      rule.chargeType,
                    ),
                    color: theme
                        .colorScheme
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
                        rule.title
                            ?.trim()
                            .isNotEmpty ==
                            true
                            ? rule.title!
                            : chargeName,
                        maxLines: 2,
                        overflow:
                        TextOverflow.ellipsis,
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
                        chargeName,
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

                const SizedBox(width: 8),

                _StatusChip(
                  isActive: rule.isActive,
                ),

                PopupMenuButton<String>(
                  tooltip:
                  'Manage billing rule',
                  onSelected: (value) async {
                    if (value != 'edit') {
                      return;
                    }

                    final result =
                    await context.push(
                      RouteNames.editBillingRule
                          .replaceFirst(
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
                        propertyBillingRulesProvider(
                          (
                          ownerId: ownerId,
                          propertyId:
                          rule.propertyId,
                          ),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                            ),
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

            // ================================================================
            // AMOUNT + VALUE TYPE
            // ================================================================

            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon:
                    Icons.payments_outlined,
                    label: 'Amount',
                    value: amountText,
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.tune_outlined,
                    label: 'Type',
                    value:
                    _valueTypeLabel(
                      rule.valueType,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ================================================================
            // SCOPE + START DATE
            // ================================================================

            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon:
                    Icons.account_tree_outlined,
                    label: 'Scope',
                    value:
                    _scopeTypeLabel(
                      rule.scopeType,
                    ),
                  ),
                ),
                Expanded(
                  child: _InfoItem(
                    icon: Icons
                        .calendar_month_outlined,
                    label: 'Starts',
                    value: _formatDate(
                      rule.effectiveFrom,
                    ),
                  ),
                ),
              ],
            ),

            // ================================================================
            // END DATE
            // ================================================================

            if (rule.effectiveTo != null) ...[
              const SizedBox(height: 14),
              _InfoItem(
                icon:
                Icons.event_busy_outlined,
                label: 'Ends',
                value: _formatDate(
                  rule.effectiveTo!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _chargeTypeLabel(BillingChargeType type,) {
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

  static IconData _chargeTypeIcon(BillingChargeType type,) {
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

  static String _valueTypeLabel(BillingValueType type,) {
    switch (type) {
      case BillingValueType.fixed:
        return 'Fixed';

      case BillingValueType.variable:
        return 'Variable';
    }
  }

  static String _scopeTypeLabel(BillingScopeType type,) {
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

  static String _formatDate(DateTime date,) {
    final day =
    date.day.toString().padLeft(2, '0');

    final month =
    date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
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
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color:
          theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow:
                TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w600,
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
// STATUS CHIP
// ============================================================================

class _StatusChip extends StatelessWidget {
  final bool isActive;

  const _StatusChip({
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? theme
            .colorScheme
            .primaryContainer
            : theme
            .colorScheme
            .surfaceContainerHighest,
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: theme.textTheme.labelMedium
            ?.copyWith(
          fontWeight: FontWeight.w700,
          color: isActive
              ? theme
              .colorScheme
              .onPrimaryContainer
              : theme
              .colorScheme
              .onSurfaceVariant,
        ),
      ),
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
      padding:
      const EdgeInsets.symmetric(
        vertical: 48,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 56,
            color:
            theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
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

  const _ErrorView({
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign:
              TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onRetry,
                child:
                const Text('Retry'),
              ),
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

  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding:
        const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign:
              TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh,
              ),
              label:
              const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}