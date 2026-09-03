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

class AddTenantScreen extends ConsumerStatefulWidget {
  const AddTenantScreen({super.key});

  @override
  ConsumerState<AddTenantScreen> createState() => _AddTenantScreenState();
}

class _AddTenantScreenState extends ConsumerState<AddTenantScreen> {
  final _formKey = GlobalKey<FormState>();

  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nidController = TextEditingController();

  Property? _selectedProperty;
  Unit? _selectedUnit;

  TenantSearchResult? _searchResult;

  bool _isSearching = false;
  bool _hasSearched = false;

  String? _searchError;

  String _phoneNumber = '';

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _nidController.dispose();

    super.dispose();
  }

  // ================================================================
  // PHONE
  // ================================================================

  String? _getValidatedPhone() {
    final value = _phoneNumber.trim();

    if (!PhoneNumberUtils.isValid(value)) {
      return null;
    }

    return PhoneNumberUtils.normalize(value);
  }

  // ================================================================
  // SEARCH REGISTERED GRIHO USER
  //
  // Search can be done by:
  // - Griho ID
  // - Phone number
  // ================================================================

  Future<void> _searchRegisteredUser() async {
    final search = _searchController.text.trim();

    if (search.isEmpty) {
      setState(() {
        _hasSearched = false;
        _searchResult = null;
        _searchError = 'Please enter a Griho ID or phone number.';
      });

      return;
    }

    String searchValue = search;

    // If the input looks like a phone number, normalize it before search.
    if (search.startsWith('+') || RegExp(r'^[0-9]').hasMatch(search)) {
      if (PhoneNumberUtils.isValid(search)) {
        searchValue = PhoneNumberUtils.normalize(search);
      }
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchResult = null;
      _searchError = null;
    });

    try {
      final result = await ref
          .read(searchRegisteredTenantProvider)
          .call(searchValue);

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
        _searchError = 'Unable to search this Griho ID or phone number.';
      });
    }
  }

  // ================================================================
  // FILL FROM SEARCH RESULT
  // ================================================================

  void _fillFromSearchResult(TenantSearchResult result) {
    final name = result.name.trim();

    if (name.isNotEmpty) {
      _nameController.text = name;
    }

    final email = result.email?.trim();

    if (email != null && email.isNotEmpty) {
      _emailController.text = email;
    }

    final phone = result.phone.trim();

    if (phone.isNotEmpty && PhoneNumberUtils.isValid(phone)) {
      _phoneNumber = PhoneNumberUtils.normalize(phone);
    }
  }

  // ================================================================
  // SEARCH CHANGED
  // ================================================================

  void _onSearchChanged(String value) {
    if (!_hasSearched &&
        _searchResult == null &&
        _searchError == null) {
      return;
    }

    setState(() {
      _hasSearched = false;
      _searchResult = null;
      _searchError = null;
    });
  }

  // ================================================================
  // PHONE CHANGED
  // ================================================================

  void _onPhoneChanged(String value) {
    _phoneNumber = value;
  }

  // ================================================================
  // CREATE TENANT
  // ================================================================

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
          content: Text(
            'Please enter a valid international phone number.',
          ),
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
          content: Text(
            state.error?.toString() ?? 'Unable to create tenant.',
          ),
        ),
      );

      return;
    }

    final sendInvitation = await _showInvitationConfirmation(
      tenant: tenant,
    );

    if (!mounted) {
      return;
    }

    if (sendInvitation != true) {
      Navigator.of(context).pop(tenant);
      return;
    }

    await _createInvitation(tenant: tenant);
  }

  // ================================================================
  // INVITATION CONFIRMATION
  // ================================================================

  Future<bool?> _showInvitationConfirmation({
    required Tenant tenant,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Send Tenant Invitation?'),
          content: Text(
            'Tenant "${tenant.name}" has been added successfully.\n\n'
                'Would you like to create an invitation for '
                '${tenant.phone} so the tenant can register and link '
                'their Griho account?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Not Now'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Send Invitation'),
            ),
          ],
        );
      },
    );
  }

  // ================================================================
  // CREATE INVITATION
  // ================================================================

  Future<void> _createInvitation({
    required Tenant tenant,
  }) async {
    try {
      final invitation = await ref.read(createTenantInvitationProvider)(
        tenantId: tenant.id,
        propertyId: tenant.propertyId,
        unitId: tenant.unitId,
        phone: tenant.phone,
      );

      if (!mounted) {
        return;
      }

      await _showInvitationCreatedDialog(
        invitationId: invitation.id,
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
        ),
      );

      Navigator.of(context).pop(tenant);
    }
  }

  // ================================================================
  // INVITATION CREATED DIALOG
  // ================================================================

  Future<void> _showInvitationCreatedDialog({
    required String invitationId,
  }) async {
    final invitationLink = _buildInvitationLink(
      invitationId: invitationId,
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Invitation Created'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'The tenant invitation has been created successfully.',
                ),
                const SizedBox(height: 20),
                const Text(
                  'Invitation Link',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(invitationLink),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: invitationLink),
                      );

                      if (!dialogContext.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(
                          content: Text('Invitation link copied.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Link'),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  // ================================================================
  // INVITATION LINK
  // ================================================================

  String _buildInvitationLink({
    required String invitationId,
  }) {
    const hostingDomain = 'griho-crafttech.web.app';

    return 'https://$hostingDomain/i/'
        '${Uri.encodeComponent(invitationId)}';
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final propertiesAsync = ref.watch(
      currentOwnerPropertiesProvider,
    );

    final tenantState = ref.watch(
      tenantControllerProvider,
    );

    final selectedPropertyId = _selectedProperty?.id;

    final unitsAsync = selectedPropertyId == null
        ? const AsyncValue<List<Unit>>.data([])
        : ref.watch(
      propertyUnitsProvider(selectedPropertyId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Tenant'),
      ),
      body: SafeArea(
        child: propertiesAsync.when(
          loading: () {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
          error: (error, stackTrace) {
            return _ErrorView(
              message: 'Unable to load your properties.',
              onRetry: () {
                ref.invalidate(
                  currentOwnerPropertiesProvider,
                );
              },
            );
          },
          data: (properties) {
            if (properties.isEmpty) {
              return const _NoPropertyView();
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tenant Information',
                      style: Theme
                          .of(context)
                          .textTheme
                          .headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select a property and unit, then search for the tenant or enter the information manually.',
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodyMedium,
                    ),
                    const SizedBox(height: 32),

                    // ==================================================
                    // PROPERTY
                    // ==================================================

                    DropdownButtonFormField<Property>(
                      initialValue: _selectedProperty,
                      decoration: const InputDecoration(
                        labelText: 'Property',
                        border: OutlineInputBorder(),
                      ),
                      items: properties.map((property) {
                        return DropdownMenuItem<Property>(
                          value: property,
                          child: Text(
                            property.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (property) {
                        setState(() {
                          _selectedProperty = property;
                          _selectedUnit = null;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a property.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // UNIT
                    // ==================================================

                    unitsAsync.when(
                      loading: () {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      error: (error, stackTrace) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Unable to load units.',
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                final property = _selectedProperty;

                                if (property == null) {
                                  return;
                                }

                                ref.invalidate(
                                  propertyUnitsProvider(property.id),
                                );
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        );
                      },
                      data: (units) {
                        if (units.isEmpty) {
                          return const Text(
                            'No units are available in this property.',
                          );
                        }

                        return DropdownButtonFormField<Unit>(
                          initialValue: _selectedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                          ),
                          items: units.map((unit) {
                            return DropdownMenuItem<Unit>(
                              value: unit,
                              child: Text(
                                '${unit.unitNumber} — Floor ${unit
                                    .floorNumber}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (unit) {
                            setState(() {
                              _selectedUnit = unit;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a unit.';
                            }

                            return null;
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // ==================================================
                    // SEARCH GRIHO USER
                    // ==================================================

                    Text(
                      'Find Existing Griho User',
                      style: Theme
                          .of(context)
                          .textTheme
                          .titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Search using Griho ID or phone number.',
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodySmall,
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: 'Griho ID or Phone Number',
                        hintText: 'Enter Griho ID or phone number',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                          onPressed: () {
                            _searchController.clear();

                            setState(() {
                              _hasSearched = false;
                              _searchResult = null;
                              _searchError = null;
                            });
                          },
                          icon: const Icon(Icons.clear),
                        ),
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: (_) {
                        _searchRegisteredUser();
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
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.search),
                        label: const Text('Search'),
                      ),
                    ),

                    if (_searchError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          _searchError!,
                          style: TextStyle(
                            color: Theme
                                .of(context)
                                .colorScheme
                                .error,
                          ),
                        ),
                      ),

                    if (!_isSearching && _searchResult != null)
                      _TenantSearchResultCard(
                        result: _searchResult!,
                      ),

                    if (!_isSearching &&
                        _hasSearched &&
                        _searchResult == null &&
                        _searchError == null)
                      const _UserNotFoundView(),

                    const SizedBox(height: 28),

                    // ==================================================
                    // TENANT PHONE
                    // ==================================================

                    IntlPhoneField(
                      initialCountryCode: 'US',
                      decoration: const InputDecoration(
                        labelText: 'Tenant Phone Number',
                        hintText: 'Select country and enter phone number',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: (phone) {
                        _onPhoneChanged(phone.completeNumber);
                      },
                      validator: (phone) {
                        if (phone == null ||
                            phone.completeNumber
                                .trim()
                                .isEmpty) {
                          return 'Please enter phone number.';
                        }

                        if (!PhoneNumberUtils.isValid(
                          phone.completeNumber,
                        )) {
                          return 'Please enter a valid international phone number.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // NAME
                    // ==================================================

                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Tenant Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value
                            ?.trim()
                            .isEmpty ?? true) {
                          return 'Please enter tenant name.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // EMAIL
                    // ==================================================

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Optional',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // NID
                    // ==================================================

                    TextFormField(
                      controller: _nidController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'NID Number',
                        hintText: 'Optional',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ==================================================
                    // ADD TENANT
                    // ==================================================

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: tenantState.isLoading
                            ? null
                            : _createTenant,
                        child: tenantState.isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Text('Add Tenant'),
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
}

// ==================================================================
// TENANT SEARCH RESULT CARD
// ==================================================================

class _TenantSearchResultCard extends StatelessWidget {
  final TenantSearchResult result;

  const _TenantSearchResultCard({
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final isExistingTenant = result.isExistingTenant;

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              child: Icon(
                isExistingTenant
                    ? Icons.person
                    : Icons.person_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isExistingTenant
                        ? 'Existing tenant found'
                        : 'Registered Griho user found',
                    style: Theme
                        .of(context)
                        .textTheme
                        .labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.name,
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Griho ID: ${result.publicId}',
                    style: Theme
                        .of(context)
                        .textTheme
                        .bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.phone,
                    style: Theme
                        .of(context)
                        .textTheme
                        .bodySmall,
                  ),
                  if (result.email != null &&
                      result.email!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        result.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    isExistingTenant
                        ? 'This Griho user is already registered as a tenant.'
                        : 'This Griho user is registered but has no tenant record yet.',
                    style: Theme
                        .of(context)
                        .textTheme
                        .bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// NOT FOUND
// ==================================================================

class _UserNotFoundView extends StatelessWidget {
  const _UserNotFoundView();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.only(top: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No registered Griho user was found. You can enter the tenant information manually.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// NO PROPERTY
// ==================================================================

class _NoPropertyView extends StatelessWidget {
  const _NoPropertyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'You need to add a property before adding a tenant.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ==================================================================
// ERROR
// ==================================================================

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}