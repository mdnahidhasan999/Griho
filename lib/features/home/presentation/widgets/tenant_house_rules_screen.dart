// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

class TenantHouseRulesScreen extends StatefulWidget {
  const TenantHouseRulesScreen({
    super.key,
    this.ownerId,
    this.propertyName,
  });

  final String? ownerId;
  final String? propertyName;

  @override
  State<TenantHouseRulesScreen> createState() => _TenantHouseRulesScreenState();
}

class _TenantHouseRulesScreenState extends State<TenantHouseRulesScreen> {
  bool _isLoading = true;
  String? _error;
  String _ownerName = '';
  DateTime? _updatedAt;
  List<String> _rules = const [];

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final db = FirebaseFirestore.instance;
      var targetOwnerId = widget.ownerId?.trim() ?? '';

      // If ownerId wasn't passed directly, find it from the active tenancy.
      if (targetOwnerId.isEmpty) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) {
          if (!mounted) return;
          setState(() {
            _error = 'Please sign in again.';
            _isLoading = false;
          });
          return;
        }

        final tenantSnap = await db
            .collection('tenants')
            .where('userId', isEqualTo: uid)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();

        if (tenantSnap.docs.isEmpty) {
          if (!mounted) return;
          setState(() {
            _rules = const [];
            _ownerName = '';
            _updatedAt = null;
            _isLoading = false;
          });
          return;
        }

        targetOwnerId =
            (tenantSnap.docs.first.data()['ownerId'] ?? '').toString().trim();
      }

      if (targetOwnerId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _rules = const [];
          _isLoading = false;
        });
        return;
      }

      final doc = await db.collection('house_rules').doc(targetOwnerId).get();
      final raw = doc.data();
      final ownerName = (raw?['ownerName'] ?? '').toString().trim();
      final rawUpdated = raw?['updatedAt'];
      final updatedAt = rawUpdated is Timestamp ? rawUpdated.toDate() : null;
      final rawRules = raw?['rules'];

      final loadedRules = rawRules is List
          ? rawRules
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList()
          : <String>[];

      if (!mounted) return;
      setState(() {
        _ownerName = ownerName;
        _updatedAt = updatedAt;
        _rules = loadedRules;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
            onAction: _loadRules,
          ),
        ),
      )
          : _rules.isEmpty
          ? RefreshIndicator(
        onRefresh: _loadRules,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 80),
            GrihoStatusState(
              icon: Iconsax.document_text_1,
              title: 'No house rules added yet',
              subtitle:
              'Your landlord has not published any house rules for this residence yet.',
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadRules,
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
