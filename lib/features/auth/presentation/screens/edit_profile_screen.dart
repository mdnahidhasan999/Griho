import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_user_model.dart';
import '../../domain/entities/app_user.dart';
import '../providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final AppUser user;

  const EditProfileScreen({
    super.key,
    required this.user,
  });

  @override
  ConsumerState<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.user.name,
    );

    _phoneController = TextEditingController(
      text: widget.user.phoneNumber ?? '',
    );

    _emailController = TextEditingController(
      text: widget.user.email ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_isSaving) {
      return;
    }

    final isValid =
        _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      final updatedUser = AppUserModel(
        uid: widget.user.uid,
        publicId: widget.user.publicId,
        role: widget.user.role,
        name: name,
        phoneNumber: widget.user.phoneNumber,
        email: email.isEmpty ? null : email,
        photoUrl: widget.user.photoUrl,
        isActive: widget.user.isActive,
        createdAt: widget.user.createdAt,
        updatedAt: DateTime.now(),
      );

      final dataSource =
      ref.read(userProfileDataSourceProvider);

      await dataSource.updateUser(updatedUser);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile updated successfully.',
          ),
        ),
      );

      Navigator.of(context).pop(updatedUser);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update profile: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              32,
            ),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor:
                  theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person_outline,
                    size: 42,
                    color: theme
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Personal Information',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Update the information associated with your Griho account.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color:
                  theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 24),

              TextFormField(
                initialValue: widget.user.publicId,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Griho ID',
                  hintText: 'Your unique Griho ID',
                  prefixIcon: const Icon(
                    Icons.badge_outlined,
                  ),
                  suffixIcon: const Icon(
                    Icons.lock_outline,
                  ),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: theme
                      .colorScheme
                      .surfaceContainerHighest,
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                textCapitalization:
                TextCapitalization.words,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter your name',
                  prefixIcon: Icon(
                    Icons.person_outline,
                  ),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';

                  if (name.isEmpty) {
                    return 'Please enter your name.';
                  }

                  if (name.length < 2) {
                    return 'Name must be at least 2 characters.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(
                    Icons.phone_outlined,
                  ),
                  suffixIcon: const Icon(
                    Icons.lock_outline,
                  ),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: theme
                      .colorScheme
                      .surfaceContainerHighest,
                  helperText:
                  'Phone number is linked to your account.',
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                enabled: !_isSaving,
                keyboardType:
                TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';

                  if (email.isEmpty) {
                    return null;
                  }

                  final emailRegex = RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  );

                  if (!emailRegex.hasMatch(email)) {
                    return 'Please enter a valid email address.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 28),

              SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                  _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(
                    Icons.save_outlined,
                  ),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : 'Save Changes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}