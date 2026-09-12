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

enum _TenantSearchType {
  grihoId,
  phone,
}

class AddTenantScreen extends ConsumerStatefulWidget {
  const AddTenantScreen({
    super.key,
  });

  @override
  ConsumerState<AddTenantScreen> createState() =>
      _AddTenantScreenState();
}

class _AddTenantScreenState extends ConsumerState<AddTenantScreen> {
  final _formKey = GlobalKey<FormState>();

  // ==========================================================================
  // SEARCH CONTROLLERS
  // ==========================================================================

  final _searchController = TextEditingController();
  final _searchPhoneController = TextEditingController();

  // ==========================================================================
  // TENANT FORM CONTROLLERS
  // ==========================================================================

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nidController = TextEditingController();

  // ==========================================================================
  // PROPERTY / UNIT
  // ==========================================================================

  Property? _selectedProperty;
  Unit? _selectedUnit;

  // ==========================================================================
  // SEARCH
  // ==========================================================================

  _TenantSearchType _searchType = _TenantSearchType.grihoId;

  TenantSearchResult? _searchResult;

  bool _isSearching = false;
  bool _hasSearched = false;

  String? _searchError;

  String _searchPhoneNumber = '';

  // ==========================================================================
  // TENANT PHONE
  // ==========================================================================

  String _phoneNumber = '';

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _searchController.dispose();
    _searchPhoneController.dispose();

    _nameController.dispose();
    _emailController.dispose();
    _nidController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // VALIDATE TENANT PHONE
  // ==========================================================================

  String? _getValidatedPhone() {
    final value = _phoneNumber.trim();

    if (!PhoneNumberUtils.isValid(value)) {
      return null;
    }

    return PhoneNumberUtils.normalize(value);
  }

  // ==========================================================================
  // CHANGE SEARCH TYPE
  // ==========================================================================

  void _changeSearchType(_TenantSearchType type,) {
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

  // ==========================================================================
  // GRIHO ID SEARCH FIELD CHANGED
  // ==========================================================================

  void _onGrihoIdChanged(String value,) {
    if (!_hasSearched &&
        _searchResult == null &&
        _searchError == null) {
      return;
    }

    setState(() {
      _searchResult = null;
      _searchError = null;
      _hasSearched = false;
    });
  }

  // ==========================================================================
  // SEARCH PHONE CHANGED
  // ==========================================================================

  void _onSearchPhoneChanged(String value,) {
    _searchPhoneNumber = value;

    if (!_hasSearched &&
        _searchResult == null &&
        _searchError == null) {
      return;
    }

    setState(() {
      _searchResult = null;
      _searchError = null;
      _hasSearched = false;
    });
  }

  // ==========================================================================
  // SEARCH REGISTERED GRIHO USER
  // ==========================================================================

  Future<void> _searchRegisteredUser() async {
    String? searchValue;

    // ------------------------------------------------------------------------
    // GRIHO ID
    // ------------------------------------------------------------------------

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
    }

    // ------------------------------------------------------------------------
    // PHONE
    // ------------------------------------------------------------------------

    else {
      final value = _searchPhoneNumber.trim();

      if (value.isEmpty) {
        setState(() {
          _hasSearched = false;
          _searchResult = null;
          _searchError = 'Please enter a phone number.';
        });

        return;
      }

      if (!PhoneNumberUtils.isValid(value)) {
        setState(() {
          _hasSearched = false;
          _searchResult = null;
          _searchError =
          'Please enter a valid international phone number.';
        });

        return;
      }

      searchValue = PhoneNumberUtils.normalize(value);
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchResult = null;
      _searchError = null;
    });

