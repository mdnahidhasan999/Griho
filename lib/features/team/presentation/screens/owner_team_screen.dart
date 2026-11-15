import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/services/audit_logger_service.dart';
import '../../../properties/domain/entities/property.dart';
import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../providers/team_providers.dart';

Color _statusColor(String status) {
  switch (status) {
    case 'active':
    case 'resolved':
      return Colors.green;
    case 'suspended':
    case 'assigned':
      return Colors.orange;
    case 'revoked':
    case 'cancelled':
      return Colors.red;
    case 'in_progress':
      return Colors.blue;
    default:
      return Colors.blueGrey; // pending / open
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'in_progress':
      return 'In progress';
    case '':
      return '';
    default:
      return status[0].toUpperCase() + status.substring(1);
  }
}

void _toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

// ============================================================================
// SCREEN
// ============================================================================

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

// ============================================================================
// PEOPLE TAB
// ============================================================================

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
    final all = <TeamMember>[for (final l in lists) ...(l.value ?? const [])];
    all.sort((a, b) {
      int rank(TeamMember m) {
        switch (m.status) {
          case 'pending':
            return 0;
          case 'active':
            return 1;
          case 'suspended':
            return 2;
          default:
            return 3;
        }
      }

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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
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
    if (_busy) return;
    final suspend = next == 'suspended';
    final ok = await _confirm(
      suspend ? 'Suspend access?' : 'Restore access?',
      suspend
          ? '${m.name} will immediately lose access to ${m.propertyName} until you restore it.'
          : '${m.name} will get full access to ${m.propertyName} again.',
      suspend ? 'Suspend' : 'Restore',
    );
    if (!ok || !mounted) return;

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
        _toast(context, suspend ? 'Access suspended.' : 'Access restored.');
      }
    } catch (e) {
      if (mounted) _toast(context, 'Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(TeamMember m) async {
    if (_busy) return;
    final ok = await _confirm(
      'Revoke access?',
      'Permanently remove ${m.name} from ${m.propertyName}? '
          'You will need to send a new invitation to assign them again.',
      'Revoke',
      danger: true,
    );
    if (!ok || !mounted) return;

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
      if (mounted) _toast(context, 'Access revoked.');
    } catch (e) {
      if (mounted) _toast(context, 'Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelInvite(TeamMember m) async {
    if (_busy) return;
    final ok = await _confirm(
      'Cancel invitation?',
      'The invitation to ${m.name} will be removed.',
      'Cancel invitation',
      danger: true,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance
          .collection(m.invitationCollection)
          .doc(m.id)
          .delete();
      await _log(m, '${m.roleLabel} invitation cancelled', m.name);
      if (mounted) _toast(context, 'Invitation cancelled.');
    } catch (e) {
      if (mounted) _toast(context, 'Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Opens the unified invite screen, pre-selecting the role of the active filter.
  void _openInvite() => context.push(
    RouteNames.inviteMember(_roleFilter == 'all' ? 'manager' : _roleFilter),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = _merge();
    final filtered = all.where((m) {
      if (!_showRevoked && m.status == 'revoked') return false;
      if (_roleFilter != 'all' && m.role != _roleFilter) return false;
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
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_2_outlined,
                          size: 56,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No team members yet',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Invite a manager, caretaker or electrician to share the work.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(m.roleIcon, color: color, size: 22),
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

// ============================================================================
// WORK ORDERS TAB
// ============================================================================

class _WorkOrdersTab extends ConsumerStatefulWidget {
  const _WorkOrdersTab();

  @override
  ConsumerState<_WorkOrdersTab> createState() => _WorkOrdersTabState();
}

class _WorkOrdersTabState extends ConsumerState<_WorkOrdersTab> {
  String _filter = 'open'; // open | done | all

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
      if (mounted) _toast(context, ok);
    } catch (e) {
      if (mounted) _toast(context, 'Failed: $e', error: true);
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

    // মিল থাকা রোল আগে দেখাও
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
    if (picked == null) return;

    // status stays as-is (staff dashboards start work from 'open')
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
    // keep these live so the "Assign" sheet always has the roster
    ref.watch(ownerStaffProvider);
    ref.watch(ownerManagersProvider);
    final orders =
        ref.watch(ownerWorkOrdersProvider).value ?? const <WorkOrder>[];
    final shown = orders.where((w) {
      if (_filter == 'open') return w.isOpenish;
      if (_filter == 'done') return !w.isOpenish;
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
                icon: const Icon(Icons.add_task_rounded, size: 18),
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
                                    ? Icons.electrical_services_rounded
                                    : w.category == 'plumbing'
                                    ? Icons.water_drop_rounded
                                    : Icons.build_rounded,
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

  @override
  void dispose() {
    _titleCtrl.dispose();
    _unitCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(List<Property> props) async {
    final property = _property ?? (props.isNotEmpty ? props.first : null);
    if (property == null || _titleCtrl.text.trim().isEmpty) {
      _toast(context, 'Choose a building and enter a title.', error: true);
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
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      _toast(context, 'Work order created.');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast(context, '$e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final props =
        (ref.watch(currentOwnerPropertiesProvider).value ?? const <Property>[])
            .where((p) => p.ownerId == uid)
            .toList();

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
            const Text(
              'New work order',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 14),
            if (props.isEmpty)
              const Text('Add a building first.')
            else ...[
              DropdownButtonFormField<Property>(
                initialValue: _property ?? props.first,
                decoration: const InputDecoration(
                  labelText: 'Building',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final p in props)
                    DropdownMenuItem(value: p, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() => _property = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Type of work',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'electrical',
                    child: Text('Electrical'),
                  ),
                  DropdownMenuItem(
                    value: 'plumbing',
                    child: Text('Plumbing / Water'),
                  ),
                  DropdownMenuItem(
                    value: 'general',
                    child: Text('General maintenance'),
                  ),
                ],
                onChanged: (v) => setState(() => _category = v ?? 'general'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'What needs fixing?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _unitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Unit / location (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _saving ? null : () => _save(props),
                child: const Text('Create work order'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
