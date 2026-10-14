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
    if (_searchType == type) return;
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
    if (!_hasSearched && _searchResult == null && _searchError == null) return;
    setState(() {
      _searchResult = null;
      _searchError = null;
      _hasSearched = false;
    });
  }

  void _onSearchPhoneChanged(String value) {
    _searchPhoneNumber = value;
    if (!_hasSearched && _searchResult == null && _searchError == null) return;
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

      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _searchResult = result;
      });

      if (result != null) {
        _fillFromSearchResult(result);
      }
    } catch (error) {
      if (!mounted) return;
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
    }
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
    if (!_formKey.currentState!.validate()) return;

    final property = _selectedProperty;
    final unit = _selectedUnit;
    if (property == null || unit == null) return;

    final phone = _getValidatedPhone();
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid international phone number.'),
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

    if (!mounted) return;

    if (tenant == null) {
      final state = ref.read(tenantControllerProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error?.toString() ?? 'Unable to create tenant.'),
        ),
      );
      return;
    }

    final invitationData = await _showInvitationConfirmation(tenant: tenant);
    if (!mounted) return;

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

      if (!mounted) return;

      await _showInvitationCreatedDialog(
        invitationToken: invitation.token,
        rentAmount: rentAmount,
      );

      if (!mounted) return;
      Navigator.of(context).pop(tenant);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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
        return AlertDialog(
          title: const Text('Invitation Created'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: Icon(Icons.check_circle_outline, size: 52)),
                const SizedBox(height: 16),
                const Text(
                  'The tenant invitation has been created successfully.',
                ),
                const SizedBox(height: 20),
                Text(
                  'Initial Monthly Rent',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '৳ ${_formatAmount(rentAmount)}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Invitation Link',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
                      if (!dialogContext.mounted) return;
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
    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);
    final tenantState = ref.watch(tenantControllerProvider);
    final selectedPropertyId = _selectedProperty?.id;

    final unitsAsync = selectedPropertyId == null
        ? const AsyncValue<List<Unit>>.data([])
        : ref.watch(propertyUnitsProvider(selectedPropertyId));

    return Scaffold(
      appBar: AppBar(title: const Text('Add Tenant')),
      body: SafeArea(
        child: propertiesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorView(
            message: 'Unable to load your properties.',
            onRetry: () => ref.invalidate(currentOwnerPropertiesProvider),
          ),
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
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select a property and unit, then search for the tenant or enter the information manually.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    DropdownButtonFormField<Property>(
                      initialValue: _selectedProperty,
                      decoration: const InputDecoration(
                        labelText: 'Property',
                        border: OutlineInputBorder(),
                      ),
                      items: properties
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                p.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (p) => setState(() {
                        _selectedProperty = p;
                        _selectedUnit = null;
                      }),
                      validator: (v) =>
                          v == null ? 'Please select a property.' : null,
                    ),
                    const SizedBox(height: 20),
                    unitsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (err, stack) => Text('Unable to load units: $err'),
                      data: (units) {
                        if (units.isEmpty) {
                          return const Text(
                            'No units available in this property.',
                          );
                        }
                        return DropdownButtonFormField<Unit>(
                          initialValue: _selectedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                          ),
                          items: units
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(
                                    '${u.unitNumber} — Floor ${u.floorNumber}',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (u) => setState(() => _selectedUnit = u),
                          validator: (v) =>
                              v == null ? 'Please select a unit.' : null,
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Find Existing Griho User',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    if (_searchType == _TenantSearchType.grihoId)
                      TextField(
                        controller: _searchController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Griho ID',
                          hintText: 'Enter Griho ID',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        onChanged: _onGrihoIdChanged,
                        onSubmitted: (_) => _searchRegisteredUser(),
                      ),
                    if (_searchType == _TenantSearchType.phone)
                      IntlPhoneField(
                        controller: _searchPhoneController,
                        initialCountryCode: 'BD',
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (phone) =>
                            _onSearchPhoneChanged(phone.completeNumber),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: _isSearching ? null : _searchRegisteredUser,
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
                      Text(
                        _searchError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (!_isSearching && _searchResult != null)
                      _TenantSearchResultCard(result: _searchResult!),
                    if (!_isSearching &&
                        _hasSearched &&
                        _searchResult == null &&
                        _searchError == null)
                      const _UserNotFoundView(),
                    const SizedBox(height: 28),
                    IntlPhoneField(
                      initialCountryCode: 'BD',
                      decoration: const InputDecoration(
                        labelText: 'Tenant Phone Number',
                        hintText: 'Select country and enter phone',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (phone) =>
                          _onPhoneChanged(phone.completeNumber),
                      validator: (phone) {
                        if (phone == null || phone.number.trim().isEmpty) {
                          return 'Please enter phone number.';
                        }
                        if (!PhoneNumberUtils.isValid(phone.completeNumber)) {
                          return 'Please enter a valid international number.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Tenant Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter tenant name.'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'Optional',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nidController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'NID Number',
                        hintText: 'Optional',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: tenantState.isLoading ? null : _createTenant,
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
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_rentController.text.trim());
    if (amount == null || amount <= 0) return;
    setState(() => _isSubmitting = true);
    Navigator.of(context).pop(amount);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Tenant Invitation'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tenant: ${widget.tenant.name}'),
            const SizedBox(height: 4),
            Text(
              widget.tenant.phone,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rentController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monthly Rent',
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
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Invitation'),
        ),
      ],
    );
  }
}

class _TenantSearchResultCard extends StatelessWidget {
  final TenantSearchResult result;

  const _TenantSearchResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            result.isExistingTenant ? Icons.person : Icons.person_outline,
          ),
        ),
        title: Text(result.name),
        subtitle: Text('${result.publicId} • ${result.phone}'),
      ),
    );
  }
}

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
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          Text(message),
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
