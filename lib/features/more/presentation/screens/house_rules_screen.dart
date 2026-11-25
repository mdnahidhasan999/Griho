// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// মালিকের জন্য জনপ্রিয় ডিফল্ট বাসা ভাড়ার নিয়ম (এক ক্লিকে সিলেক্ট করা যাবে)
const List<String> _presetHouseRules = [
  'প্রতি মাসের ৫ তারিখের মধ্যে বাসা ভাড়া পরিশোধ করতে হবে।',
  'বাসা ছাড়ার অন্তত ১ মাস আগে মালিককে জানাতে হবে।',
  'রাত ১১টার পর বিল্ডিংয়ের মূল গেট বন্ধ থাকবে।',
  'রাত ১০টার পর উচ্চ শব্দে গান বাজানো বা হইচই করা যাবে না।',
  'মালিকের অনুমতি ছাড়া সাবলেট (Sublet) দেওয়া সম্পূর্ণ নিষিদ্ধ।',
  'সিঁড়ি, ছাদ ও কমন স্পেস পরিষ্কার-পরিচ্ছন্ন রাখতে হবে।',
  'গ্যাস, পানি ও বিদ্যুৎ অপচয় করা যাবে না।',
  'মালিকের অনুমতি ছাড়া দেয়ালে পেরেক বা বড় কোনো পরিবর্তন করা যাবে না।',
  'ভাড়াটিয়া ও পরিবারের সদস্যদের সঠিক NID তথ্য জমা দিতে হবে।',
  'নির্ধারিত ডাস্টবিন বা বর্জ্য পাত্রে ময়লা ফেলতে হবে, যেখানে-সেখানে ফেলা যাবে না।',
  'রাত ১১টার পর আগত মেহমান বা অতিথি সম্পর্কে মালিক বা কেয়ারটেকারকে জানাতে হবে।',
  'পোষা প্রাণী পালন করতে চাইলে আগে মালিকের অনুমতি নিতে হবে।',
  'ছাদে শুকানো কাপড় বা কোনো জিনিস দীর্ঘদিন ফেলে রাখা যাবে না।',
  'নির্ধারিত পার্কিং স্পেসের বাইরে গাড়ি বা বাইক রাখা যাবে না।',
  'অ্যাডভান্স বা সিকিউরিটি ডিপোজিটের শর্ত অনুযায়ী বকেয়া বিল ও ক্ষয়ক্ষতি সমন্বয় করে ফেরত দেওয়া হবে।',
];

// ============================================================================
// 1. OWNER HOUSE RULES SCREEN (ADD / SELECT / EDIT RULES)
// ============================================================================

class OwnerHouseRulesScreen extends ConsumerStatefulWidget {
  const OwnerHouseRulesScreen({super.key});

  @override
  ConsumerState<OwnerHouseRulesScreen> createState() =>
      _OwnerHouseRulesScreenState();
}

class _OwnerHouseRulesScreenState extends ConsumerState<OwnerHouseRulesScreen> {
  final _customRuleController = TextEditingController();
  final List<String> _selectedRules = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  @override
  void dispose() {
    _customRuleController.dispose();
    super.dispose();
  }

