import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../../core/utils/phone_number_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';

enum _ManagerInviteMethod { phone, email, grihoId }

class AddManagerScreen extends ConsumerStatefulWidget {
  const AddManagerScreen({super.key});

  @override
  ConsumerState<AddManagerScreen> createState() => _AddManagerScreenState();
}

class _AddManagerScreenState extends ConsumerState<AddManagerScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _grihoIdController = TextEditingController();

  _ManagerInviteMethod _inviteMethod = _ManagerInviteMethod.phone;
  Property? _selectedProperty;

  String _phoneNumber = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _grihoIdController.dispose();
    super.dispose();
  }

  String? _getValidatedPhone() {
    final cleanPhone = PhoneNumberUtils.clean(_phoneNumber);
    if (!PhoneNumberUtils.isValid(cleanPhone)) {
      return null;
    }
    return PhoneNumberUtils.normalize(cleanPhone);
  }

  Future<void> _sendInvitation(List<Property> properties) async {
    if (!_formKey.currentState!.validate()) return;

    final property =
        _selectedProperty ?? (properties.isNotEmpty ? properties.first : null);
    if (property == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or create a property first.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    String? phone;
    String? targetEmail;
    String? targetGrihoId;
    String? targetUserId;
    String identifier = '';

    final firestore = FirebaseFirestore.instance;

    if (_inviteMethod == _ManagerInviteMethod.phone) {
      final validPhone = _getValidatedPhone();
      if (validPhone == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid international phone number.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      phone = validPhone;
      identifier = validPhone;

      try {
        final phoneDoc = await firestore
            .collection('phone_lookups')
            .doc(validPhone)
            .get();
        if (phoneDoc.exists) {
          final data = phoneDoc.data()!;
          targetUserId = (data['uid'] ?? '').toString().trim();
          targetGrihoId = (data['publicId'] ?? '').toString().trim();
          targetEmail = (data['email'] ?? '').toString().trim().toLowerCase();
        }
      } catch (_) {}
    } else if (_inviteMethod == _ManagerInviteMethod.email) {
      targetEmail = _emailController.text.trim().toLowerCase();
      identifier = targetEmail;
    } else {
      targetGrihoId = _grihoIdController.text.trim().toUpperCase();
      identifier = targetGrihoId;

      try {
        final pubDoc = await firestore
            .collection('public_ids')
            .doc(targetGrihoId)
            .get();
        if (pubDoc.exists) {
          final data = pubDoc.data()!;
          targetUserId = (data['uid'] ?? '').toString().trim();
          phone = (data['phoneNumber'] ?? '').toString().trim();
          targetEmail = (data['email'] ?? '').toString().trim().toLowerCase();
        }
      } catch (_) {}
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await ref.read(currentUserProfileProvider.future);
      if (profile == null) {
        throw StateError('Owner profile not found.');
      }

      final name = _nameController.text.trim();
      final docRef = firestore.collection('managerInvitations').doc();

      final cleanDigitsPhone = phone != null
          ? PhoneNumberUtils.clean(phone)
          : '';

      await docRef.set({
        'id': docRef.id,
        'token': docRef.id,
        'ownerId': profile.uid,
        'ownerName': profile.name,
        'ownerGrihoId': profile.publicId,
        'propertyId': property.id,
        'propertyName': property.name,
        'propertyCode': property.propertyCode,
        'name': name,
        'identifier': identifier,
        'phone': phone,
        'rawPhone': cleanDigitsPhone,
        'targetEmail': targetEmail,
        'targetGrihoId': targetGrihoId,
        'targetUserId': targetUserId,
        'role': 'manager',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Manager invitation sent for ${property.name}!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send invitation: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final propertiesAsync = ref.watch(currentOwnerPropertiesProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Invite Property Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: propertiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) =>
            Center(child: Text('Unable to load properties: $err')),
        data: (properties) {
          if (properties.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.apartment_rounded,
                      size: 48,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No properties available.',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please create at least one building before assigning a manager.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_selectedProperty == null && properties.isNotEmpty) {
            _selectedProperty = properties.first;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            Icons.admin_panel_settings_rounded,
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
                                'Assign a Building Manager',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Select the building and choose how to reach the manager.',
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
                  const SizedBox(height: 20),

                  // Building selection
                  DropdownButtonFormField<Property>(
                    initialValue: _selectedProperty,
                    decoration: const InputDecoration(
                      labelText: 'Select Building / Property *',
                      prefixIcon: Icon(Icons.domain_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    items: properties.map((prop) {
                      return DropdownMenuItem<Property>(
                        value: prop,
                        child: Text('${prop.name} (${prop.propertyCode})'),
                      );
                    }).toList(),
                    onChanged: (prop) {
                      setState(() {
                        _selectedProperty = prop;
                      });
                    },
                    validator: (val) =>
                        val == null ? 'Please select a property' : null,
                  ),
                  const SizedBox(height: 16),

                  // Manager Full Name
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Manager Full Name *',
                      hintText: 'e.g. Hani',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter manager full name.';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Method selection toggle
                  Text(
                    'Invite Recipient Method',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<_ManagerInviteMethod>(
                    segments: const [
                      ButtonSegment(
                        value: _ManagerInviteMethod.phone,
                        label: Text('Phone'),
                        icon: Icon(Icons.phone_outlined),
                      ),
                      ButtonSegment(
                        value: _ManagerInviteMethod.email,
                        label: Text('Email'),
                        icon: Icon(Icons.email_outlined),
                      ),
                      ButtonSegment(
                        value: _ManagerInviteMethod.grihoId,
                        label: Text('Griho ID'),
                        icon: Icon(Icons.badge_outlined),
                      ),
                    ],
                    selected: {_inviteMethod},
                    onSelectionChanged: (val) {
                      setState(() {
                        _inviteMethod = val.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Dynamic method field
                  if (_inviteMethod == _ManagerInviteMethod.phone)
                    IntlPhoneField(
                      controller: _phoneController,
                      initialCountryCode: 'BD',
                      decoration: const InputDecoration(
                        labelText: 'Manager Phone Number *',
                        hintText: 'Enter phone number',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      onChanged: (phone) {
                        _phoneNumber = phone.completeNumber;
                      },
                      validator: (phone) {
                        if (phone == null || phone.number.trim().isEmpty) {
                          return 'Please enter phone number.';
                        }
                        if (!PhoneNumberUtils.isValid(phone.completeNumber)) {
                          return 'Please enter a valid international phone number.';
                        }
                        return null;
                      },
                    ),

                  if (_inviteMethod == _ManagerInviteMethod.email)
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Manager Email Address *',
                        hintText: 'e.g. manager@example.com',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
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

                  if (_inviteMethod == _ManagerInviteMethod.grihoId)
                    TextFormField(
                      controller: _grihoIdController,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Recipient Griho ID *',
                        hintText: 'e.g. GRI-U3GLWKJK',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      validator: (value) {
                        final id = value?.trim().toUpperCase() ?? '';
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

                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _sendInvitation(properties),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                      label: Text(
                        _isLoading
                            ? 'Sending Invitation...'
                            : 'Send Manager Invitation',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
    );
  }
}
