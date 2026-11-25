// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/widgets/griho_picker_field.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../../../core/utils/phone_number_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';

enum _InviteMethod { phone, email, grihoId }

class _RoleInfo {
  const _RoleInfo(this.label, this.icon, this.description);

  final String label;
  final IconData icon;
  final String description;
}

const Map<String, _RoleInfo> _roles = {
  'manager': _RoleInfo(
    'Manager',
    Iconsax.shield_tick,
    'Runs residents, rent, bills and payments for the building.',
  ),
  'caretaker': _RoleInfo(
    'Caretaker',
    Iconsax.broom,
    'Handles plumbing and general maintenance, visitor log and notices.',
  ),
  'electrician': _RoleInfo(
    'Electrician',
    Iconsax.electricity,
    'Handles electrical repairs and records meter readings.',
  ),
};

class InviteTeamMemberScreen extends ConsumerStatefulWidget {
  const InviteTeamMemberScreen({super.key, this.initialRole = 'manager'});

  final String initialRole;

  @override
  ConsumerState<InviteTeamMemberScreen> createState() =>
      _InviteTeamMemberScreenState();
}

class _InviteTeamMemberScreenState
    extends ConsumerState<InviteTeamMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _grihoIdController = TextEditingController();

  late String _role;
  _InviteMethod _method = _InviteMethod.phone;
  Property? _selectedProperty;
  String _phoneNumber = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _role = _roles.containsKey(widget.initialRole)
        ? widget.initialRole
        : 'manager';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _grihoIdController.dispose();
    super.dispose();
  }

  String? _validatedPhone() {
    final clean = PhoneNumberUtils.clean(_phoneNumber);
    if (!PhoneNumberUtils.isValid(clean)) {
      return null;
    }
    return PhoneNumberUtils.normalize(clean);
  }

  Future<void> _send(List<Property> properties) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final profile = ref.read(currentUserProfileProvider).value;

    final property =
        (_selectedProperty != null &&
            properties.any((p) => p.id == _selectedProperty!.id))
        ? _selectedProperty
        : (properties.isNotEmpty ? properties.first : null);
    if (property == null) {
      GrihoFeedback.showError(
        context,
        'Please select or create a property first.',
      );
      return;
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      GrihoFeedback.showError(
        context,
        'You must be signed in to send invitations.',
      );
      return;
    }

    if (!authUser.emailVerified) {
      GrihoFeedback.showWarning(
        context,
        'Please verify your email address before sending an invitation.',
      );
      return;
    }

    if (profile == null) {
      GrihoFeedback.showError(context, 'Owner profile not found.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      String? phone;
      String? targetEmail;
      String? targetGrihoId;
      String? targetUserId;
      var identifier = '';

      if (_method == _InviteMethod.phone) {
        final valid = _validatedPhone();
        if (valid == null) {
          throw ArgumentError(
            'Please enter a valid international phone number.',
          );
        }
        phone = valid;
        identifier = valid;
        try {
          final doc = await db.collection('phone_lookups').doc(valid).get();
          final d = doc.data();
          if (doc.exists && d != null) {
            targetUserId = (d['uid'] ?? '').toString().trim();
            targetGrihoId = (d['publicId'] ?? '').toString().trim();
            targetEmail = (d['email'] ?? '').toString().trim().toLowerCase();
          }
        } catch (_) {}
      } else if (_method == _InviteMethod.email) {
        targetEmail = _emailController.text.trim().toLowerCase();
        identifier = targetEmail;
      } else {
        targetGrihoId = _grihoIdController.text.trim().toUpperCase();
        identifier = targetGrihoId;
        try {
          final doc = await db
              .collection('public_ids')
              .doc(targetGrihoId)
              .get();
          final d = doc.data();
          if (doc.exists && d != null) {
            targetUserId = (d['uid'] ?? '').toString().trim();
            phone = (d['phoneNumber'] ?? '').toString().trim();
            targetEmail = (d['email'] ?? '').toString().trim().toLowerCase();
          }
        } catch (_) {}
      }

      final isManager = _role == 'manager';
      final docRef = db
          .collection(isManager ? 'managerInvitations' : 'staffInvitations')
          .doc();

      await docRef.set({
        'id': docRef.id,
        'token': docRef.id,
        'ownerId': profile.uid,
        'ownerName': profile.name,
        'ownerGrihoId': profile.publicId,
        'propertyId': property.id,
        'propertyName': property.name,
        'propertyCode': property.propertyCode,
        'name': _nameController.text.trim(),
        'identifier': identifier,
        'phone': phone,
        'rawPhone': phone != null ? PhoneNumberUtils.clean(phone) : '',
        'targetEmail': targetEmail,
        'targetGrihoId': targetGrihoId,
        'targetUserId': targetUserId,
        'role': _role,
        if (!isManager) 'staffRole': _role,
        'status': 'pending',
        'accessStatus': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await AuditLoggerService.log(
        ownerId: profile.uid,
        propertyId: property.id,
        propertyName: property.name,
        category: 'manager',
        actionTitle: '${_roles[_role]!.label} invited',
        details: '${_nameController.text.trim()} • $identifier',
      );

      if (!mounted) {
        return;
      }
      GrihoFeedback.showSuccess(
        context,
        '${_roles[_role]!.label} invitation sent for ${property.name}!',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(
        context,
        e.toString().replaceFirst(
          RegExp(r'^(Bad state: |Invalid argument\(s\): )'),
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentUserProfileProvider).value;
    final uid = profile?.uid;
    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);
    final info = _roles[_role]!;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Invite to your team')),
      body: propertiesAsync.when(
        loading: () => const GrihoLoadingView(message: 'Loading properties...'),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GrihoStatusState(
              icon: Iconsax.warning_2,
              title: 'Unable to load properties',
              subtitle: err.toString(),
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(currentOwnerPropertiesProvider),
            ),
          ),
        ),
        data: (all) {
          final properties = uid == null
              ? all
              : all.where((p) => p.ownerId == uid).toList();

          if (properties.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: GrihoStatusState(
                  icon: Iconsax.buildings_2,
                  title: 'No properties available',
                  subtitle:
                      'Please create at least one building before inviting your team.',
                ),
              ),
            );
          }

          final selectedProperty =
              (_selectedProperty != null &&
                  properties.any((p) => p.id == _selectedProperty!.id))
              ? _selectedProperty!
              : properties.first;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Role',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      for (final e in _roles.entries)
                        ButtonSegment(
                          value: e.key,
                          label: Text(e.value.label),
                          icon: Icon(e.value.icon, size: 17),
                        ),
                    ],
                    selected: {_role},
                    onSelectionChanged: (v) => setState(() => _role = v.first),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            info.icon,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            info.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GrihoPickerField<Property>(
                    label: 'Select Building / Property *',
                    hint: 'Choose a building',
                    sheetTitle: 'Select Building / Property',
                    searchHint: 'Search by building name or code...',
                    icon: Iconsax.buildings_2,
                    items: properties,
                    value: selectedProperty,
                    enabled: !_isLoading,
                    itemTitle: (p) => p.name,
                    itemSubtitle: (p) => p.propertyCode.trim().isNotEmpty
                        ? 'Code: ${p.propertyCode}'
                        : null,
                    onChanged: (p) => setState(() => _selectedProperty = p),
                    validator: (v) =>
                        v == null ? 'Please select a property.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: '${info.label} Full Name *',
                      prefixIcon: const Icon(
                        Iconsax.user,
                        color: GrihoColors.emerald,
                        size: 19,
                      ),
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) {
                        return 'Please enter full name.';
                      }
                      if (t.length < 2) {
                        return 'Name must be at least 2 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Invite Recipient Method',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
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
                        label: Text('Griho ID'),
                        icon: Icon(Iconsax.personalcard, size: 16),
                      ),
                    ],
                    selected: {_method},
                    onSelectionChanged: (v) =>
                        setState(() => _method = v.first),
                  ),
                  const SizedBox(height: 16),
                  if (_method == _InviteMethod.phone)
                    IntlPhoneField(
                      controller: _phoneController,
                      initialCountryCode: 'BD',
                      decoration: InputDecoration(
                        labelText: '${info.label} Phone Number *',
                      ),
                      onChanged: (p) => _phoneNumber = p.completeNumber,
                      validator: (p) {
                        if (p == null || p.number.trim().isEmpty) {
                          return 'Please enter phone number.';
                        }
                        if (!PhoneNumberUtils.isValid(p.completeNumber)) {
                          return 'Please enter a valid international phone number.';
                        }
                        return null;
                      },
                    ),
                  if (_method == _InviteMethod.email)
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: '${info.label} Email Address *',
                        hintText: 'e.g. name@example.com',
                        prefixIcon: const Icon(
                          Iconsax.sms,
                          color: GrihoColors.emerald,
                          size: 19,
                        ),
                      ),
                      validator: (v) {
                        final email = v?.trim() ?? '';
                        if (email.isEmpty) {
                          return 'Please enter recipient email.';
                        }
                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(email)) {
                          return 'Please enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                  if (_method == _InviteMethod.grihoId)
                    TextFormField(
                      controller: _grihoIdController,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Recipient Griho ID *',
                        hintText: 'e.g. GRI-U3GLWKJK',
                        prefixIcon: Icon(
                          Iconsax.personalcard,
                          color: GrihoColors.emerald,
                          size: 19,
                        ),
                      ),
                      validator: (v) {
                        final id = v?.trim().toUpperCase() ?? '';
                        if (id.isEmpty) {
                          return 'Please enter recipient Griho ID.';
                        }
                        if (!RegExp(
                          r'^[A-Z0-9][A-Z0-9_-]{2,39}$',
                        ).hasMatch(id)) {
                          return 'Please enter a valid Griho ID.';
                        }
                        return null;
                      },
                    ),
                  const SizedBox(height: 32),
                  GrihoPrimaryButton(
                    label: _isLoading
                        ? 'Sending Invitation...'
                        : 'Send ${info.label} Invitation',
                    icon: Iconsax.send_1,
                    isLoading: _isLoading,
                    onPressed: () => _send(properties),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
