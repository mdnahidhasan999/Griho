// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/widgets/griho_picker_field.dart';
import '../../../../core/utils/phone_number_utils.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';
import '../../domain/entities/create_tenant_request.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/tenant_search_result.dart';
import '../controllers/tenant_controller.dart';
import '../providers/search_registered_tenant_provider.dart';
import '../providers/tenant_invitation_provider.dart';
import '../widgets/tenant_ui_helpers.dart';

enum _TenantSearchType { grihoId, phone }

enum _InviteMethod { phone, email, grihoId }

class _InviteChoice {
  final _InviteMethod method;
  final double rentAmount;
  final String? email;
  final String? grihoId;

  const _InviteChoice({
    required this.method,
    required this.rentAmount,
    this.email,
    this.grihoId,
  });
}

class AddTenantScreen extends ConsumerStatefulWidget {
  const AddTenantScreen({super.key});

  @override
  ConsumerState<AddTenantScreen> createState() => _AddTenantScreenState();
}

class _AddTenantScreenState extends ConsumerState<AddTenantScreen> {
  final _formKey = GlobalKey<FormState>();

  final _searchController = TextEditingController();
  final _searchPhoneController = TextEditingController();

  final _nameController = TextEditingController();
  final _tenantPhoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _nidController = TextEditingController();

  Tenant? _createdTenant;
  _InviteChoice? _pendingChoice;

  bool _isCreatingInvitation = false;
  Property? _selectedProperty;
  Unit? _selectedUnit;

  _TenantSearchType _searchType = _TenantSearchType.grihoId;
  TenantSearchResult? _searchResult;

  bool _isSearching = false;
  bool _hasSearched = false;
  String? _searchError;