  Future<void> _loadRules() async {
    final profile = ref.read(currentUserProfileProvider).value;
    if (profile == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('house_rules')
          .doc(profile.uid)
          .get();

      final data = doc.data();
      final rawRules = data?['rules'];
      if (rawRules is List) {
        _selectedRules
          ..clear()
          ..addAll(
            rawRules
                .whereType<String>()
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty),
          );
      }
    } catch (e) {
      if (mounted) {
        GrihoFeedback.showError(context, 'Unable to load house rules: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _togglePresetRule(String rule) {
    setState(() {
      if (_selectedRules.contains(rule)) {
        _selectedRules.remove(rule);
      } else {
        _selectedRules.add(rule);
      }
    });
  }

  void _addCustomRule() {
    final text = _customRuleController.text.trim();
    if (text.isEmpty) return;

    if (_selectedRules.contains(text)) {
      GrihoFeedback.showInfo(context, 'This rule is already added.');
      return;
    }

    setState(() {
      _selectedRules.add(text);
      _customRuleController.clear();
    });
  }

  void _removeRule(String rule) {
    setState(() => _selectedRules.remove(rule));
  }

  Future<void> _saveRules() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();

    final profile = ref.read(currentUserProfileProvider).value;
    if (profile == null) {
      GrihoFeedback.showError(context, 'Owner profile not found.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('house_rules')
          .doc(profile.uid)
          .set({
            'ownerId': profile.uid,
            'ownerName': profile.name,
            'rules': _selectedRules,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      GrihoFeedback.showSuccess(
        context,
        'House rules saved! Tenants can now view these rules.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      GrihoFeedback.showError(context, 'Unable to save rules: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customRules = _selectedRules
        .where((r) => !_presetHouseRules.contains(r))
        .toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('House Rules & Policies')),
      body: _isLoading
          ? const GrihoLoadingView(message: 'Loading house rules...')
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
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
                            Iconsax.document_text_1,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'এখানে আপনি যে নিয়মগুলো সিলেক্ট বা যোগ করবেন, আপনার ভাড়াটিয়ারা ভাড়া কনফার্ম করার পর তাদের প্রোফাইলে সেগুলো দেখতে পারবে।',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 1. Quick Select Preset Rules
                  GrihoSectionCard(
                    title: '1. Quick Select Rules',
                    subtitle: 'ট্যাপ করে প্রয়োজনীয় নিয়মগুলো সিলেক্ট করুন',
                    icon: Iconsax.task_square,
                    children: [
                      for (final rule in _presetHouseRules) ...[
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: GrihoColors.emerald,
                          value: _selectedRules.contains(rule),
                          title: Text(
                            rule,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.35,
                            ),
                          ),
                          onChanged: _isSaving
                              ? null
                              : (_) => _togglePresetRule(rule),
                        ),
                        if (rule != _presetHouseRules.last)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 2. Add Custom Rules
                  GrihoSectionCard(
                    title: '2. Custom Rules',
                    subtitle: 'নিজের মতো করে অতিরিক্ত নিয়ম যোগ করুন',
                    icon: Iconsax.edit_2,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customRuleController,
                              enabled: !_isSaving,
                              maxLines: 2,
                              minLines: 1,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _addCustomRule(),
                              decoration: const InputDecoration(
                                labelText: 'Write a custom rule',
                                hintText:
                                    'যেমন: বাইক পার্কিংয়ের জন্য আলাদা চার্জ...',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _isSaving ? null : _addCustomRule,
                              child: const Icon(Iconsax.add),
                            ),
                          ),
                        ],
                      ),
                      if (customRules.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        for (var i = 0; i < customRules.length; i++) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Iconsax.tick_circle,
                              color: GrihoColors.emerald,
                              size: 20,
                            ),
                            title: Text(
                              customRules[i],
                              style: theme.textTheme.bodyMedium,
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove',
                              icon: Icon(
                                Iconsax.trash,
                                size: 18,
                                color: theme.colorScheme.error,
                              ),
                              onPressed: _isSaving
                                  ? null
                                  : () => _removeRule(customRules[i]),
                            ),
                          ),
                          if (i != customRules.length - 1)
                            const Divider(height: 1),
                        ],
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  GrihoPrimaryButton(
                    label: _isSaving
                        ? 'Saving Rules...'
                        : 'Save Rules (${_selectedRules.length} selected)',
                    icon: Iconsax.tick_circle,
                    isLoading: _isSaving,
                    onPressed: _saveRules,
                  ),
                ],
              ),
            ),
    );
  }
}

// ============================================================================
// 2. TENANT HOUSE RULES SCREEN (READ-ONLY VIEW OF LANDLORD'S RULES)
// ============================================================================

class TenantHouseRulesScreen extends ConsumerStatefulWidget {
  const TenantHouseRulesScreen({super.key, this.ownerId, this.propertyName});

  final String? ownerId;
  final String? propertyName;

  @override
  ConsumerState<TenantHouseRulesScreen> createState() =>
      _TenantHouseRulesScreenState();
}

