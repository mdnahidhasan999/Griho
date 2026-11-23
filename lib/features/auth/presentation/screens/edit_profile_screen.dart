// noinspection SpellCheckingInspection
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/widgets/griho_picker_field.dart';
import '../../../../core/services/firebase_storage_service.dart';
import '../../domain/entities/app_user.dart';
import '../providers/auth_provider.dart';

enum _PhotoTarget { avatar, nidFront, nidBack }

const List<String> _occupations = [
  'Student',
  'Service Holder',
  'Business',
  'Freelancer',
  'Housewife',
  'Retired',
  'Other',
];

class EditProfileScreen extends ConsumerStatefulWidget {
  final AppUser user;

  const EditProfileScreen({super.key, required this.user});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _storageService = FirebaseStorageService();

  late final TextEditingController _nameController;
  late final TextEditingController _nidController;

  DateTime? _dateOfBirth;
  String? _occupation;
  String? _gender;
  String? _maritalStatus;

  // Avatar state
  String? _photoUrl;
  String? _initialPhotoUrl;
  File? _pendingPhotoFile;
  Uint8List? _photoBytes;
  bool _photoChanged = false;

  // NID Front state
  String? _nidFrontUrl;
  String? _initialNidFrontUrl;
  File? _pendingNidFrontFile;
  Uint8List? _nidFrontBytes;
  bool _nidFrontChanged = false;

  // NID Back state
  String? _nidBackUrl;
  String? _initialNidBackUrl;
  File? _pendingNidBackFile;
  Uint8List? _nidBackBytes;
  bool _nidBackChanged = false;

  bool _isSaving = false;
  bool _isProcessingPhoto = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _nidController = TextEditingController(text: widget.user.nidNumber ?? '');

    _dateOfBirth = widget.user.dateOfBirth;
    _occupation = widget.user.occupation;
    _gender = widget.user.gender;
    _maritalStatus = widget.user.maritalStatus;

    _photoUrl = widget.user.photoUrl;
    _initialPhotoUrl = widget.user.photoUrl;
    _photoBytes = _decodeDataUrl(_photoUrl);

    _nidFrontUrl = widget.user.nidFrontUrl;
    _initialNidFrontUrl = widget.user.nidFrontUrl;

    _nidBackUrl = widget.user.nidBackUrl;
    _initialNidBackUrl = widget.user.nidBackUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nidController.dispose();
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

  ImageProvider? _buildImageProvider({
    File? file,
    Uint8List? bytes,
    String? url,
  }) {
    if (file != null) return FileImage(file);
    if (bytes != null) return MemoryImage(bytes);
    if (url != null && url.startsWith('http')) return NetworkImage(url);
    return null;
  }

  ImageProvider? _providerForTarget(_PhotoTarget target) => switch (target) {
    _PhotoTarget.avatar => _buildImageProvider(
      file: _pendingPhotoFile,
      bytes: _photoBytes,
      url: _photoUrl,
    ),
    _PhotoTarget.nidFront => _buildImageProvider(
      file: _pendingNidFrontFile,
      bytes: _nidFrontBytes,
      url: _nidFrontUrl,
    ),
    _PhotoTarget.nidBack => _buildImageProvider(
      file: _pendingNidBackFile,
      bytes: _nidBackBytes,
      url: _nidBackUrl,
    ),
  };

  String _titleForTarget(_PhotoTarget target) => switch (target) {
    _PhotoTarget.avatar => 'Profile Photo',
    _PhotoTarget.nidFront => 'NID Front Side',
    _PhotoTarget.nidBack => 'NID Back Side',
  };

  Future<void> _pickDateOfBirth() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();