  String _searchPhoneNumber = '';
  String _phoneNumber = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchPhoneController.dispose();
    _nameController.dispose();
    _tenantPhoneController.dispose();
    _emailController.dispose();
    _nidController.dispose();
    super.dispose();
  }

  String? _getValidatedPhone() {
    final cleanPhone = PhoneNumberUtils.clean(_phoneNumber);
    if (!PhoneNumberUtils.isValid(cleanPhone)) {
      return null;
    }
    return PhoneNumberUtils.normalize(cleanPhone);
  }

  void _changeSearchType(_TenantSearchType type) {
    if (_searchType == type) {
      return;
    }
    setState(() {
      _searchType = type;
      _searchController.clear();
      _searchPhoneController.clear();
      _searchPhoneNumber = '';
      _searchResult = null;
      _searchError = null;
      _hasSearched = false;
    });
  }

  void _onGrihoIdChanged(String value) {
    if (!_hasSearched && _searchResult == null && _searchError == null) {
      return;
    }
    setState(() {
      _searchResult = null;
      _searchError = null;
      _hasSearched = false;
    });
  }

  void _onSearchPhoneChanged(String value) {
    _searchPhoneNumber = value;
    if (!_hasSearched && _searchResult == null && _searchError == null) {
      return;
    }
    setState(() {
      _searchResult = null;
      _searchError = null;
      _hasSearched = false;
    });
  }

  Future<void> _searchRegisteredUser() async {
    FocusScope.of(context).unfocus();
    String? searchValue;

    if (_searchType == _TenantSearchType.grihoId) {
      final value = _searchController.text.trim().toUpperCase();
      if (value.isEmpty) {
        setState(() {
          _hasSearched = false;
          _searchResult = null;
          _searchError = 'Please enter a Griho ID.';
        });
        return;
      }
      searchValue = value;
    } else {
      final cleanPhone = PhoneNumberUtils.clean(_searchPhoneNumber);
      if (cleanPhone.isEmpty) {
        setState(() {
          _hasSearched = false;
          _searchResult = null;
          _searchError = 'Please enter a phone number.';
        });
        return;
      }
      if (!PhoneNumberUtils.isValid(cleanPhone)) {
        setState(() {
          _hasSearched = false;
          _searchResult = null;
          _searchError = 'Please enter a valid international phone number.';
        });
        return;
      }
      searchValue = PhoneNumberUtils.normalize(cleanPhone);
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchResult = null;
      _searchError = null;
    });

    try {
      final searchUseCase = ref.read(searchRegisteredTenantProvider);
      final TenantSearchResult? result =
          _searchType == _TenantSearchType.grihoId
          ? await searchUseCase.byPublicId(searchValue)
          : await searchUseCase.byPhone(searchValue);

      if (!mounted) {
        return;
      }

      setState(() {
        _isSearching = false;
        _searchResult = result;
      });

      if (result != null) {
        _fillFromSearchResult(result);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSearching = false;
        _searchResult = null;
        _searchError = 'Unable to search the registered Griho user.';
      });
    }
  }

  void _fillFromSearchResult(TenantSearchResult result) {
    final name = result.name.trim();
    if (name.isNotEmpty) {
      _nameController.text = name;
    }

    final email = result.email?.trim();
    if (email != null && email.isNotEmpty) {
      _emailController.text = email;
    }

    final cleanPhone = PhoneNumberUtils.clean(result.phone);
    if (cleanPhone.isNotEmpty && PhoneNumberUtils.isValid(cleanPhone)) {
      _phoneNumber = PhoneNumberUtils.normalize(cleanPhone);
      final digitsOnly = cleanPhone.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length >= 10) {
        _tenantPhoneController.text = digitsOnly.substring(
          digitsOnly.length - 10,
        );
      } else {
        _tenantPhoneController.text = digitsOnly;
      }
    }
  }

  void _clearSearchResult() {
    setState(() {
      _searchResult = null;
      _hasSearched = false;
      _searchError = null;
      _searchController.clear();
      _searchPhoneController.clear();
      _searchPhoneNumber = '';
    });
  }

  void _onPhoneChanged(String value) {
    final cleanCurrent = PhoneNumberUtils.clean(value);

    if (_searchResult != null) {
      final cleanSearched = PhoneNumberUtils.clean(_searchResult!.phone);
      if (cleanSearched != cleanCurrent) {
        setState(() => _searchResult = null);
      }
    }

    _phoneNumber = cleanCurrent;
  }

  Future<void> _createTenant() async {
    FocusScope.of(context).unfocus();

    final existingTenant = _createdTenant;
    if (existingTenant != null) {
      final pendingChoice = _pendingChoice;
      if (pendingChoice != null) {
        await _createInvitation(tenant: existingTenant, choice: pendingChoice);
        return;
      }

      final choice = await _showInvitationConfirmation(tenant: existingTenant);
      if (!mounted) {
        return;
      }
      if (choice == null) {
        Navigator.of(context).pop(existingTenant);
        return;
      }

      _pendingChoice = choice;
      await _createInvitation(tenant: existingTenant, choice: choice);
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final property = _selectedProperty;
    final unit = _selectedUnit;
    if (property == null || unit == null) {
      return;
    }

    if (unit.status != UnitStatus.available) {
      GrihoFeedback.showError(
        context,
        'Selected unit is not vacant. Please choose an available unit.',
      );
      return;
    }

    final phone = _getValidatedPhone();
    if (phone == null) {
      GrihoFeedback.showError(
        context,
        'Please enter a valid international phone number.',
      );
      return;
    }

    final request = CreateTenantRequest(
      userId: _searchResult?.userId,
      propertyId: property.id,
      unitId: unit.id,
      name: _nameController.text.trim(),
      phone: phone,
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      nidNumber: _nidController.text.trim().isEmpty
          ? null
          : _nidController.text.trim(),
    );

    final tenant = await ref
        .read(tenantControllerProvider.notifier)
        .createTenant(request);

    if (!mounted) {
      return;
    }

    if (tenant == null) {
      final state = ref.read(tenantControllerProvider);
      GrihoFeedback.showError(
        context,
        state.error?.toString() ?? 'Unable to create tenant.',
      );
      return;
    }

    setState(() => _createdTenant = tenant);

    final choice = await _showInvitationConfirmation(tenant: tenant);
    if (!mounted) {
      return;
    }

    if (choice == null) {
      Navigator.of(context).pop(tenant);
      return;
    }

    _pendingChoice = choice;
    await _createInvitation(tenant: tenant, choice: choice);
  }

  Future<_InviteChoice?> _showInvitationConfirmation({required Tenant tenant}) {
    return showDialog<_InviteChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _InvitationConfirmationDialog(
        tenant: tenant,
        initialEmail: _searchResult?.email,
        initialGrihoId: _searchResult?.publicId,
      ),
    );
  }

  Future<void> _createInvitation({
    required Tenant tenant,
    required _InviteChoice choice,
  }) async {
    if (_isCreatingInvitation) {
      return;
    }

    final rentAmount = choice.rentAmount;

    setState(() {
      _isCreatingInvitation = true;
      _pendingChoice = choice;
    });

    try {
      final invitation = await ref.read(createTenantInvitationProvider)(
        tenantId: tenant.id,
        propertyId: tenant.propertyId,
        unitId: tenant.unitId,
        phone: choice.method == _InviteMethod.phone ? tenant.phone : null,
        targetEmail: choice.method == _InviteMethod.email ? choice.email : null,
        targetGrihoId: choice.method == _InviteMethod.grihoId
            ? choice.grihoId
            : null,
        targetName: tenant.name,
        rentAmount: rentAmount,
      );

      if (!mounted) {
        return;
      }

      _pendingChoice = null;

      await _showInvitationCreatedDialog(
        invitationToken: invitation.token,
        rentAmount: rentAmount,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(tenant);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _pendingChoice = choice;
      GrihoFeedback.showError(
        context,
        'Tenant created, but invitation failed. Tap "Retry Invitation". $error',
      );
    } finally {
      if (mounted) {
        setState(() => _isCreatingInvitation = false);
      }
    }
  }

  Future<void> _showInvitationCreatedDialog({
    required String invitationToken,
    required double rentAmount,
  }) async {
    final invitationLink =
        'https://griho-crafttech.web.app${RouteNames.tenantInvitationPath(invitationToken)}';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return AlertDialog(
          title: const Text('Invitation Ready'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: GrihoColors.emerald.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Iconsax.tick_circle,
                      size: 44,
                      color: GrihoColors.emerald,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'The tenancy invitation has been generated successfully. Share this link with the tenant to finalize their onboarding.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monthly Rent',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '৳ ${formatTenantAmount(rentAmount)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Invitation Link',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: SelectableText(
                    invitationLink,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GrihoSecondaryButton(
                  label: 'Copy Invitation Link',
                  icon: Iconsax.copy,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: invitationLink),
                    );
                    if (!dialogContext.mounted) {
                      return;
                    }
                    GrihoFeedback.showSuccess(
                      dialogContext,
                      'Invitation link copied to clipboard.',
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);
    final tenantState = ref.watch(tenantControllerProvider);
    final selectedPropertyId = _selectedProperty?.id;

    final unitsAsync = selectedPropertyId == null
        ? const AsyncValue<List<Unit>>.data([])
        : ref.watch(propertyUnitsProvider(selectedPropertyId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Add Tenant')),
      body: SafeArea(
        child: propertiesAsync.when(
          loading: () =>
              const GrihoLoadingView(message: 'Loading buildings...'),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GrihoStatusState(
                icon: Iconsax.warning_2,
                title: 'Unable to load properties',
                subtitle: 'Please check your connection and try again.',
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(currentOwnerPropertiesProvider),
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
                    title: 'No Properties Available',
                    subtitle:
                        'Register at least one property and configure unit spaces before assigning a tenant.',
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Iconsax.user_add,
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
                                  'Register New Resident',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Assign a tenant to a vacant unit and dispatch an official tenancy invitation.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    GrihoSectionCard(
                      title: '1. Allocation & Vacant Unit',
                      subtitle:
                          'Choose target building and available unit space',
                      icon: Iconsax.buildings_2,
                      children: [
                        GrihoPickerField<Property>(
                          label: 'Property Building',
                          hint: 'Choose a building',
                          sheetTitle: 'Select Property Building',
                          searchHint: 'Search by building name or code...',
                          icon: Iconsax.buildings_2,
                          items: properties,
                          value: _selectedProperty,
                          itemTitle: (p) => p.name,
                          itemSubtitle: (p) => p.propertyCode.trim().isNotEmpty
                              ? 'Code: ${p.propertyCode}'
                              : null,
                          onChanged: (property) {
                            setState(() {
                              _selectedProperty = property;
                              _selectedUnit = null;
                            });
                          },
                          validator: (_) => _selectedProperty == null
                              ? 'Please select a property.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        unitsAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (error, _) =>
                              Text('Unable to load units: $error'),
                          data: (units) {
                            if (_selectedProperty == null) {
                              return GrihoPickerField<Unit>(
                                label: 'Vacant Unit / Space',
                                hint: 'Select a building first',
                                icon: Iconsax.home_2,
                                items: const [],
                                value: null,
                                enabled: false,
                                itemTitle: (u) => 'Unit ${u.unitNumber}',
                                onChanged: (_) {},
                              );
                            }

                            if (units.isEmpty) {
                              return GrihoPickerField<Unit>(
                                label: 'Vacant Unit / Space',
                                hint:
                                    'No units configured in this property yet',
                                icon: Iconsax.home_2,
                                items: const [],
                                value: null,
                                enabled: false,
                                itemTitle: (u) => 'Unit ${u.unitNumber}',
                                onChanged: (_) {},
                              );
                            }

                            final vacantUnits = units
                                .where((u) => u.status == UnitStatus.available)
                                .toList();
                            final occupiedCount =
                                units.length - vacantUnits.length;

                            if (vacantUnits.isEmpty) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: GrihoColors.warning.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: GrihoColors.warning.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Iconsax.home_2,
                                      color: GrihoColors.warning,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'All ${units.length} unit(s) in this building are currently occupied.',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final safeSelectedUnit =
                                (_selectedUnit != null &&
                                    vacantUnits.any(
                                      (u) => u.id == _selectedUnit!.id,
                                    ))
                                ? _selectedUnit
                                : null;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GrihoPickerField<Unit>(
                                  key: ValueKey(_selectedProperty?.id),
                                  label: 'Vacant Unit / Space',
                                  hint: 'Choose a vacant unit',
                                  sheetTitle: 'Select Vacant Unit',
                                  searchHint: 'Search by unit or floor...',
                                  icon: Iconsax.home_2,
                                  items: vacantUnits,
                                  value: safeSelectedUnit,
                                  itemTitle: (u) => 'Unit ${u.unitNumber}',
                                  itemSubtitle: (u) {
                                    final custom = u.name?.trim() ?? '';
                                    return custom.isNotEmpty
                                        ? 'Floor ${u.floorNumber} • $custom • Vacant'
                                        : 'Floor ${u.floorNumber} • Vacant';
                                  },
                                  onChanged: (unit) {
                                    setState(() => _selectedUnit = unit);
                                  },
                                  validator: (_) => safeSelectedUnit == null
                                      ? 'Please select a vacant unit.'
                                      : null,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Iconsax.tick_circle,
                                      size: 14,
                                      color: GrihoColors.emerald,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${vacantUnits.length} vacant unit(s) available'
                                        '${occupiedCount > 0 ? " • $occupiedCount occupied hidden" : ""}',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    GrihoSectionCard(
                      title: '2. Griho Account Lookup',
                      subtitle: 'Find existing members by Griho ID or phone',
                      icon: Iconsax.search_normal_1,
                      children: [
                        SegmentedButton<_TenantSearchType>(
                          segments: const [
                            ButtonSegment(
                              value: _TenantSearchType.grihoId,
                              label: Text('Griho ID'),
                              icon: Icon(Iconsax.personalcard, size: 17),
                            ),
                            ButtonSegment(
                              value: _TenantSearchType.phone,
                              label: Text('Phone'),
                              icon: Icon(Iconsax.call, size: 17),
                            ),
                          ],
                          selected: {_searchType},
                          onSelectionChanged: (selection) =>
                              _changeSearchType(selection.first),
                        ),
                        const SizedBox(height: 14),
                        if (_searchType == _TenantSearchType.grihoId)
                          TextField(
                            controller: _searchController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Griho Public ID',
                              hintText: 'e.g. GR-98213',
                              prefixIcon: const Icon(
                                Iconsax.finger_scan,
                                color: GrihoColors.emerald,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                tooltip: 'Search',
                                icon: _isSearching
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Iconsax.search_normal_1,
                                        size: 19,
                                      ),
                                onPressed: _isSearching
                                    ? null
                                    : _searchRegisteredUser,
                              ),
                            ),
                            onChanged: _onGrihoIdChanged,
                            onSubmitted: (_) => _searchRegisteredUser(),
                          ),
                        if (_searchType == _TenantSearchType.phone) ...[
                          GrihoPhoneField(
                            controller: _searchPhoneController,
                            label: 'Registered Phone Number',
                            onCompleteNumberChanged: _onSearchPhoneChanged,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: _isSearching
                                  ? null
                                  : _searchRegisteredUser,
                              icon: _isSearching
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Iconsax.search_normal_1,
                                      size: 17,
                                    ),
                              label: const Text('Search Member'),
                            ),
                          ),
                        ],
                        if (_searchError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _searchError!,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (!_isSearching && _searchResult != null) ...[
                          const SizedBox(height: 12),
                          _TenantSearchResultCard(
                            result: _searchResult!,
                            onUnlink: _clearSearchResult,
                          ),
                        ],
                        if (!_isSearching &&
                            _hasSearched &&
                            _searchResult == null &&
                            _searchError == null) ...[
                          const SizedBox(height: 12),
                          const _UserNotFoundView(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 18),
                    GrihoSectionCard(
                      title: '3. Personal Information',
                      subtitle: 'Contact and identification details',
                      icon: Iconsax.user,
                      children: [
                        GrihoPhoneField(
                          controller: _tenantPhoneController,
                          label: 'Tenant Phone Number',
                          hint: 'Enter phone number',
                          onCompleteNumberChanged: _onPhoneChanged,
                        ),
                        const SizedBox(height: 12),
                        GrihoTextField(
                          controller: _nameController,
                          label: 'Full Legal Name',
                          hint: 'Enter tenant name',
                          prefixIcon: Iconsax.user,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          validator: GrihoValidators.name,
                        ),
                        const SizedBox(height: 16),
                        GrihoTextField(
                          controller: _emailController,
                          label: 'Email Address (Optional)',
                          hint: 'e.g. resident@example.com',
                          prefixIcon: Iconsax.sms,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: GrihoValidators.optionalEmail,
                        ),
                        const SizedBox(height: 16),
                        GrihoTextField(
                          controller: _nidController,
                          label: 'National ID / NID (Optional)',
                          hint: 'Enter national identity number',
                          prefixIcon: Iconsax.card,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          maxLength: 17,
                          counterText: '',
                          validator: GrihoValidators.optionalNid,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    GrihoPrimaryButton(
                      label: tenantState.isLoading
                          ? 'Registering Tenant...'
                          : _isCreatingInvitation
                          ? 'Creating Invitation...'
                          : _createdTenant != null
                          ? 'Retry Invitation'
                          : 'Add Tenant & Prepare Invitation',
                      icon: _createdTenant != null
                          ? Iconsax.refresh
                          : Iconsax.user_add,
                      isLoading: tenantState.isLoading || _isCreatingInvitation,
                      onPressed: _createTenant,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InvitationConfirmationDialog extends StatefulWidget {
  final Tenant tenant;
  final String? initialEmail;
  final String? initialGrihoId;

  const _InvitationConfirmationDialog({
    required this.tenant,
    this.initialEmail,
    this.initialGrihoId,
  });

  @override
  State<_InvitationConfirmationDialog> createState() =>
      _InvitationConfirmationDialogState();
}

class _InvitationConfirmationDialogState
    extends State<_InvitationConfirmationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _rentController = TextEditingController();
  final _emailController = TextEditingController();
  final _grihoIdController = TextEditingController();

  _InviteMethod _selectedMethod = _InviteMethod.phone;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail?.trim() ?? '';
    _grihoIdController.text = widget.initialGrihoId?.trim().toUpperCase() ?? '';
  }

  @override
  void dispose() {
    _rentController.dispose();
    _emailController.dispose();
    _grihoIdController.dispose();
    super.dispose();
  }

  String? _validateGrihoId(String? value) {
    final grihoId = value?.trim() ?? '';
    if (grihoId.isEmpty) {
      return 'Please enter the recipient Griho ID.';
    }
    if (!RegExp(
      r'^[A-Z0-9][A-Z0-9_-]{2,39}$',
    ).hasMatch(grihoId.toUpperCase())) {
      return 'Please enter a valid Griho ID.';
    }
    return null;
  }

  void _submit() {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final rentAmount = double.tryParse(_rentController.text.trim());
    if (rentAmount == null || !rentAmount.isFinite || rentAmount <= 0) {
      return;
    }

    final choice = _InviteChoice(
      method: _selectedMethod,
      rentAmount: rentAmount,
      email: _selectedMethod == _InviteMethod.email
          ? _emailController.text.trim().toLowerCase()
          : null,
      grihoId: _selectedMethod == _InviteMethod.grihoId
          ? _grihoIdController.text.trim().toUpperCase()
          : null,
    );

    setState(() => _isSubmitting = true);
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Send Tenant Invitation'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose how to identify the recipient for ${widget.tenant.name}.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<_InviteMethod>(
                segments: const [
                  ButtonSegment(
                    value: _InviteMethod.phone,
                    label: Text('Phone'),
                    icon: Icon(Iconsax.call, size: 16),
                  ),
                  ButtonSegment(
                    value: _InviteMethod.email,
                    label: Text('Email'),
                    icon: Icon(Iconsax.sms, size: 16),
                  ),
                  ButtonSegment(
                    value: _InviteMethod.grihoId,
                    label: Text('ID'),
                    icon: Icon(Iconsax.personalcard, size: 16),
                  ),
                ],
                selected: {_selectedMethod},
                onSelectionChanged: (selection) =>
                    setState(() => _selectedMethod = selection.first),
              ),
              const SizedBox(height: 16),
              if (_selectedMethod == _InviteMethod.phone)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.call, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.tenant.phone,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_selectedMethod == _InviteMethod.email)
                GrihoTextField(
                  controller: _emailController,
                  label: 'Recipient Email',
                  hint: 'tenant@example.com',
                  prefixIcon: Iconsax.sms,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: GrihoValidators.email,
                ),
              if (_selectedMethod == _InviteMethod.grihoId)
                GrihoTextField(
                  controller: _grihoIdController,
                  label: 'Recipient Griho ID',
                  hint: 'e.g. GRI-12345',
                  prefixIcon: Iconsax.personalcard,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.next,
                  validator: _validateGrihoId,
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rentController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Initial Monthly Rent',
                  prefixText: '৳ ',
                ),
                validator: (value) {
                  final amount = double.tryParse(value?.trim() ?? '');
                  if (amount == null || !amount.isFinite || amount <= 0) {
                    return 'Enter a valid rent amount.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Not Now'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: const Text('Create Invitation'),
        ),
      ],
    );
  }
}

class _TenantSearchResultCard extends StatelessWidget {
  final TenantSearchResult result;
  final VoidCallback onUnlink;

  const _TenantSearchResultCard({required this.result, required this.onUnlink});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GrihoColors.emerald.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GrihoColors.emerald.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: GrihoColors.emerald.withValues(alpha: 0.2),
            child: const Icon(
              Iconsax.verify,
              color: GrihoColors.emerald,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        result.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: GrihoColors.emerald,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Verified Member',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Griho ID: ${result.publicId} • ${result.phone}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Unlink',
            icon: const Icon(Iconsax.close_circle, size: 19),
            onPressed: onUnlink,
          ),
        ],
      ),
    );
  }
}

class _UserNotFoundView extends StatelessWidget {
  const _UserNotFoundView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.info_circle, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No registered Griho user was found with these credentials. You can enter the tenant details manually below.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