    try {
      final searchUseCase = ref.read(
        searchRegisteredTenantProvider,
      );

      final TenantSearchResult? result;

      if (_searchType == _TenantSearchType.grihoId) {
        result = await searchUseCase.byPublicId(
          searchValue,
        );
      } else {
        result = await searchUseCase.byPhone(
          searchValue,
        );
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
      debugPrint(
        'Tenant search error: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSearching = false;
        _searchResult = null;
        _searchError =
        'Unable to search the registered Griho user.';
      });
    }
  }

  // ==========================================================================
  // FILL FORM FROM SEARCH RESULT
  // ==========================================================================

  void _fillFromSearchResult(TenantSearchResult result,) {
    final name = result.name.trim();

    if (name.isNotEmpty) {
      _nameController.text = name;
    }

    final email = result.email?.trim();

    if (email != null && email.isNotEmpty) {
      _emailController.text = email;
    }

    final phone = result.phone.trim();

    if (phone.isNotEmpty &&
        PhoneNumberUtils.isValid(phone)) {
      final normalizedPhone = PhoneNumberUtils.normalize(
        phone,
      );

      _phoneNumber = normalizedPhone;
    }
  }

  // ==========================================================================
  // TENANT PHONE CHANGED
  // ==========================================================================

  void _onPhoneChanged(String value,) {
    final normalizedValue = value.trim();

    // ------------------------------------------------------------------------
    // If the owner searched for one registered account and then changes the
    // tenant phone manually, the previously found userId must not be reused.
    // ------------------------------------------------------------------------

    if (_searchResult != null) {
      final searchedPhone = _searchResult!.phone.trim();

      final searchedPhoneValid =
          searchedPhone.isNotEmpty &&
              PhoneNumberUtils.isValid(
                searchedPhone,
              );

      final currentPhoneValid =
          normalizedValue.isNotEmpty &&
              PhoneNumberUtils.isValid(
                normalizedValue,
              );

      if (!searchedPhoneValid ||
          !currentPhoneValid ||
          PhoneNumberUtils.normalize(
            searchedPhone,
          ) !=
              PhoneNumberUtils.normalize(
                normalizedValue,
              )) {
        setState(() {
          _searchResult = null;
        });
      }
    }

    _phoneNumber = value;
  }

  // ==========================================================================
  // CREATE TENANT
  // ==========================================================================

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

    // ------------------------------------------------------------------------
    // CREATE TENANT REQUEST
    // ------------------------------------------------------------------------

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
        .read(
      tenantControllerProvider.notifier,
    )
        .createTenant(request);

    if (!mounted) {
      return;
    }

    if (tenant == null) {
      final state = ref.read(
        tenantControllerProvider,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.error?.toString() ??
                'Unable to create tenant.',
          ),
        ),
      );

      return;
    }

    // ------------------------------------------------------------------------
    // INVITATION CONFIRMATION + RENT
    // ------------------------------------------------------------------------

    final invitationData =
    await _showInvitationConfirmation(
      tenant: tenant,
    );

    if (!mounted) {
      return;
    }

    // Owner chose not to send invitation.
    if (invitationData == null) {
      Navigator.of(context).pop(tenant);
      return;
    }

    await _createInvitation(
      tenant: tenant,
      rentAmount: invitationData,
    );
  }

  // ==========================================================================
  // INVITATION CONFIRMATION + INITIAL RENT
  // ==========================================================================

  Future<double?> _showInvitationConfirmation({
    required Tenant tenant,
  }) {
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _InvitationConfirmationDialog(
          tenant: tenant,
        );
      },
    );
  }

  // ==========================================================================
  // CREATE INVITATION
  // ==========================================================================

  Future<void> _createInvitation({
    required Tenant tenant,
    required double rentAmount,
  }) async {
    try {
      final invitation = await ref.read(
        createTenantInvitationProvider,
      )(
        tenantId: tenant.id,
        propertyId: tenant.propertyId,
        unitId: tenant.unitId,
        phone: tenant.phone,
        rentAmount: rentAmount,
      );

      if (!mounted) {
        return;
      }

      // ----------------------------------------------------------------------
      // IMPORTANT:
      // Use the public invitation token in the link.
      //
      // Never expose the internal Firestore invitation document ID.
      // ----------------------------------------------------------------------

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
          content: Text(
            error.toString(),
          ),
        ),
      );

      Navigator.of(context).pop(tenant);
    }
  }

  // ==========================================================================
  // INVITATION CREATED DIALOG
  // ==========================================================================

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
        return AlertDialog(
          title: const Text(
            'Invitation Created',
          ),
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
                Text(
                  'Initial Monthly Rent',
                  style: Theme
                      .of(context)
                      .textTheme
                      .labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '৳ ${_formatAmount(rentAmount)}',
                  style: Theme
                      .of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Invitation Link',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  invitationLink,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: invitationLink,
                        ),
                      );

                      if (!dialogContext.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Invitation link copied.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.copy,
                    ),
                    label: const Text(
                      'Copy Link',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child: const Text(
                'Done',
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================================
  // INVITATION LINK
  // ==========================================================================

  String _buildInvitationLink({
    required String invitationToken,
  }) {
    const hostingDomain = 'griho-crafttech.web.app';

    return 'https://$hostingDomain/i/'
        '${Uri.encodeComponent(invitationToken)}';
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

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
        ? const AsyncValue<List<Unit>>.data(
      [],
    )
        : ref.watch(
      propertyUnitsProvider(
        selectedPropertyId,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Tenant',
        ),
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
              message:
              'Unable to load your properties.',
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
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
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

                    // ========================================================
                    // PROPERTY
                    // ========================================================

                    DropdownButtonFormField<Property>(
                      initialValue: _selectedProperty,
                      decoration: const InputDecoration(
                        labelText: 'Property',
                        border: OutlineInputBorder(),
                      ),
                      items: properties.map(
                            (property) {
                          return DropdownMenuItem<Property>(
                            value: property,
                            child: Text(
                              property.name,
                              overflow:
                              TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ).toList(),
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

                    // ========================================================
                    // UNIT
                    // ========================================================

                    unitsAsync.when(
                      loading: () {
                        return const Padding(
                          padding:
                          EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                          child: Center(
                            child:
                            CircularProgressIndicator(),
                          ),
                        );
                      },
                      error: (error,
                          stackTrace,) {
                        return Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Unable to load units.',
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                final property =
                                    _selectedProperty;

                                if (property == null) {
                                  return;
                                }

                                ref.invalidate(
                                  propertyUnitsProvider(
                                    property.id,
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.refresh,
                              ),
                              label: const Text(
                                'Retry',
                              ),
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
                          decoration:
                          const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                          ),
                          items: units.map(
                                (unit) {
                              return DropdownMenuItem<Unit>(
                                value: unit,
                                child: Text(
                                  '${unit.unitNumber} — Floor ${unit
                                      .floorNumber}',
                                  overflow:
                                  TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ).toList(),
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

                    // ========================================================
                    // SEARCH REGISTERED GRIHO USER
                    // ========================================================

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

                    // ========================================================
                    // SEARCH TYPE
                    // ========================================================

                    SegmentedButton<_TenantSearchType>(
                      segments: const [
                        ButtonSegment<_TenantSearchType>(
                          value:
                          _TenantSearchType.grihoId,
                          label: Text('Griho ID'),
                          icon: Icon(
                            Icons.badge_outlined,
                          ),
                        ),
                        ButtonSegment<_TenantSearchType>(
                          value:
                          _TenantSearchType.phone,
                          label: Text('Phone'),
                          icon: Icon(
                            Icons.phone_outlined,
                          ),
                        ),
                      ],
                      selected: {
                        _searchType,
                      },
                      onSelectionChanged:
                          (selection) {
                        if (selection.isEmpty) {
                          return;
                        }

                        _changeSearchType(
                          selection.first,
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // ========================================================
                    // GRIHO ID SEARCH
                    // ========================================================

                    if (_searchType ==
                        _TenantSearchType.grihoId)
                      TextField(
                        controller: _searchController,
                        textInputAction:
                        TextInputAction.search,
                        textCapitalization:
                        TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Griho ID',
                          hintText: 'Enter Griho ID',
                          border:
                          const OutlineInputBorder(),
                          prefixIcon: const Icon(
                            Icons.badge_outlined,
                          ),
                          suffixIcon:
                          _searchController
                              .text
                              .isEmpty
                              ? null
                              : IconButton(
                            onPressed: () {
                              _searchController
                                  .clear();

                              setState(() {
                                _hasSearched =
                                false;
                                _searchResult =
                                null;
                                _searchError =
                                null;
                              });
                            },
                            icon: const Icon(
                              Icons.clear,
                            ),
                          ),
                        ),
                        onChanged:
                        _onGrihoIdChanged,
                        onSubmitted: (_) {
                          _searchRegisteredUser();
                        },
                      ),

                    // ========================================================
                    // PHONE SEARCH
                    // ========================================================

                    if (_searchType ==
                        _TenantSearchType.phone)
                      IntlPhoneField(
                        controller:
                        _searchPhoneController,
                        initialCountryCode: 'BD',
                        decoration:
                        const InputDecoration(
                          labelText: 'Phone Number',
                          hintText:
                          'Enter registered phone number',
                          border:
                          OutlineInputBorder(),
                        ),
                        textInputAction:
                        TextInputAction.search,
                        onChanged: (phone) {
                          _onSearchPhoneChanged(
                            phone.completeNumber,
                          );
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

                    const SizedBox(height: 8),

                    // ========================================================
                    // SEARCH BUTTON
                    // ========================================================

                    Align(
                      alignment:
                      Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _isSearching
                            ? null
                            : _searchRegisteredUser,
                        icon: _isSearching
                            ? const SizedBox(
                          height: 16,
                          width: 16,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(
                          Icons.search,
                        ),
                        label: const Text(
                          'Search',
                        ),
                      ),
                    ),

                    // ========================================================
                    // SEARCH ERROR
                    // ========================================================

                    if (_searchError != null)
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(
                          vertical: 8,
                        ),
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

                    // ========================================================
                    // SEARCH RESULT
                    // ========================================================

                    if (!_isSearching &&
                        _searchResult != null)
                      _TenantSearchResultCard(
                        result: _searchResult!,
                      ),

                    // ========================================================
                    // NOT FOUND
                    // ========================================================

                    if (!_isSearching &&
                        _hasSearched &&
                        _searchResult == null &&
                        _searchError == null)
                      const _UserNotFoundView(),

                    const SizedBox(height: 28),

                    // ========================================================
                    // TENANT PHONE
                    // ========================================================

                    IntlPhoneField(
                      initialCountryCode: 'BD',
                      decoration: const InputDecoration(
                        labelText:
                        'Tenant Phone Number',
                        hintText:
                        'Select country and enter phone number',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction:
                      TextInputAction.next,
                      onChanged: (phone) {
                        _onPhoneChanged(
                          phone.completeNumber,
                        );
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

                    // ========================================================
                    // NAME
                    // ========================================================

                    TextFormField(
                      controller: _nameController,
                      textCapitalization:
                      TextCapitalization.words,
                      textInputAction:
                      TextInputAction.next,
                      decoration:
                      const InputDecoration(
                        labelText: 'Tenant Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value
                            ?.trim()
                            .isEmpty ??
                            true) {
                          return 'Please enter tenant name.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ========================================================
                    // EMAIL
                    // ========================================================

                    TextFormField(
                      controller: _emailController,
                      keyboardType:
                      TextInputType.emailAddress,
                      textInputAction:
                      TextInputAction.next,
                      decoration:
                      const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Optional',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ========================================================
                    // NID
                    // ========================================================

                    TextFormField(
                      controller: _nidController,
                      keyboardType:
                      TextInputType.number,
                      textInputAction:
                      TextInputAction.done,
                      decoration:
                      const InputDecoration(
                        labelText: 'NID Number',
                        hintText: 'Optional',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ========================================================
                    // ADD TENANT
                    // ========================================================

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
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          'Add Tenant',
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
}

// ==========================================================================
// INVITATION CONFIRMATION DIALOG
// ==========================================================================
//
// IMPORTANT:
// This dialog owns its own TextEditingController.
// The controller is disposed only when this dialog widget is disposed.
//
// This fixes:
// "A TextEditingController was used after being disposed."
// ==========================================================================

class _InvitationConfirmationDialog extends StatefulWidget {
  final Tenant tenant;

  const _InvitationConfirmationDialog({
    required this.tenant,
  });

  @override
  State<_InvitationConfirmationDialog> createState() =>
      _InvitationConfirmationDialogState();
}

class _InvitationConfirmationDialogState
    extends State<_InvitationConfirmationDialog> {
  final _formKey = GlobalKey<FormState>();

  final _rentController =
  TextEditingController();

  bool _isSubmitting = false;

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _rentController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // SUBMIT
  // ==========================================================================

  void _submit() {
    if (_isSubmitting) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(
      _rentController.text.trim(),
    );

    if (amount == null ||
        !amount.isFinite ||
        amount <= 0) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    Navigator.of(context).pop(amount);
  }

  // ==========================================================================
  // CANCEL
  // ==========================================================================

  void _cancel() {
    if (_isSubmitting) {
      return;
    }

    Navigator.of(context).pop();
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final tenant = widget.tenant;

    return AlertDialog(
      title: const Text(
        'Send Tenant Invitation',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'Tenant: ${tenant.name}',
                style: Theme
                    .of(context)
                    .textTheme
                    .titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                tenant.phone,
                style: Theme
                    .of(context)
                    .textTheme
                    .bodyMedium,
              ),
              const SizedBox(height: 20),
              Text(
                'Set Monthly Rent',
                style: Theme
                    .of(context)
                    .textTheme
                    .titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'This amount will become the tenant\'s initial agreed monthly rent when the invitation is accepted.',
                style: Theme
                    .of(context)
                    .textTheme
                    .bodySmall,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _rentController,
                autofocus: true,
                keyboardType:
                const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(
                      r'^\d*\.?\d{0,2}',
                    ),
                  ),
                ],
                decoration:
                const InputDecoration(
                  labelText: 'Monthly Rent',
                  hintText: 'Enter monthly rent',
                  prefixText: '৳ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final text =
                      value?.trim() ?? '';

                  if (text.isEmpty) {
                    return 'Please enter monthly rent.';
                  }

                  final amount =
                  double.tryParse(text);

                  if (amount == null ||
                      !amount.isFinite ||
                      amount <= 0) {
                    return 'Enter a valid rent amount.';
                  }

                  return null;
                },
                onFieldSubmitted: (_) {
                  _submit();
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
          _isSubmitting ? null : _cancel,
          child: const Text(
            'Not Now',
          ),
        ),
        FilledButton(
          onPressed:
          _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
            width: 18,
            height: 18,
            child:
            CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
              : const Text(
            'Send Invitation',
          ),
        ),
      ],
    );
  }
}

// ==========================================================================
// TENANT SEARCH RESULT CARD
// ==========================================================================

class _TenantSearchResultCard extends StatelessWidget {
  final TenantSearchResult result;

  const _TenantSearchResultCard({
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final isExistingTenant =
        result.isExistingTenant;

    return Card(
      margin:
      const EdgeInsets.only(top: 8),
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
                crossAxisAlignment:
                CrossAxisAlignment.start,
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
                      result.email!
                          .trim()
                          .isNotEmpty)
                    Padding(
                      padding:
                      const EdgeInsets.only(
                        top: 4,
                      ),
                      child: Text(
                        result.email!,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
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

// ==========================================================================
// NOT FOUND
// ==========================================================================

class _UserNotFoundView extends StatelessWidget {
  const _UserNotFoundView();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin:
      EdgeInsets.only(top: 8),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
            ),
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

// ==========================================================================
// NO PROPERTY
// ==========================================================================

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

// ==========================================================================
// ERROR
// ==========================================================================

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
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================================================
// FORMAT AMOUNT
// ==========================================================================

String _formatAmount(double amount,) {
  if (amount ==
      amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }

  return amount.toStringAsFixed(2);
}