// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import 'griho_colors.dart';

// ============================================================================
// 1. CUSTOM GRIHO BRAND LOGO (DAY & NIGHT ADAPTIVE)
// ============================================================================

class GrihoLogo extends StatelessWidget {
  const GrihoLogo({
    super.key,
    this.size = 44,
    this.showWordmark = false,
    this.subtitle,
  });

  final double size;
  final bool showWordmark;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [GrihoColors.deepTeal, GrihoColors.emerald],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: GrihoColors.deepTeal.withValues(alpha: isDark ? 0.45 : 0.22),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Iconsax.buildings_2,
            size: size * 0.56,
            color: GrihoColors.mintWhisper,
          ),
          Positioned(
            right: size * 0.16,
            bottom: size * 0.16,
            child: Container(
              width: size * 0.22,
              height: size * 0.22,
              decoration: BoxDecoration(
                color: GrihoColors.softMint,
                shape: BoxShape.circle,
                border: Border.all(color: GrihoColors.deepTeal, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Griho',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// 2. HEADER ICON BADGE (AUTH & ONBOARDING SCREENS)
// ============================================================================

class GrihoIconBadge extends StatelessWidget {
  const GrihoIconBadge({
    super.key,
    required this.icon,
    this.size = 72,
    this.isSuccess = false,
  });

  final IconData icon;
  final double size;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = isSuccess
        ? GrihoColors.emerald.withValues(alpha: 0.16)
        : theme.colorScheme.primaryContainer;
    final fgColor = isSuccess
        ? GrihoColors.emerald
        : theme.colorScheme.onPrimaryContainer;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: Icon(icon, size: size * 0.5, color: fgColor),
      ),
    );
  }
}

// ============================================================================
// 3. BRANDED LOADING WIDGET
// ============================================================================

class GrihoLoadingView extends StatelessWidget {
  const GrihoLoadingView({super.key, this.message = 'Loading...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: GrihoColors.emerald,
                  backgroundColor: GrihoColors.softMint.withValues(alpha: 0.3),
                ),
              ),
              const GrihoLogo(size: 40),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. EMPTY / STATUS DISPLAY STATE (DAY & NIGHT ADAPTIVE)
// ============================================================================

class GrihoStatusState extends StatelessWidget {
  const GrihoStatusState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            GrihoPrimaryButton(
              label: actionLabel!,
              onPressed: onAction,
              fullWidth: false,
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// 5. REUSABLE SECTION CARD
// ============================================================================
class GrihoSectionCard extends StatelessWidget {
  const GrihoSectionCard({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? theme.colorScheme.outlineVariant
              : GrihoColors.softMint,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: GrihoColors.deepTeal.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isDark
                        ? GrihoColors.emerald.withValues(alpha: 0.16)
                        : GrihoColors.mintWhisper,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: GrihoColors.emerald),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

// ============================================================================
// 6. REUSABLE TEXT FIELD
// ============================================================================

class GrihoTextField extends StatelessWidget {
  const GrihoTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.counterText,
    this.enabled = true,
    this.readOnly = false,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? minLines;
  final int maxLines;
  final int? maxLength;
  final String? counterText;
  final bool enabled;
  final bool readOnly;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      keyboardType: keyboardType,
      obscureText: obscureText,
      minLines: minLines,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: counterText,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: GrihoColors.emerald, size: 20)
            : null,
        suffixIcon: suffixIcon,
      ),
    );
  }
}

// ============================================================================
// 7. REUSABLE PASSWORD FIELD (BUILT-IN VISIBILITY TOGGLE)
// ============================================================================

class GrihoPasswordField extends StatefulWidget {
  const GrihoPasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon = Iconsax.lock,
    this.enabled = true,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData prefixIcon;
  final bool enabled;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<GrihoPasswordField> createState() => _GrihoPasswordFieldState();
}

class _GrihoPasswordFieldState extends State<GrihoPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GrihoTextField(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      prefixIcon: widget.prefixIcon,
      enabled: widget.enabled,
      obscureText: _obscure,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      autofillHints: widget.autofillHints,
      suffixIcon: IconButton(
        tooltip: _obscure ? 'Show password' : 'Hide password',
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Iconsax.eye : Iconsax.eye_slash,
          size: 20,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ============================================================================
// 8. REUSABLE INTERNATIONAL PHONE FIELD
// ============================================================================

class GrihoPhoneField extends StatelessWidget {
  const GrihoPhoneField({
    super.key,
    required this.controller,
    required this.onCompleteNumberChanged,
    this.label = 'Phone Number',
    this.hint,
    this.enabled = true,
    this.initialCountryCode = 'BD',
  });

  final TextEditingController controller;
  final ValueChanged<String> onCompleteNumberChanged;
  final String label;
  final String? hint;
  final bool enabled;
  final String initialCountryCode;

  @override
  Widget build(BuildContext context) {
    return IntlPhoneField(
      controller: controller,
      initialCountryCode: initialCountryCode,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(labelText: label, hintText: hint),
      onChanged: (phone) => onCompleteNumberChanged(phone.completeNumber),
      validator: (phone) {
        if (phone == null || phone.number.trim().isEmpty) {
          return 'Please enter your phone number.';
        }
        if (!phone.isValidNumber()) {
          return 'Please enter a valid phone number.';
        }
        return null;
      },
    );
  }
}

// ============================================================================
// 9. REUSABLE PRIMARY & SECONDARY BUTTONS
// ============================================================================

class GrihoPrimaryButton extends StatelessWidget {
  const GrihoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: fullWidth ? const Size(double.infinity, 52) : null,
      ),
      onPressed: isLoading ? null : onPressed,
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading) ...[
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 10),
          ] else if (icon != null) ...[
            Icon(icon, size: 19),
            const SizedBox(width: 8),
          ],
          Text(label),
        ],
      ),
    );
  }
}

class GrihoSecondaryButton extends StatelessWidget {
  const GrihoSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: fullWidth ? const Size(double.infinity, 52) : null,
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 8)],
          Text(label),
        ],
      ),
    );
  }
}

// ============================================================================
// 10. SHARED FORM VALIDATORS
// ============================================================================

abstract final class GrihoValidators {
  static final RegExp _emailPattern = RegExp(
    r'^[A-Za-z0-9.!#$%&*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$',
  );

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return 'Please enter your full name.';
    }
    if (v.length < 2) {
      return 'Name must contain at least 2 characters.';
    }
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return 'Please enter your email address.';
    }
    if (!_emailPattern.hasMatch(v)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  static String? optionalEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return null;
    }
    if (!_emailPattern.hasMatch(v)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  static String? requiredPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password.';
    }
    return null;
  }

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please create a password.';
    }
    if (value.length < 6) {
      return 'Password must contain at least 6 characters.';
    }
    return null;
  }

  static String? optionalNid(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return null;
    }
    if (!RegExp(r'^(\d{10}|\d{13}|\d{17})$').hasMatch(v)) {
      return 'NID must be 10, 13 or 17 digits.';
    }
    return null;
  }
}