    final now = DateTime.now();
    final initial = _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Select Date of Birth',
    );

    if (picked != null && mounted) {
      setState(() {
        _dateOfBirth = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  String _formatDob(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }

  Future<void> _viewFullPhoto(_PhotoTarget target) async {
    final provider = _providerForTarget(target);
    if (provider == null) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _titleForTarget(target),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(
                      Iconsax.close_circle,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image(image: provider, fit: BoxFit.contain),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPhotoOptions(_PhotoTarget target) async {
    if (_isSaving || _isProcessingPhoto) return;

    final hasPhoto = _providerForTarget(target) != null;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasPhoto)
                ListTile(
                  leading: const Icon(Iconsax.eye),
                  title: const Text('View full photo'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _viewFullPhoto(target);
                  },
                ),
              ListTile(
                leading: const Icon(Iconsax.gallery),
                title: Text(
                  hasPhoto ? 'Change from gallery' : 'Choose from gallery',
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pickPhoto(target, ImageSource.gallery);
                },
              ),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Iconsax.camera),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickPhoto(target, ImageSource.camera);
                  },
                ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(Iconsax.trash),
                  title: const Text('Remove photo'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    setState(() {
                      switch (target) {
                        case _PhotoTarget.avatar:
                          _photoUrl = null;
                          _photoBytes = null;
                          _pendingPhotoFile = null;
                          _photoChanged = true;
                        case _PhotoTarget.nidFront:
                          _nidFrontUrl = null;
                          _nidFrontBytes = null;
                          _pendingNidFrontFile = null;
                          _nidFrontChanged = true;
                        case _PhotoTarget.nidBack:
                          _nidBackUrl = null;
                          _nidBackBytes = null;
                          _pendingNidBackFile = null;
                          _nidBackChanged = true;
                      }
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickPhoto(_PhotoTarget target, ImageSource source) async {
    if (_isSaving || _isProcessingPhoto) return;

    setState(() => _isProcessingPhoto = true);

    try {
      final isAvatar = target == _PhotoTarget.avatar;
      // Keep NID resolution higher so text and numbers stay crisp and readable.
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: isAvatar ? 800 : 1600,
        maxHeight: isAvatar ? 800 : 1600,
        imageQuality: isAvatar ? 85 : 90,
      );

      if (picked == null) return;

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() {
          switch (target) {
            case _PhotoTarget.avatar:
              _photoBytes = bytes;
              _pendingPhotoFile = null;
              _photoChanged = true;
            case _PhotoTarget.nidFront:
              _nidFrontBytes = bytes;
              _pendingNidFrontFile = null;
              _nidFrontChanged = true;
            case _PhotoTarget.nidBack:
              _nidBackBytes = bytes;
              _pendingNidBackFile = null;
              _nidBackChanged = true;
          }
        });
      } else {
        final file = File(picked.path);
        if (!mounted) return;
        setState(() {
          switch (target) {
            case _PhotoTarget.avatar:
              _pendingPhotoFile = file;
              _photoBytes = null;
              _photoChanged = true;
            case _PhotoTarget.nidFront:
              _pendingNidFrontFile = file;
              _nidFrontBytes = null;
              _nidFrontChanged = true;
            case _PhotoTarget.nidBack:
              _pendingNidBackFile = file;
              _nidBackBytes = null;
              _nidBackChanged = true;
          }
        });
      }
    } catch (error) {
      if (!mounted) return;
      GrihoFeedback.showError(context, _cleanErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isProcessingPhoto = false);
      }
    }
  }

  Future<String?> _uploadNidImage({
    required String side,
    File? file,
    Uint8List? bytes,
    String? currentUrl,
  }) async {
    if (file == null && bytes == null) return currentUrl;

    final fileName = 'nid_${side}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storageRef = FirebaseStorage.instance.ref().child(
      'users/${widget.user.uid}/nid/$fileName',
    );
    final metadata = SettableMetadata(contentType: 'image/jpeg');

    final TaskSnapshot snap = file != null
        ? await storageRef.putFile(file, metadata)
        : await storageRef.putData(bytes!, metadata);

    return snap.ref.getDownloadURL();
  }

  bool _sameDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _saveProfile() async {
    if (_isSaving || _isProcessingPhoto) return;
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameController.text.trim();
    final nid = _nidController.text.trim();

    // Skip Firestore write if nothing actually changed.
    final unchanged =
        !_photoChanged &&
        !_nidFrontChanged &&
        !_nidBackChanged &&
        name == widget.user.name.trim() &&
        nid == (widget.user.nidNumber?.trim() ?? '') &&
        _sameDate(_dateOfBirth, widget.user.dateOfBirth) &&
        _occupation == widget.user.occupation &&
        _gender == widget.user.gender &&
        _maritalStatus == widget.user.maritalStatus;

    if (unchanged) {
      GrihoFeedback.showInfo(context, 'No changes to save.');
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isSaving = true);

    try {
      var finalPhotoUrl = _photoUrl;
      var finalNidFrontUrl = _nidFrontUrl;
      var finalNidBackUrl = _nidBackUrl;

      if (!kIsWeb && _pendingPhotoFile != null) {
        finalPhotoUrl = await _storageService.uploadUserProfilePhoto(
          userId: widget.user.uid,
          imageFile: _pendingPhotoFile!,
        );
      } else if (kIsWeb &&
          _photoChanged &&
          _photoBytes != null &&
          !(_photoUrl?.startsWith('data:image') ?? false)) {
        final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance.ref().child(
          'users/${widget.user.uid}/profile/$fileName',
        );
        final snap = await storageRef.putData(
          _photoBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );
        finalPhotoUrl = await snap.ref.getDownloadURL();
      }

      if (_nidFrontChanged) {
        finalNidFrontUrl = await _uploadNidImage(
          side: 'front',
          file: _pendingNidFrontFile,
          bytes: _nidFrontBytes,
          currentUrl: _nidFrontUrl,
        );
      }

      if (_nidBackChanged) {
        finalNidBackUrl = await _uploadNidImage(
          side: 'back',
          file: _pendingNidBackFile,
          bytes: _nidBackBytes,
          currentUrl: _nidBackUrl,
        );
      }

      final dataSource = ref.read(userProfileDataSourceProvider);

      // Preserve verified email and phone unchanged.
      await dataSource.updateProfile(
        uid: widget.user.uid,
        publicId: widget.user.publicId,
        phoneNumber: widget.user.phoneNumber,
        name: name,
        email: widget.user.email,
        photoUrl: finalPhotoUrl,
        nidNumber: nid.isEmpty ? null : nid,
      );

      // Merge extended personal & NID verification fields into the user document.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .set({
            'dateOfBirth': _dateOfBirth != null
                ? Timestamp.fromDate(_dateOfBirth!)
                : null,
            'occupation': _occupation,
            'gender': _gender,
            'maritalStatus': _maritalStatus,
            'nidFrontUrl': finalNidFrontUrl,
            'nidBackUrl': finalNidBackUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Clean up replaced storage files.
      if (_initialPhotoUrl != null &&
          _initialPhotoUrl != finalPhotoUrl &&
          _initialPhotoUrl!.contains('firebasestorage')) {
        await _storageService.deleteFileByUrl(_initialPhotoUrl);
      }
      if (_initialNidFrontUrl != null &&
          _initialNidFrontUrl != finalNidFrontUrl &&
          _initialNidFrontUrl!.contains('firebasestorage')) {
        await _storageService.deleteFileByUrl(_initialNidFrontUrl);
      }
      if (_initialNidBackUrl != null &&
          _initialNidBackUrl != finalNidBackUrl &&
          _initialNidBackUrl!.contains('firebasestorage')) {
        await _storageService.deleteFileByUrl(_initialNidBackUrl);
      }

      ref.invalidate(currentUserProfileProvider);

      if (!mounted) return;

      GrihoFeedback.showSuccess(context, 'Profile updated successfully.');
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      GrihoFeedback.showError(context, _cleanErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _cleanErrorMessage(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ') ? message.substring(11) : message;
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    GrihoFeedback.showSuccess(context, '$label copied to clipboard.');
  }

  String _roleName(String? role) => switch (role) {
    'owner' => 'Property Owner',
    'tenant' => 'Tenant',
    'manager' => 'Property Manager',
    'caretaker' => 'Caretaker',
    'electrician' => 'Electrician',
    _ => 'Griho User',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleName = _roleName(widget.user.defaultDashboard);
    final avatarProvider = _providerForTarget(_PhotoTarget.avatar);
    final nidFrontProvider = _providerForTarget(_PhotoTarget.nidFront);
    final nidBackProvider = _providerForTarget(_PhotoTarget.nidBack);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Personal Information')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              // Profile Avatar Header
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _showPhotoOptions(_PhotoTarget.avatar),
                          child: CircleAvatar(
                            radius: 46,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage: avatarProvider,
                            child: _isProcessingPhoto
                                ? const CircularProgressIndicator(
                                    strokeWidth: 2,
                                  )
                                : avatarProvider == null
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
                              onTap: () =>
                                  _showPhotoOptions(_PhotoTarget.avatar),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Iconsax.camera,
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
              const SizedBox(height: 22),

              // 1. Personal Information
              GrihoSectionCard(
                title: 'Personal Information',
                subtitle: 'Details as per your National ID (NID)',
                icon: Iconsax.user,
                children: [
                  GrihoTextField(
                    controller: _nameController,
                    label: 'Name (As per NID)',
                    hint: 'Enter your full name',
                    prefixIcon: Iconsax.personalcard,
                    textCapitalization: TextCapitalization.words,
                    enabled: !_isSaving,
                    textInputAction: TextInputAction.next,
                    validator: GrihoValidators.name,
                  ),
                  const SizedBox(height: 16),
                  GrihoTextField(
                    controller: _nidController,
                    label: 'Your NID Number',
                    hint: '10, 13 or 17 digits (Optional)',
                    prefixIcon: Iconsax.card,
                    enabled: !_isSaving,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 17,
                    counterText: '',
                    validator: GrihoValidators.optionalNid,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _isSaving ? null : _pickDateOfBirth,
                    child: InputDecorator(
                      isEmpty: _dateOfBirth == null,
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth (DD/MM/YYYY)',
                        prefixIcon: Icon(
                          Iconsax.calendar_1,
                          color: GrihoColors.emerald,
                          size: 20,
                        ),
                        suffixIcon: Icon(Iconsax.calendar, size: 18),
                      ),
                      child: _dateOfBirth == null
                          ? const SizedBox.shrink()
                          : Text(
                              _formatDob(_dateOfBirth!),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GrihoPickerField<String>(
                    label: 'Select Occupation',
                    hint: 'Choose your occupation',
                    sheetTitle: 'Select Occupation',
                    searchHint: 'Search occupation...',
                    icon: Iconsax.briefcase,
                    items: _occupations,
                    value: _occupation,
                    enabled: !_isSaving,
                    itemTitle: (item) => item,
                    onChanged: (val) => setState(() => _occupation = val),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Gender',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _RadioOptionCard(
                          label: 'Male',
                          selected: _gender == 'Male',
                          enabled: !_isSaving,
                          onTap: () => setState(() => _gender = 'Male'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RadioOptionCard(
                          label: 'Female',
                          selected: _gender == 'Female',
                          enabled: !_isSaving,
                          onTap: () => setState(() => _gender = 'Female'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Marital Status',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _RadioOptionCard(
                          label: 'Married',
                          selected: _maritalStatus == 'Married',
                          enabled: !_isSaving,
                          onTap: () =>
                              setState(() => _maritalStatus = 'Married'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RadioOptionCard(
                          label: 'Unmarried',
                          selected: _maritalStatus == 'Unmarried',
                          enabled: !_isSaving,
                          onTap: () =>
                              setState(() => _maritalStatus = 'Unmarried'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 2. Upload NID Photo
              GrihoSectionCard(
                title: 'Upload NID Photo',
                subtitle: 'Tap a card to view or upload clear NID photos',
                icon: Iconsax.camera,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _NidPhotoBox(
                          label: 'Your NID Front Side',
                          imageProvider: nidFrontProvider,
                          enabled: !_isSaving && !_isProcessingPhoto,
                          onTap: () => _showPhotoOptions(_PhotoTarget.nidFront),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _NidPhotoBox(
                          label: 'Your NID Back Side',
                          imageProvider: nidBackProvider,
                          enabled: !_isSaving && !_isProcessingPhoto,
                          onTap: () => _showPhotoOptions(_PhotoTarget.nidBack),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 3. Account & Security (All 3 Permanently Locked)
              GrihoSectionCard(
                title: 'Account & Security',
                subtitle: 'Verified credentials cannot be modified',
                icon: Iconsax.shield_tick,
                children: [
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Griho Public ID',
                      prefixIcon: const Icon(
                        Iconsax.finger_scan,
                        color: GrihoColors.emerald,
                        size: 20,
                      ),
                      suffixIcon: IconButton(
                        tooltip: 'Copy ID',
                        icon: const Icon(Iconsax.copy, size: 19),
                        onPressed: () =>
                            _copyToClipboard(widget.user.publicId, 'Griho ID'),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.45),
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
                      labelText: 'Email Address (Verified)',
                      prefixIcon: const Icon(
                        Iconsax.sms,
                        color: GrihoColors.emerald,
                        size: 20,
                      ),
                      suffixIcon: Icon(
                        Iconsax.lock,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.45),
                    ),
                    child: Text(
                      widget.user.email?.trim().isNotEmpty == true
                          ? widget.user.email!
                          : 'No email linked',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: const Icon(
                        Iconsax.call,
                        color: GrihoColors.emerald,
                        size: 20,
                      ),
                      suffixIcon: Icon(
                        Iconsax.lock,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.45),
                    ),
                    child: Text(
                      widget.user.phoneNumber ?? 'No phone linked',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              GrihoPrimaryButton(
                label: _isSaving ? 'Saving Changes...' : 'Save Changes',
                icon: Iconsax.tick_circle,
                isLoading: _isSaving || _isProcessingPhoto,
                onPressed: _saveProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioOptionCard extends StatelessWidget {
  const _RadioOptionCard({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? GrihoColors.emerald.withValues(alpha: 0.1)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? GrihoColors.emerald
                : theme.colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? GrihoColors.emerald
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? GrihoColors.emerald
                      : theme.colorScheme.outline,
                  width: selected ? 5.5 : 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NidPhotoBox extends StatelessWidget {
  const _NidPhotoBox({
    required this.label,
    required this.imageProvider,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final ImageProvider? imageProvider;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = imageProvider != null;

    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: Container(
            height: 130,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.45,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasImage
                    ? GrihoColors.emerald
                    : theme.colorScheme.outlineVariant,
                width: hasImage ? 1.5 : 1,
              ),
            ),
            child: hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image(
                          image: imageProvider!,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Iconsax.eye,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Icon(
                      Iconsax.camera,
                      size: 28,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
