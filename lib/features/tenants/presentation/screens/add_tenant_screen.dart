import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

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

enum _TenantSearchType { grihoId, phone }

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
      final TenantSearchResult? result;

      if (_searchType == _TenantSearchType.grihoId) {
        result = await searchUseCase.byPublicId(searchValue);
      } else {
        result = await searchUseCase.byPhone(searchValue);
      }

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
    } catch (error) {
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
      // Auto-populate local phone number digits
      final digitsOnly = cleanPhone.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length >= 10) {
        _tenantPhoneController.text =
            digitsOnly.substring(digitsOnly.length - 10);
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
    });
  }

  void _onPhoneChanged(String value) {
    final cleanCurrent = PhoneNumberUtils.clean(value);
    if (_searchResult != null) {
      final cleanSearched = PhoneNumberUtils.clean(_searchResult!.phone);
      if (cleanSearched != cleanCurrent) {
        setState(() {
          _searchResult = null;
        });
      }
    }
    _phoneNumber = cleanCurrent;
  }

  Future<void> _createTenant() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final property = _selectedProperty;
    final unit = _selectedUnit;
    if (property == null || unit == null) {
      return;
    }

    final phone = _getValidatedPhone();
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid international phone number.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final request = CreateTenantRequest(
      userId: _searchResult?.userId,
      propertyId: property.id,
      unitId: unit.id,
      name: _nameController.text.trim(),
      phone: phone,
      email: _emailController.text
          .trim()
          .isEmpty
          ? null
          : _emailController.text.trim(),
      nidNumber: _nidController.text
          .trim()
          .isEmpty
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error?.toString() ?? 'Unable to create tenant.'),
          backgroundColor: Theme
              .of(context)
              .colorScheme
              .error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final invitationData = await _showInvitationConfirmation(tenant: tenant);
    if (!mounted) {
      return;
    }

    if (invitationData == null) {
      Navigator.of(context).pop(tenant);
      return;
    }

    await _createInvitation(tenant: tenant, rentAmount: invitationData);
  }

  Future<double?> _showInvitationConfirmation({required Tenant tenant}) {
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _InvitationConfirmationDialog(tenant: tenant),
    );
  }

  Future<void> _createInvitation({
    required Tenant tenant,
    required double rentAmount,
  }) async {
    try {
      final invitation = await ref.read(createTenantInvitationProvider)(
        tenantId: tenant.id,
        propertyId: tenant.propertyId,
        unitId: tenant.unitId,
        phone: tenant.phone,
        rentAmount: rentAmount,
      );

      if (!mounted) {
        return;
      }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Theme
              .of(context)
              .colorScheme
              .error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(tenant);
    }
  }

  Future<void> _showInvitationCreatedDialog({
    required String invitationToken,
    required double rentAmount,
  }) async {
    final invitationLink = _buildInvitationLink(
      invitationToken: invitationToken,
    );

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
                      color: Colors.green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 48,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'The tenancy invitation has been generated successfully. Share this link with the tenant to finalize their onboarding.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.5),
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
                        '৳ ${_formatAmount(rentAmount)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
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
                        fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                          ClipboardData(text: invitationLink));
                      if (!dialogContext.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Invitation link copied to clipboard.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copy Invitation Link'),
                  ),
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

  String _buildInvitationLink({required String invitationToken}) {
    const hostingDomain = 'griho-crafttech.web.app';
    return 'https://$hostingDomain/i/${Uri.encodeComponent(invitationToken)}';
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
      appBar: AppBar(
        title: const Text(
          'Add Tenant',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: propertiesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              _ErrorView(
                message: 'Unable to load your properties.',
                onRetry: () => ref.invalidate(currentOwnerPropertiesProvider),
              ),
          data: (properties) {
            if (properties.isEmpty) {
              return const _NoPropertyView();
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Overview Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: theme.colorScheme
                            .outlineVariant),
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
                              Icons.person_add_alt_1_rounded,
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

                    // Section 1: Target Building & Unit
                    _buildSectionCard(
                      title: '1. Allocation & Unit',
                      subtitle: 'Choose target building and unit space',
                      icon: Icons.apartment_rounded,
                      children: [
                        DropdownButtonFormField<Property>(
                          initialValue: _selectedProperty,
                          decoration: const InputDecoration(
                            labelText: 'Property Building',
                            prefixIcon: Icon(Icons.domain_rounded),
                            border: OutlineInputBorder(),
                          ),
                          items: properties
                              .map(
                                (p) =>
                                DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    '${p.name} (${p.propertyCode})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                          )
                              .toList(),
                          onChanged: (p) {
                            setState(() {
                              _selectedProperty = p;
                              _selectedUnit = null;
                            });
                          },
                          validator: (v) {
                            if (v == null) {
                              return 'Please select a property.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        unitsAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (err, stack) =>
                              Text('Unable to load units: $err'),
                          data: (units) {
                            if (_selectedProperty == null) {
                              return const InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Unit / Space',
                                  prefixIcon: Icon(
                                      Icons.door_front_door_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text('Select property first'),
                              );
                            }

                            if (units.isEmpty) {
                              return const InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Unit / Space',
                                  prefixIcon: Icon(
                                      Icons.door_front_door_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                child: Text(
                                    'No units available in this property'),
                              );
                            }

                            return DropdownButtonFormField<Unit>(
                              initialValue: _selectedUnit,
                              decoration: const InputDecoration(
                                labelText: 'Unit / Space',
                                prefixIcon: Icon(
                                    Icons.door_front_door_outlined),
                                border: OutlineInputBorder(),
                              ),
                              items: units
                                  .map(
                                    (u) =>
                                    DropdownMenuItem(
                                      value: u,
                                      child: Text(
                                        'Unit ${u.unitNumber} • Floor ${u
                                            .floorNumber}',
                                      ),
                                    ),
                              )
                                  .toList(),
                              onChanged: (u) {
                                setState(() {
                                  _selectedUnit = u;
                                });
                              },
                              validator: (v) {
                                if (v == null) {
                                  return 'Please select a unit.';
                                }
                                return null;
                              },
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Section 2: Griho Lookup (Optional Fast-Track)
                    _buildSectionCard(
                      title: '2. Griho Account Lookup',
                      subtitle: 'Find existing members by Griho ID or phone',
                      icon: Icons.person_search_rounded,
                      children: [
                        SegmentedButton<_TenantSearchType>(
                          segments: const [
                            ButtonSegment(
                              value: _TenantSearchType.grihoId,
                              label: Text('Griho ID'),
                              icon: Icon(Icons.badge_outlined),
                            ),
                            ButtonSegment(
                              value: _TenantSearchType.phone,
                              label: Text('Phone'),
                              icon: Icon(Icons.phone_outlined),
                            ),
                          ],
                          selected: {_searchType},
                          onSelectionChanged: (s) => _changeSearchType(s.first),
                        ),
                        const SizedBox(height: 14),
                        if (_searchType == _TenantSearchType.grihoId)
                          TextField(
                            controller: _searchController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Griho Public ID',
                              hintText: 'e.g. GR-98213',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.fingerprint_rounded),
                              suffixIcon: IconButton(
                                tooltip: 'Search',
                                icon: _isSearching
                                    ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                                    : const Icon(Icons.search_rounded),
                                onPressed: _isSearching
                                    ? null
                                    : _searchRegisteredUser,
                              ),
                            ),
                            onChanged: _onGrihoIdChanged,
                            onSubmitted: (_) => _searchRegisteredUser(),
                          ),
                        if (_searchType == _TenantSearchType.phone) ...[
                          IntlPhoneField(
                            controller: _searchPhoneController,
                            initialCountryCode: 'BD',
                            decoration: const InputDecoration(
                              labelText: 'Registered Phone Number',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (phone) {
                              _onSearchPhoneChanged(phone.completeNumber);
                            },
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
                                    strokeWidth: 2),
                              )
                                  : const Icon(Icons.search_rounded, size: 18),
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

                    // Section 3: Personal & Contact Credentials
                    _buildSectionCard(
                      title: '3. Personal Information',
                      subtitle: 'Contact and identification details',
                      icon: Icons.contact_page_outlined,
                      children: [
                        IntlPhoneField(
                          controller: _tenantPhoneController,
                          initialCountryCode: 'BD',
                          decoration: const InputDecoration(
                            labelText: 'Tenant Phone Number',
                            hintText: 'Enter phone number',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (phone) =>
                              _onPhoneChanged(phone.completeNumber),
                          validator: (phone) {
                            if (phone == null || phone.number
                                .trim()
                                .isEmpty) {
                              return 'Please enter phone number.';
                            }
                            if (!PhoneNumberUtils.isValid(
                                phone.completeNumber)) {
                              return 'Please enter a valid international number.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Full Legal Name',
                            hintText: 'Enter tenant name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v
                                .trim()
                                .isEmpty) {
                              return 'Please enter tenant full name.';
                            }
                            if (v
                                .trim()
                                .length < 2) {
                              return 'Name must be at least 2 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email Address (Optional)',
                            hintText: 'e.g. resident@example.com',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nidController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'National ID / NID (Optional)',
                            hintText: 'Enter national identity number',
                            prefixIcon: Icon(Icons.badge_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: tenantState.isLoading ? null : _createTenant,
                        icon: tenantState.isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(Icons.person_add_rounded),
                        label: Text(
                          tenantState.isLoading
                              ? 'Registering Tenant...'
                              : 'Add Tenant & Prepare Invitation',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
}

// ============================================================================
// INVITATION CONFIRMATION MODAL
// ============================================================================

class _InvitationConfirmationDialog extends StatefulWidget {
  final Tenant tenant;

  const _InvitationConfirmationDialog({required this.tenant});

  @override
  State<_InvitationConfirmationDialog> createState() =>
      _InvitationConfirmationDialogState();
}

class _InvitationConfirmationDialogState
    extends State<_InvitationConfirmationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _rentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _rentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }
    final amount = double.tryParse(_rentController.text.trim());
    if (amount == null || amount <= 0) {
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Send Tenant Invitation'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specify initial recurring rent terms for ${widget.tenant.name}.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    widget.tenant.phone,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rentController,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Initial Monthly Rent',
                prefixText: '৳ ',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final amount = double.tryParse(v?.trim() ?? '');
                if (amount == null || amount <= 0) {
                  return 'Enter a valid rent amount.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Not Now'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white),
          )
              : const Text('Send Invitation'),
        ),
      ],
    );
  }
}

// ============================================================================
// SEARCH RESULT CARD (LINKED MEMBER)
// ============================================================================

class _TenantSearchResultCard extends StatelessWidget {
  final TenantSearchResult result;
  final VoidCallback onUnlink;

  const _TenantSearchResultCard({
    required this.result,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.green.shade100,
            child: Icon(
                Icons.verified_user_rounded, color: Colors.green.shade800),
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
                            fontWeight: FontWeight.w800, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
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
            icon: const Icon(Icons.close_rounded, size: 18),
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
          Icon(Icons.info_outline_rounded, size: 18,
              color: theme.colorScheme.primary),
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

class _NoPropertyView extends StatelessWidget {
  const _NoPropertyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.apartment_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No Properties Available',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You need to register at least one property and configure unit spaces before you can assign a tenant.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
              Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _formatAmount(double amount) {
  return amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
}