class _TenantHouseRulesScreenState
    extends ConsumerState<TenantHouseRulesScreen> {
  bool _isLoading = true;
  String? _error;
  String _ownerName = '';
  DateTime? _updatedAt;
  List<String> _rules = const [];

  @override
  void initState() {
    super.initState();
    _loadTenantRules();
  }

  Future<void> _loadTenantRules() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final db = FirebaseFirestore.instance;
      var targetOwnerId = widget.ownerId?.trim() ?? '';

      // If ownerId wasn't passed directly (e.g. opened from Profile), find active tenancy.
      if (targetOwnerId.isEmpty) {
        final profile = ref.read(currentUserProfileProvider).value;
        if (profile == null) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _error = 'User profile not found.';
            });
          }
          return;
        }

        final tenantSnap = await db
            .collection('tenants')
            .where('userId', isEqualTo: profile.uid)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();

        if (tenantSnap.docs.isEmpty) {
          if (mounted) {
            setState(() {
              _rules = const [];
              _ownerName = '';
              _updatedAt = null;
              _isLoading = false;
            });
          }
          return;
        }

        targetOwnerId = (tenantSnap.docs.first.data()['ownerId'] ?? '')
            .toString()
            .trim();
      }

      if (targetOwnerId.isEmpty) {
        if (mounted) {
          setState(() {
            _rules = const [];
            _isLoading = false;
          });
        }
        return;
      }

      final rulesDoc = await db
          .collection('house_rules')
          .doc(targetOwnerId)
          .get();
      final rulesData = rulesDoc.data();
      final rawRules = rulesData?['rules'];
      final rawUpdated = rulesData?['updatedAt'];

      final loadedRules = rawRules is List
          ? rawRules
                .whereType<String>()
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : <String>[];

      if (mounted) {
        setState(() {
          _ownerName = (rulesData?['ownerName'] ?? '').toString().trim();
          _updatedAt = rawUpdated is Timestamp ? rawUpdated.toDate() : null;
          _rules = loadedRules;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final propertyName = widget.propertyName?.trim() ?? '';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('House Rules')),
      body: _isLoading
          ? const GrihoLoadingView(message: 'Loading house rules...')
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GrihoStatusState(
                  icon: Iconsax.warning_2,
                  title: 'Unable to load house rules',
                  subtitle: _error!,
                  actionLabel: 'Retry',
                  onAction: _loadTenantRules,
                ),
              ),
            )
          : _rules.isEmpty
          ? RefreshIndicator(
              onRefresh: _loadTenantRules,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 80),
                  GrihoStatusState(
                    icon: Iconsax.document_text_1,
                    title: 'No house rules added yet',
                    subtitle:
                        'Your landlord has not published any house rules for your tenancy yet.',
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadTenantRules,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                children: [
                  // Hero Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        colors: [GrihoColors.deepTeal, Color(0xFF064C50)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: GrihoColors.deepTeal.withValues(alpha: 0.22),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Iconsax.shield_tick,
                                size: 22,
                                color: GrihoColors.softMint,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'বাসা ভাড়ার নিয়মাবলী',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _ownerName.isNotEmpty
                                        ? 'মালিক: $_ownerName'
                                        : 'মালিকের নির্ধারিত নীতিমালা',
                                    style: const TextStyle(
                                      color: GrihoColors.mintWhisper,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: GrihoColors.emerald.withValues(
                                  alpha: 0.3,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: GrihoColors.softMint.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              child: Text(
                                '${_rules.length}টি নিয়ম',
                                style: const TextStyle(
                                  color: GrihoColors.mintWhisper,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (propertyName.isNotEmpty || _updatedAt != null) ...[
                          const SizedBox(height: 14),
                          Divider(
                            color: Colors.white.withValues(alpha: 0.14),
                            height: 1,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (propertyName.isNotEmpty)
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Iconsax.buildings_2,
                                        size: 14,
                                        color: GrihoColors.softMint,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          propertyName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: GrihoColors.mintWhisper,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_updatedAt != null)
                                Text(
                                  'Updated: ${_formatDate(_updatedAt!)}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Rules List Cards
                  for (var i = 0; i < _rules.length; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: GrihoColors.emerald.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: GrihoColors.emerald,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              _rules[i],
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.info_circle,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'সুন্দর ও শান্তিপূর্ণ বসবাসের জন্য মালিকের নির্ধারিত নিয়মগুলো মেনে চলুন।',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
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
