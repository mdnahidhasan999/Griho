// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/widgets/griho_picker_field.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../providers/team_providers.dart';

Color _statusColor(String status) {
  switch (status) {
    case 'active':
    case 'resolved':
      return GrihoColors.emerald;
    case 'suspended':
    case 'assigned':
      return GrihoColors.warning;
    case 'revoked':
    case 'cancelled':
      return GrihoColors.error;
    case 'in_progress':
      return Colors.blueAccent;
    default:
      return Colors.blueGrey;
  }
}

String _statusLabel(String status) {
  final clean = status.trim();
  if (clean.isEmpty) {
    return '';
  }
  if (clean == 'in_progress') {
    return 'In progress';
  }
  return clean[0].toUpperCase() + clean.substring(1);
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = _statusLabel(status);
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class OwnerTeamScreen extends ConsumerWidget {
  const OwnerTeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Team & Work Orders'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'People'),
              Tab(text: 'Work orders'),
            ],
          ),
        ),
        body: const TabBarView(children: [_PeopleTab(), _WorkOrdersTab()]),
      ),
    );
  }
}

class _PeopleTab extends ConsumerStatefulWidget {
  const _PeopleTab();

  @override
  ConsumerState<_PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends ConsumerState<_PeopleTab> {
  String _roleFilter = 'all';
  bool _showRevoked = false;
  bool _busy = false;

  List<TeamMember> _merge() {
    final lists = <AsyncValue<List<TeamMember>>>[
      ref.watch(ownerManagersProvider),
      ref.watch(ownerStaffProvider),
      ref.watch(ownerPendingManagerInvitesProvider),
      ref.watch(ownerPendingStaffInvitesProvider),
    ];
    final all = <TeamMember>[for (final l in lists) ...(l.value ?? const [])]
      ..sort((a, b) {
        int rank(TeamMember m) => switch (m.status) {
          'pending' => 0,
          'active' => 1,
          'suspended' => 2,
          _ => 3,
        };
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.name.compareTo(b.name);
      });
    return all;
  }

  Future<bool> _confirm(
    String title,
    String body,
    String action, {
    bool danger = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _log(TeamMember m, String title, String details) async {
    final uid = ref.read(currentUserProfileProvider).value?.uid;
    if (uid == null) {
      return;
    }
    await AuditLoggerService.log(
      ownerId: uid,
      propertyId: m.propertyId,
      propertyName: m.propertyName,
      category: 'manager',
      actionTitle: title,
      details: details,
      metadata: {'targetUserId': m.userId, 'role': m.role},
    );
  }

  Future<void> _changeStatus(TeamMember m, String next) async {
    if (_busy) {
      return;
    }
    final suspend = next == 'suspended';
    final ok = await _confirm(
      suspend ? 'Suspend access?' : 'Restore access?',
      suspend
          ? '${m.name} will immediately lose access to ${m.propertyName} until you restore it.'
          : '${m.name} will get full access to ${m.propertyName} again.',
      suspend ? 'Suspend' : 'Restore',
    );
    if (!ok || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.update(db.collection(m.accessCollection).doc(m.id), {
        'status': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (m.invitationId.isNotEmpty) {
        batch.update(
          db.collection(m.invitationCollection).doc(m.invitationId),
          {'accessStatus': next, 'updatedAt': FieldValue.serverTimestamp()},
        );
      }
      await batch.commit();
      await _log(
        m,
        suspend ? '${m.roleLabel} suspended' : '${m.roleLabel} restored',
        '${m.name} • ${m.propertyName}',
      );
      if (mounted) {
        GrihoFeedback.showSuccess(
          context,
          suspend ? 'Access suspended.' : 'Access restored.',
        );
      }
    } catch (e) {
      if (mounted) {
        GrihoFeedback.showError(context, 'Failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _revoke(TeamMember m) async {
    if (_busy) {
      return;
    }
    final ok = await _confirm(
      'Revoke access?',
      'Permanently remove ${m.name} from ${m.propertyName}? '
          'You will need to send a new invitation to assign them again.',
      'Revoke',
      danger: true,
    );
    if (!ok || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.update(db.collection(m.accessCollection).doc(m.id), {
        'status': 'revoked',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (m.invitationId.isNotEmpty) {
        batch
            .update(db.collection(m.invitationCollection).doc(m.invitationId), {
              'status': 'revoked',
              'accessStatus': 'revoked',
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }
      await batch.commit();
      await _log(
        m,
        '${m.roleLabel} access revoked',
        '${m.name} • ${m.propertyName}',
      );
      if (mounted) {
        GrihoFeedback.showSuccess(context, 'Access revoked.');
      }
    } catch (e) {
      if (mounted) {
        GrihoFeedback.showError(context, 'Failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _cancelInvite(TeamMember m) async {
    if (_busy) {
      return;
    }
    final ok = await _confirm(
      'Cancel invitation?',
      'The invitation to ${m.name} will be removed.',
      'Cancel invitation',
      danger: true,
    );
    if (!ok || !mounted) {
      return;
    }

    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance
          .collection(m.invitationCollection)
          .doc(m.id)
          .delete();
      await _log(m, '${m.roleLabel} invitation cancelled', m.name);
      if (mounted) {
        GrihoFeedback.showSuccess(context, 'Invitation cancelled.');
      }
    } catch (e) {
      if (mounted) {
        GrihoFeedback.showError(context, 'Failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _openInvite() => context.push(
    RouteNames.inviteMember(_roleFilter == 'all' ? 'manager' : _roleFilter),
  );

  @override
  Widget build(BuildContext context) {
    final all = _merge();
    final filtered = all.where((m) {
      if (!_showRevoked && m.status == 'revoked') {
        return false;
      }
      if (_roleFilter != 'all' && m.role != _roleFilter) {
        return false;
      }
      return true;
    }).toList();

    int count(String role) => all
        .where(
          (m) =>
              m.role == role && (m.status == 'active' || m.status == 'pending'),
        )
        .length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in const [
                        ['all', 'All'],
                        ['manager', 'Managers'],
                        ['caretaker', 'Caretakers'],
                        ['electrician', 'Electricians'],
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              f[0] == 'all'
                                  ? 'All'
                                  : '${f[1]} (${count(f[0])})',
                            ),
                            selected: _roleFilter == f[0],
                            onSelected: (_) =>
                                setState(() => _roleFilter = f[0]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _openInvite,
                icon: const Icon(Iconsax.user_add, size: 17),
                label: const Text('Invite'),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: () => setState(() => _showRevoked = !_showRevoked),
              child: Text(_showRevoked ? 'Hide revoked' : 'Show revoked'),
            ),
          ),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: GrihoStatusState(
                      icon: Iconsax.profile_2user,
                      title: 'No team members yet',
                      subtitle:
                          'Invite a manager, caretaker or electrician to share the work.',
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _MemberCard(
                    member: filtered[i],
                    onSuspend: () => _changeStatus(filtered[i], 'suspended'),
                    onRestore: () => _changeStatus(filtered[i], 'active'),
                    onRevoke: () => _revoke(filtered[i]),
                    onCancelInvite: () => _cancelInvite(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.onSuspend,
    required this.onRestore,
    required this.onRevoke,
    required this.onCancelInvite,
  });

  final TeamMember member;
  final VoidCallback onSuspend;
  final VoidCallback onRestore;
  final VoidCallback onRevoke;
  final VoidCallback onCancelInvite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = member;
    final color = _statusColor(m.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withValues(alpha: 0.14),
            child: Icon(m.roleIcon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(m.status),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${m.roleLabel} • ${m.propertyName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (m.contact.isNotEmpty)
                  Text(
                    m.contact,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (m.status != 'revoked')
            PopupMenuButton<String>(
              tooltip: 'Actions',
              onSelected: (v) {
                switch (v) {
                  case 'suspend':
                    onSuspend();
                  case 'restore':
                    onRestore();
                  case 'revoke':
                    onRevoke();
                  case 'cancel':
                    onCancelInvite();
                }
              },
              itemBuilder: (_) => [
                if (m.status == 'pending')
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Cancel invitation'),
                  ),
                if (m.status == 'active')
                  const PopupMenuItem(
                    value: 'suspend',
                    child: Text('Suspend access'),
                  ),
                if (m.status == 'suspended')
                  const PopupMenuItem(
                    value: 'restore',
                    child: Text('Restore access'),
                  ),
                if (m.status == 'active' || m.status == 'suspended')
                  PopupMenuItem(
                    value: 'revoke',
                    child: Text(
                      'Revoke access',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WorkOrdersTab extends ConsumerStatefulWidget {
  const _WorkOrdersTab();

  @override
  ConsumerState<_WorkOrdersTab> createState() => _WorkOrdersTabState();
}

class _WorkOrdersTabState extends ConsumerState<_WorkOrdersTab> {
  String _filter = 'open';

  Future<void> _update(
    WorkOrder w,
    Map<String, dynamic> data,
    String ok,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('maintenanceRequests')
          .doc(w.id)
          .update({...data, 'updatedAt': FieldValue.serverTimestamp()});
      if (mounted) {
        GrihoFeedback.showSuccess(context, ok);
      }
    } catch (e) {
      if (mounted) {
        GrihoFeedback.showError(context, 'Failed: $e');
      }
    }
  }

  Future<void> _assign(WorkOrder w) async {
    final staff =
        [
              ...(ref.read(ownerStaffProvider).value ?? const <TeamMember>[]),
              ...(ref.read(ownerManagersProvider).value ??
                  const <TeamMember>[]),
            ]
            .where((m) => m.status == 'active' && m.propertyId == w.propertyId)
            .toList();

    final preferred = w.category == 'electrical' ? 'electrician' : 'caretaker';
    staff.sort((a, b) {
      final ar = a.role == preferred ? 0 : 1;
      final br = b.role == preferred ? 0 : 1;
      return ar.compareTo(br);
    });

    final picked = await showModalBottomSheet<TeamMember>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: staff.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'No active team member for this building. Invite one from the People tab.',
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      'Assign to',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  for (final m in staff)
                    ListTile(
                      leading: Icon(m.roleIcon),
                      title: Text(m.name),
                      subtitle: Text(m.roleLabel),
                      trailing: m.role == preferred
                          ? const Chip(label: Text('Best fit'))
                          : null,
                      onTap: () => Navigator.pop(ctx, m),
                    ),
                ],
              ),
      ),
    );
    if (picked == null) {
      return;
    }

    await _update(w, {
      'assignedToUid': picked.userId,
      'assignedToName': picked.name,
      'assignedRole': picked.role,
    }, 'Assigned to ${picked.name}.');
  }

  void _create() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _WorkOrderSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.watch(ownerStaffProvider);
    ref.watch(ownerManagersProvider);
    final orders =
        ref.watch(ownerWorkOrdersProvider).value ?? const <WorkOrder>[];
    final shown = orders.where((w) {
      if (_filter == 'open') {
        return w.isOpenish;
      }
      if (_filter == 'done') {
        return !w.isOpenish;
      }
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'open', label: Text('Open')),
                    ButtonSegment(value: 'done', label: Text('Closed')),
                    ButtonSegment(value: 'all', label: Text('All')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Iconsax.task_square, size: 17),
                label: const Text('New'),
              ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    'No work orders here.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final w = shown[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                w.category == 'electrical'
                                    ? Iconsax.electricity
                                    : w.category == 'plumbing'
                                    ? Iconsax.drop
                                    : Iconsax.setting_2,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  w.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              _StatusChip(w.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${w.propertyName} • ${w.unitName}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (w.assignedToName.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Assigned to ${w.assignedToName}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (w.isOpenish) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _assign(w),
                                  child: Text(
                                    w.assignedToUid.isEmpty
                                        ? 'Assign'
                                        : 'Reassign',
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () => _update(w, {
                                    'status': 'resolved',
                                  }, 'Marked as resolved.'),
                                  child: const Text('Mark resolved'),
                                ),
                                TextButton(
                                  onPressed: () => _update(w, {
                                    'status': 'cancelled',
                                  }, 'Work order cancelled.'),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _WorkOrderSheet extends ConsumerStatefulWidget {
  const _WorkOrderSheet();

  @override
  ConsumerState<_WorkOrderSheet> createState() => _WorkOrderSheetState();
}

class _WorkOrderSheetState extends ConsumerState<_WorkOrderSheet> {
  final _titleCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  Property? _property;
  String _category = 'electrical';
  bool _saving = false;

  static const _categories = [
    (
      key: 'electrical',
      label: 'Electrical',
      icon: Iconsax.electricity,
      color: GrihoColors.warning,
    ),
    (
      key: 'plumbing',
      label: 'Plumbing',
      icon: Iconsax.drop,
      color: Colors.blueAccent,
    ),
    (
      key: 'general',
      label: 'General',
      icon: Iconsax.setting_2,
      color: GrihoColors.emerald,
    ),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _unitCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(List<Property> props, String? uid) async {
    FocusScope.of(context).unfocus();
    final property = _property ?? (props.isNotEmpty ? props.first : null);
    if (property == null || _titleCtrl.text.trim().isEmpty) {
      GrihoFeedback.showError(context, 'Choose a building and enter a title.');
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('maintenanceRequests').add({
        'ownerId': property.ownerId,
        'propertyId': property.id,
        'propertyName': property.name,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'unitName': _unitCtrl.text.trim().isEmpty
            ? 'Common Area'
            : _unitCtrl.text.trim(),
        'category': _category,
        'status': 'open',
        'assignedToUid': '',
        'assignedToName': '',
        'assignedRole': '',
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      GrihoFeedback.showSuccess(context, 'Work order created.');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        GrihoFeedback.showError(context, '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = ref.watch(currentUserProfileProvider).value?.uid;
    final props =
        (ref.watch(currentOwnerPropertiesProvider).value ?? const <Property>[])
            .where((p) => p.ownerId == uid)
            .toList();

    final selectedProperty =
        _property != null && props.any((p) => p.id == _property!.id)
        ? _property
        : (props.isNotEmpty ? props.first : null);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: GrihoColors.emerald.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Iconsax.task_square,
                    color: GrihoColors.emerald,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Work Order',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Create a maintenance task for your building',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Iconsax.close_circle, size: 22),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (props.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: GrihoStatusState(
                  icon: Iconsax.buildings_2,
                  title: 'No buildings found',
                  subtitle: 'Add a building first before creating work orders.',
                ),
              )
            else ...[
              GrihoPickerField<Property>(
                label: 'Select Building',
                hint: 'Choose a building',
                sheetTitle: 'Select Building',
                searchHint: 'Search by building name or code...',
                icon: Iconsax.buildings_2,
                items: props,
                value: selectedProperty,
                enabled: !_saving,
                itemTitle: (p) => p.name,
                itemSubtitle: (p) => p.propertyCode.trim().isNotEmpty
                    ? 'Code: ${p.propertyCode}'
                    : null,
                onChanged: (p) => setState(() => _property = p),
              ),
              const SizedBox(height: 18),
              Text(
                'Type of Work',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < _categories.length; i++) ...[
                    Expanded(
                      child: _WorkCategoryTile(
                        label: _categories[i].label,
                        icon: _categories[i].icon,
                        accentColor: _categories[i].color,
                        selected: _category == _categories[i].key,
                        onTap: () =>
                            setState(() => _category = _categories[i].key),
                      ),
                    ),
                    if (i != _categories.length - 1) const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _titleCtrl,
                enabled: !_saving,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'What needs fixing? *',
                  hintText: 'e.g. Corridor light not working',
                  prefixIcon: Icon(
                    Iconsax.edit_2,
                    color: GrihoColors.emerald,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _unitCtrl,
                enabled: !_saving,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Unit / Location (Optional)',
                  hintText: 'e.g. Unit 3B, Rooftop, Main Gate',
                  prefixIcon: Icon(
                    Iconsax.location,
                    color: GrihoColors.emerald,
                    size: 19,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descCtrl,
                enabled: !_saving,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Additional Details (Optional)',
                  hintText: 'Any notes or instructions for the technician...',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Iconsax.document_text,
                      color: GrihoColors.emerald,
                      size: 19,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GrihoPrimaryButton(
                label: _saving ? 'Creating...' : 'Create Work Order',
                icon: Iconsax.tick_circle,
                isLoading: _saving,
                onPressed: () => _save(props, uid),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkCategoryTile extends StatelessWidget {
  const _WorkCategoryTile({
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.14)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accentColor : theme.colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected
                  ? accentColor
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? accentColor
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
