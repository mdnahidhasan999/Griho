import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/utils/image_compression_helper.dart';
import '../../domain/entities/app_user.dart';
import '../providers/auth_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final AppUser user;

  const EditProfileScreen({super.key, required this.user});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  static const int _maxPhotoBytes = 150 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  String? _photoUrl;
  Uint8List? _photoBytes;

  bool _isSaving = false;
  bool _isProcessingPhoto = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email ?? '');

    _photoUrl = widget.user.photoUrl;
    _photoBytes = _decodeDataUrl(_photoUrl);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Uint8List? _decodeDataUrl(String? value) {
    if (value == null || !value.startsWith('data:image')) {
      return null;
    }

    try {
      return base64Decode(value.substring(value.indexOf(',') + 1));
    } catch (_) {
      return null;
    }
  }

  ImageProvider? get _photoProvider {
    final bytes = _photoBytes;

    if (bytes != null) {
      return MemoryImage(bytes);
    }

    final url = _photoUrl;

    if (url != null && url.startsWith('http')) {
      return NetworkImage(url);
    }

    return null;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showPhotoOptions() async {
    if (_isSaving || _isProcessingPhoto) {
      return;
    }

    final hasPhoto = _photoProvider != null;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickPhoto(ImageSource.gallery);
                },
              ),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickPhoto(ImageSource.camera);
                  },
                ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Remove photo'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    setState(() {
                      _photoUrl = null;
                      _photoBytes = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_isSaving || _isProcessingPhoto) {
      return;
    }

    setState(() {
      _isProcessingPhoto = true;
    });

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: kIsWeb ? 512 : 1024,
        maxHeight: kIsWeb ? 512 : 1024,
        imageQuality: kIsWeb ? 50 : 90,
      );

      if (picked == null) {
        return;
      }

      final Uint8List bytes;

      if (kIsWeb) {
        // File compression is not available on web, so use the picker's resize.
        bytes = await picked.readAsBytes();
      } else {
        final compressed = await ImageCompressionHelper.compressImage(
          File(picked.path),
        );

        if (compressed == null) {
          throw Exception('Could not process the selected photo.');
        }

        bytes = await compressed.readAsBytes();
      }

      if (bytes.length > _maxPhotoBytes) {
        throw Exception('Photo is too large. Please choose another one.');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _photoBytes = bytes;
        _photoUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      });
    } catch (error) {
      _showSnack(_cleanErrorMessage(error), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPhoto = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving || _isProcessingPhoto) {
      return;
    }

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      final dataSource = ref.read(userProfileDataSourceProvider);

      await dataSource.updateProfile(
        uid: widget.user.uid,
        publicId: widget.user.publicId,
        phoneNumber: widget.user.phoneNumber,
        name: name,
        email: email.isEmpty ? null : email,
        photoUrl: _photoUrl,
      );

      ref.invalidate(currentUserProfileProvider);

      if (!mounted) {
        return;
      }

      _showSnack('Profile updated successfully.');

      Navigator.of(context).pop();
    } catch (error) {
      _showSnack(_cleanErrorMessage(error), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _cleanErrorMessage(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ') ? message.substring(11) : message;
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('$label copied to clipboard.');
  }

  String _roleName(String? role) {
    switch (role) {
      case 'owner':
        return 'Property Owner';
      case 'tenant':
        return 'Tenant';
      case 'manager':
        return 'Property Manager';
      case 'caretaker':
        return 'Caretaker';
      case 'electrician':
        return 'Electrician';
      default:
        return 'Griho User';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleName = _roleName(widget.user.defaultDashboard);
    final photoProvider = _photoProvider;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _showPhotoOptions,
                          child: CircleAvatar(
                            radius: 46,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage: photoProvider,
                            child: _isProcessingPhoto
                                ? const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  )
                                : photoProvider == null
                                ? Text(
                                    _nameController.text.trim().isNotEmpty
                                        ? _nameController.text
                                              .trim()[0]
                                              .toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Material(
                            color: theme.colorScheme.primary,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _showPhotoOptions,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.photo_camera_rounded,
                                  size: 18,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        roleName,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _buildSectionCard(
                context,
                title: 'Personal Information',
                subtitle: 'Update your display name and contact email',
                icon: Icons.person_outline_rounded,
                children: [
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    enabled: !_isSaving,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      hintText: 'Enter your full name',
                      prefixIcon: Icon(Icons.badge_outlined),
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
                    controller: _emailController,
                    enabled: !_isSaving,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _saveProfile(),
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'e.g. name@example.com (Optional)',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) {
                        return null;
                      }
                      final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                      if (!emailRegex.hasMatch(email)) {
                        return 'Please enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSectionCard(
                context,
                title: 'Account & Security',
                subtitle: 'Permanently linked credentials for your account',
                icon: Icons.shield_outlined,
                children: [
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Griho Public ID',
                      prefixIcon: const Icon(Icons.fingerprint_rounded),
                      suffixIcon: IconButton(
                        tooltip: 'Copy ID',
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        onPressed: () =>
                            _copyToClipboard(widget.user.publicId, 'Griho ID'),
                      ),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                    ),
                    child: Text(
                      widget.user.publicId,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      suffixIcon: Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [Icon(Icons.lock_outline, size: 18)],
                        ),
                      ),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                    ),
                    child: Text(
                      widget.user.phoneNumber ?? 'No phone linked',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSaving || _isProcessingPhoto
                      ? null
                      : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving ? 'Saving Changes...' : 'Save Changes',
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
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
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
    );
  }
}
