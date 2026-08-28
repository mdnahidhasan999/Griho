import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/user_profile_provider.dart';

import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';

import '../../../units/domain/entities/unit.dart';
import '../../../units/presentation/providers/property_units_provider.dart';

import '../../domain/entities/create_tenant_request.dart';
import '../../domain/entities/tenant.dart';

import '../controllers/tenant_controller.dart';
import '../providers/tenant_by_phone_provider.dart';
import '../providers/tenant_invitation_provider.dart';

class AddTenantScreen extends ConsumerStatefulWidget {
  const AddTenantScreen({super.key});

  @override
  ConsumerState<AddTenantScreen> createState() =>
      _AddTenantScreenState();
}

class _AddTenantScreenState extends ConsumerState<AddTenantScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _nidController = TextEditingController();

  Property? _selectedProperty;
  Unit? _selectedUnit;

  AppUser? _existingUser;
  Tenant? _existingTenant;

  bool _isSearching = false;
  bool _hasSearched = false;

  String? _searchError;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nidController.dispose();

    super.dispose();
  }

  // ================================================================
  // SEARCH PHONE
  // ================================================================

  Future<void> _searchPhone() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      setState(() {
        _hasSearched = false;
        _existingUser = null;
        _existingTenant = null;
        _searchError = 'Please enter a phone number.';
      });

      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _existingUser = null;
      _existingTenant = null;
      _searchError = null;
    });

    try {
      // ------------------------------------------------------------
      // SEARCH GRIHO USER
      // ------------------------------------------------------------

      final user = await ref.read(
        userByPhoneProvider(phone).future,
      );

      if (!mounted) {
        return;
      }

      if (user != null) {
        setState(() {
          _existingUser = user;
          _isSearching = false;
        });

        _fillFromUser(user);

        return;
      }

      // ------------------------------------------------------------
      // SEARCH EXISTING TENANT
      // ------------------------------------------------------------

      final tenant = await ref.read(
        tenantByPhoneProvider(phone).future,
      );

      if (!mounted) {
        return;
      }

      if (tenant != null) {
        setState(() {
          _existingTenant = tenant;
          _isSearching = false;
        });

        _fillFromTenant(tenant);

        return;
      }

      // ------------------------------------------------------------
      // NOTHING FOUND
      // ------------------------------------------------------------

      setState(() {
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSearching = false;
        _searchError = 'Unable to search this phone number.';
      });
    }
  }

  // ================================================================
  // FILL USER
  // ================================================================

  void _fillFromUser(AppUser user) {
    if (user.name
        .trim()
        .isNotEmpty) {
      _nameController.text = user.name;
    }

    final email = user.email?.trim();

    if (email != null && email.isNotEmpty) {
      _emailController.text = email;
    }
  }

  // ================================================================
  // FILL TENANT
  // ================================================================

  void _fillFromTenant(Tenant tenant) {
    if (tenant.name
        .trim()
        .isNotEmpty) {
      _nameController.text = tenant.name;
    }

    final email = tenant.email?.trim();

    if (email != null && email.isNotEmpty) {
      _emailController.text = email;
    }

    final nid = tenant.nidNumber?.trim();

    if (nid != null && nid.isNotEmpty) {
      _nidController.text = nid;
    }
  }

  // ================================================================
  // PHONE CHANGED
  // ================================================================

  void _onPhoneChanged(String value) {
    if (!_hasSearched &&
        _existingUser == null &&
        _existingTenant == null) {
      return;
    }

    setState(() {
      _hasSearched = false;
      _existingUser = null;
      _existingTenant = null;
      _searchError = null;
    });
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

    final phone = _phoneController.text.trim();

    final request = CreateTenantRequest(
      userId: _existingUser?.uid,
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
            state.error?.toString() ??
                'Unable to create tenant.',
          ),
        ),
      );

      return;
    }

    // ==========================================================
    // TENANT CREATED SUCCESSFULLY
    // ==========================================================

    final sendInvitation = await _showInvitationConfirmation(
      tenant: tenant,
    );

    if (!mounted) {
      return;
    }

    // ----------------------------------------------------------
    // USER CHOSE NO
    // ----------------------------------------------------------

    if (sendInvitation != true) {
      Navigator.of(context).pop(tenant);
      return;
    }

    // ----------------------------------------------------------
    // USER CHOSE YES
    // ----------------------------------------------------------

    await _createInvitation(
      tenant: tenant,
    );
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
          title: const Text(
            'Send Tenant Invitation?',
          ),
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
    final propertyId = tenant.propertyId;
    final unitId = tenant.unitId;

    try {
      final invitation = await ref.read(
        createTenantInvitationProvider,
      )(
        tenantId: tenant.id,
        propertyId: propertyId,
        unitId: unitId,
        phone: tenant.phone,
      );

      if (!mounted) {
        return;
      }

      await _showInvitationCreatedDialog(
        invitationId: invitation.id,
        token: invitation.token,
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

      // Tenant already exists.
      // Only invitation creation failed.
      Navigator.of(context).pop(tenant);
    }
  }

  // ================================================================
  // INVITATION CREATED DIALOG
  // ================================================================

  Future<void> _showInvitationCreatedDialog({
    required String invitationId,
    required String token,
  }) async {
    final invitationLink = _buildInvitationLink(
      invitationId: invitationId,
      token: token,
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
                const Icon(
                  Icons.check_circle_outline,
                  size: 52,
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
                Navigator.of(dialogContext).pop();
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

  // ================================================================
  // BUILD INVITATION LINK
  // ================================================================
  //
  // IMPORTANT:
  // তোমার current router query parameters ব্যবহার করছে:
  //
  // tenantId
  // invitationId
  //
  // তাই link এই format-এ হবে।
  //
  // ================================================================
  String _buildInvitationLink({
    required String invitationId,
    required String token,
  }) {
    return 'tenantId=${Uri.encodeComponent(_selectedProperty!.id)}'
        '&invitationId=${Uri.encodeComponent(invitationId)}'
        '&token=${Uri.encodeComponent(token)}';
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

    final selectedPropertyId =
        _selectedProperty?.id;

    final unitsAsync = selectedPropertyId == null
        ? const AsyncValue<List<Unit>>.data([])
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
                      'Select a property and unit, then enter the tenant information.',
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
                      initialValue:
                      _selectedProperty,
                      decoration:
                      const InputDecoration(
                        labelText: 'Property',
                        border:
                        OutlineInputBorder(),
                      ),
                      items: properties
                          .map(
                            (property) {
                          return DropdownMenuItem<
                              Property>(
                            value: property,
                            child: Text(
                              property.name,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                            ),
                          );
                        },
                      )
                          .toList(),
                      onChanged: (property) {
                        setState(() {
                          _selectedProperty =
                              property;
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
                      error:
                          (error, stackTrace) {
                        return Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            const Text(
                              'Unable to load units.',
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                final property =
                                    _selectedProperty;

                                if (property ==
                                    null) {
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

                        return DropdownButtonFormField<
                            Unit>(
                          initialValue:
                          _selectedUnit,
                          decoration:
                          const InputDecoration(
                            labelText: 'Unit',
                            border:
                            OutlineInputBorder(),
                          ),
                          items: units
                              .map(
                                (unit) {
                              return DropdownMenuItem<
                                  Unit>(
                                value: unit,
                                child: Text(
                                  '${unit.unitNumber} — Floor ${unit
                                      .floorNumber}',
                                  overflow:
                                  TextOverflow
                                      .ellipsis,
                                ),
                              );
                            },
                          )
                              .toList(),
                          onChanged: (unit) {
                            setState(() {
                              _selectedUnit =
                                  unit;
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
                    // PHONE
                    // ==================================================

                    TextFormField(
                      controller:
                      _phoneController,
                      keyboardType:
                      TextInputType.phone,
                      textInputAction:
                      TextInputAction.search,
                      decoration:
                      InputDecoration(
                        labelText: 'Phone',
                        hintText:
                        'e.g. 018XXXXXXXX',
                        border:
                        const OutlineInputBorder(),
                        suffixIcon:
                        _isSearching
                            ? const Padding(
                          padding:
                          EdgeInsets
                              .all(
                            12,
                          ),
                          child: SizedBox(
                            height: 20,
                            width: 20,
                            child:
                            CircularProgressIndicator(
                              strokeWidth:
                              2,
                            ),
                          ),
                        )
                            : IconButton(
                          tooltip:
                          'Search tenant',
                          onPressed:
                          _searchPhone,
                          icon:
                          const Icon(
                            Icons.search,
                          ),
                        ),
                      ),
                      onChanged:
                      _onPhoneChanged,
                      onFieldSubmitted: (_) =>
                          _searchPhone(),
                      validator: (value) {
                        if (value
                            ?.trim()
                            .isEmpty ??
                            true) {
                          return 'Please enter phone number.';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 8),

                    if (_searchError != null)
                      Padding(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          vertical: 8,
                        ),
                        child: Text(
                          _searchError!,
                          style: TextStyle(
                            color: Theme
                                .of(
                              context,
                            )
                                .colorScheme
                                .error,
                          ),
                        ),
                      ),

                    if (!_isSearching &&
                        _existingUser != null)
                      _ExistingUserCard(
                        user: _existingUser!,
                      ),

                    if (!_isSearching &&
                        _existingUser == null &&
                        _existingTenant != null)
                      _ExistingTenantCard(
                        tenant: _existingTenant!,
                      ),

                    if (!_isSearching &&
                        _hasSearched &&
                        _existingUser == null &&
                        _existingTenant == null &&
                        _searchError == null)
                      const _UserNotFoundView(),

                    const SizedBox(height: 20),

                    // ==================================================
                    // NAME
                    // ==================================================

                    TextFormField(
                      controller:
                      _nameController,
                      textCapitalization:
                      TextCapitalization
                          .words,
                      textInputAction:
                      TextInputAction.next,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'Tenant Name',
                        hintText:
                        'e.g. Rahim Uddin',
                        border:
                        OutlineInputBorder(),
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

                    // ==================================================
                    // EMAIL
                    // ==================================================

                    TextFormField(
                      controller:
                      _emailController,
                      keyboardType:
                      TextInputType
                          .emailAddress,
                      textInputAction:
                      TextInputAction.next,
                      decoration:
                      const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Optional',
                        border:
                        OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==================================================
                    // NID
                    // ==================================================

                    TextFormField(
                      controller:
                      _nidController,
                      keyboardType:
                      TextInputType.number,
                      textInputAction:
                      TextInputAction.done,
                      decoration:
                      const InputDecoration(
                        labelText:
                        'NID Number',
                        hintText: 'Optional',
                        border:
                        OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ==================================================
                    // ADD TENANT
                    // ==================================================

                    SizedBox(
                      width:
                      double.infinity,
                      child: FilledButton(
                        onPressed:
                        tenantState.isLoading
                            ? null
                            : _createTenant,
                        child:
                        tenantState.isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                          CircularProgressIndicator(
                            strokeWidth:
                            2,
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

// ==================================================================
// GRIHO USER CARD
// ==================================================================

class _ExistingUserCard extends StatelessWidget {
  final AppUser user;

  const _ExistingUserCard({
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin:
      const EdgeInsets.only(top: 8),
      child: Padding(
        padding:
        const EdgeInsets.all(12),
        child: Row(
          children: [
            const CircleAvatar(
              child:
              Icon(Icons.person_outline),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    'Griho user found',
                    style: Theme
                        .of(context)
                        .textTheme
                        .labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.name,
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleMedium,
                  ),
                  if (user.email != null &&
                      user.email!
                          .trim()
                          .isNotEmpty)
                    Padding(
                      padding:
                      const EdgeInsets
                          .only(
                        top: 4,
                      ),
                      child: Text(
                        user.email!,
                        maxLines: 1,
                        overflow:
                        TextOverflow
                            .ellipsis,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Griho ID: ${user.publicId}',
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
// EXISTING TENANT CARD
// ==================================================================

class _ExistingTenantCard extends StatelessWidget {
  final Tenant tenant;

  const _ExistingTenantCard({
    required this.tenant,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin:
      const EdgeInsets.only(top: 8),
      child: Padding(
        padding:
        const EdgeInsets.all(12),
        child: Row(
          children: [
            const CircleAvatar(
              child: Icon(Icons.person),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  Text(
                    'Existing tenant found',
                    style: Theme
                        .of(context)
                        .textTheme
                        .labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tenant.name,
                    style: Theme
                        .of(context)
                        .textTheme
                        .titleMedium,
                  ),
                  if (tenant.email != null &&
                      tenant.email!
                          .trim()
                          .isNotEmpty)
                    Padding(
                      padding:
                      const EdgeInsets
                          .only(
                        top: 4,
                      ),
                      child: Text(
                        tenant.email!,
                      ),
                    ),
                  if (tenant.nidNumber != null &&
                      tenant.nidNumber!
                          .trim()
                          .isNotEmpty)
                    Padding(
                      padding:
                      const EdgeInsets
                          .only(
                        top: 4,
                      ),
                      child: Text(
                        'NID: ${tenant.nidNumber}',
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'This tenant was previously added by you.',
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
    return Card(
      margin:
      const EdgeInsets.only(top: 8),
      child: const Padding(
        padding:
        EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No Griho user or previous tenant found. You can enter the tenant information manually.',
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
        padding:
        EdgeInsets.all(24),
        child: Text(
          'You need to add a property before adding a tenant.',
          textAlign:
          TextAlign.center,
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
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child:
              const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}