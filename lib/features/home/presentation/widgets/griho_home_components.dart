// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

typedef HomeJsonMap = Map<String, dynamic>;
typedef HomeDocList = List<QueryDocumentSnapshot>;

HomeJsonMap homeAsMap(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return <String, dynamic>{};
}

// ============================================================================
// 1. UNIFIED BRAND HERO SUMMARY CARD
// ============================================================================

class GrihoHeroMetric {
  const GrihoHeroMetric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;
}

class GrihoHeroCard extends StatelessWidget {
  const GrihoHeroCard({
    super.key,
    required this.eyebrow,
    required this.headline,
    required this.metrics,
    this.eyebrowIcon,
    this.trailingBadge,
  });

  final String eyebrow;
  final String headline;
  final List<GrihoHeroMetric> metrics;
  final IconData? eyebrowIcon;
  final Widget? trailingBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [GrihoColors.deepTeal, Color(0xFF064C50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: GrihoColors.deepTeal.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (eyebrowIcon != null) ...[
                Icon(eyebrowIcon, size: 15, color: GrihoColors.softMint),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  eyebrow,
                  style: const TextStyle(
                    color: GrihoColors.softMint,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              ?trailingBadge,
            ],
          ),
          const SizedBox(height: 6),
          Text(
            headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final m in metrics)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: m.highlight
                              ? GrihoColors.softMint
                              : Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        m.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. REUSABLE 2-COLUMN QUICK ACTION GRID
// ============================================================================

class GrihoQuickActionItem {
  const GrihoQuickActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}

class GrihoQuickActionGrid extends StatelessWidget {
  const GrihoQuickActionGrid({super.key, required this.items});

  final List<GrihoQuickActionItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.3,
      children: [
        for (final item in items)
          Material(
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: item.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(item.icon, size: 20, color: item.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            item.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// 3. REUSABLE SECTION HEADER
// ============================================================================

class GrihoSectionHeader extends StatelessWidget {
  const GrihoSectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        ?trailing,
      ],
    );
  }
}

// ============================================================================
// 4. UNIFIED PENDING WORK INVITATION BANNER (MANAGER / CARETAKER / ELECTRICIAN)
// ============================================================================

class GrihoPendingInviteBanner extends StatelessWidget {
  const GrihoPendingInviteBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
    this.acceptLabel = 'Accept',
  });

  final String title;
  final String subtitle;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final String acceptLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GrihoColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: GrihoColors.warning.withValues(alpha: 0.7),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Iconsax.sms_notification,
                size: 18,
                color: GrihoColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onDecline,
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onAccept,
                  child: Text(acceptLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 5. SHARED STAFF INVITATION HELPER (AVOIDS DUPLICATE LOGIC & QUERIES)
// ============================================================================

abstract final class GrihoStaffInviteService {
  static Future<HomeDocList> fetchPendingStaffInvites({
    required dynamic profile,
    required String staffRole,
  }) async {
    final col = FirebaseFirestore.instance.collection('staffInvitations');
    final results = <String, QueryDocumentSnapshot>{};

    final uid = profile.uid.toString().trim();
    final phone = (profile.phoneNumber ?? '').toString().trim();
    final publicId = profile.publicId.toString().trim();
    final email = (profile.email ?? '').toString().trim();

    final queries = <Future<QuerySnapshot>>[
      if (uid.isNotEmpty)
        col
            .where('staffUserId', isEqualTo: uid)
            .where('status', isEqualTo: 'pending')
            .get(),
      if (phone.isNotEmpty)
        col
            .where('phone', isEqualTo: phone)
            .where('status', isEqualTo: 'pending')
            .get(),
      if (publicId.isNotEmpty)
        col
            .where('targetGrihoId', isEqualTo: publicId)
            .where('status', isEqualTo: 'pending')
            .get(),
      if (email.isNotEmpty)
        col
            .where('targetEmail', isEqualTo: email)
            .where('status', isEqualTo: 'pending')
            .get(),
    ];

    await Future.wait(
      queries.map((q) async {
        try {
          final snap = await q;
          for (final doc in snap.docs) {
            final data = homeAsMap(doc.data());
            final role = (data['staffRole'] ?? '').toString();
            if (role == staffRole) {
              results[doc.id] = doc;
            }
          }
        } catch (_) {}
      }),
    );

    return results.values.toList();
  }

  static Future<void> respondToStaffInvite({
    required QueryDocumentSnapshot doc,
    required dynamic profile,
    required String staffRole,
    required bool accept,
  }) async {
    final authUser = FirebaseAuth.instance.currentUser;
    await authUser?.reload();
    if (!(FirebaseAuth.instance.currentUser?.emailVerified ?? false)) {
      throw StateError(
        'Please verify your email address before responding to an invitation.',
      );
    }

    final firestore = FirebaseFirestore.instance;
    final data = homeAsMap(doc.data());
    final propertyId = (data['propertyId'] ?? '').toString().trim();
    final ownerId = (data['ownerId'] ?? '').toString().trim();

    final batch = firestore.batch();

    batch.update(doc.reference, {
      'status': accept ? 'accepted' : 'rejected',
      'accessStatus': accept ? 'active' : 'rejected',
      'staffUserId': profile.uid,
      'staffName': profile.name,
      'staffGrihoId': profile.publicId,
      'staffPhone': profile.phoneNumber,
      'respondedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (accept && propertyId.isNotEmpty) {
      final accessRef = firestore
          .collection('staffAccess')
          .doc('${profile.uid}_${propertyId}_$staffRole');
      batch.set(accessRef, {
        'userId': profile.uid,
        'staffName': profile.name,
        'staffGrihoId': profile.publicId,
        'staffPhone': profile.phoneNumber,
        'staffRole': staffRole,
        'ownerId': ownerId,
        'propertyId': propertyId,
        'propertyName': data['propertyName'] ?? 'Assigned Building',
        'propertyCode': data['propertyCode'] ?? '',
        'invitationId': doc.id,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final currentRoles = List<String>.from(profile.availableRoles ?? []);
      if (!currentRoles.contains(staffRole)) {
        batch.update(firestore.collection('users').doc(profile.uid), {
          'availableRoles': FieldValue.arrayUnion([staffRole]),
          'defaultDashboard': staffRole,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }
}
