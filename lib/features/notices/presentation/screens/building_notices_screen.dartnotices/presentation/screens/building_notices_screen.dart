// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../../core/navigation/app_bottom_navigation.dart';
import '../../../../../../auth/presentation/providers/auth_provider.dart';

typedef JsonMap = Map<String, dynamic>;
typedef TypedQuerySnapshot = QuerySnapshot<JsonMap>;

class _AccessibleBuilding {
  final String id;
  final String name;
  final String ownerId;
  final String
  userRole; // 'owner', 'manager', 'caretaker', 'electrician', 'tenant'

  const _AccessibleBuilding({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.userRole,
  });

  bool get canPost =>
      userRole == 'owner' || userRole == 'manager' || userRole == 'caretaker';

  bool get canDelete => userRole == 'owner' || userRole == 'manager';
}

class BuildingNoticesScreen extends ConsumerStatefulWidget {
  const BuildingNoticesScreen({super.key});

  @override
  ConsumerState<BuildingNoticesScreen> createState() =>
      _BuildingNoticesScreenState();
}

class _BuildingNoticesScreenState extends ConsumerState<BuildingNoticesScreen> {
  Future<List<_AccessibleBuilding>>? _buildingsFuture;
  String? _loadedForUid;
  String _selectedBuildingId = 'all';

  Future<List<_AccessibleBuilding>> _getBuildings(String uid) {
    if (_buildingsFuture == null || _loadedForUid != uid) {
      _loadedForUid = uid;
      _buildingsFuture = _loadAllUserBuildings(uid);
    }
    return _buildingsFuture!;
  }

  void _refreshBuildings(String uid) {
    setState(() {
      _loadedForUid = uid;
      _buildingsFuture = _loadAllUserBuildings(uid);
    });
  }

  Future<List<_AccessibleBuilding>> _loadAllUserBuildings(String uid) async {
    final db = FirebaseFirestore.instance;
    final byId = <String, _AccessibleBuilding>{};

    // Priority order: owner > manager > caretaker > electrician > tenant
    final results = await Future.wait([
      db.collection('properties').where('ownerId', isEqualTo: uid).get(),
      db
          .collection('managerAccess')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .get(),
      db
          .collection('staffAccess')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .get(),
      db
          .collection('tenants')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .get(),
    ]);

    // 1. Owned buildings
    for (final doc in results[0].docs) {
      final d = doc.data();
      byId[doc.id] = _AccessibleBuilding(
        id: doc.id,
        name: (d['name'] ?? 'Building').toString(),
        ownerId: uid,
        userRole: 'owner',
      );
    }

    // 2. Managed buildings
    for (final doc in results[1].docs) {
      final d = doc.data();
      final pId = (d['propertyId'] ?? '').toString().trim();
      if (pId.isEmpty || byId.containsKey(pId)) continue;
      byId[pId] = _AccessibleBuilding(
        id: pId,
        name: (d['propertyName'] ?? 'Managed Building').toString(),
        ownerId: (d['ownerId'] ?? '').toString().trim(),
        userRole: 'manager',
      );
    }

    // 3. Staff buildings (Caretaker / Electrician)
    for (final doc in results[2].docs) {
      final d = doc.data();
      final pId = (d['propertyId'] ?? '').toString().trim();
      if (pId.isEmpty || byId.containsKey(pId)) continue;
      final staffRole = (d['staffRole'] ?? 'caretaker').toString().trim();
      byId[pId] = _AccessibleBuilding(
        id: pId,
        name: (d['propertyName'] ?? 'Assigned Building').toString(),
        ownerId: (d['ownerId'] ?? '').toString().trim(),
        userRole: staffRole,
      );
    }

    // 4. Resident / Tenant buildings
    for (final doc in results[3].docs) {
      final d = doc.data();
      final pId = (d['propertyId'] ?? '').toString().trim();
      if (pId.isEmpty || byId.containsKey(pId)) continue;

      var propName = (d['propertyName'] ?? '').toString().trim();
      if (propName.isEmpty) {
        try {
          final pSnap = await db.collection('properties').doc(pId).get();
          propName = (pSnap.data()?['name'] ?? 'My Building').toString();
        } catch (_) {
          propName = 'My Building';
        }
      }

      byId[pId] = _AccessibleBuilding(
        id: pId,
        name: propName,
        ownerId: (d['ownerId'] ?? '').toString().trim(),
        userRole: 'tenant',
      );
    }

    return byId.values.toList();
  }

  void _openCreateNoticeSheet({
    required String actorUid,
    required String actorName,
    required List<_AccessibleBuilding> postableBuildings,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CreateNoticeModal(
        actorUid: actorUid,
        actorName: actorName,
        buildings: postableBuildings,
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp is! Timestamp) return 'Just now';
    final dt = timestamp.toDate().toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $hour:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      extendBody: true,

      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Building Notices',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Unable to load profile: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found.'));
          }

          return FutureBuilder<List<_AccessibleBuilding>>(
            future: _getBuildings(profile.uid),
            builder: (context, buildingsSnap) {
              if (buildingsSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final buildings =
                  buildingsSnap.data ?? const <_AccessibleBuilding>[];
              final buildingMap = {for (final b in buildings) b.id: b};

              if (buildings.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async => _refreshBuildings(profile.uid),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 80),
                      Icon(
                        Icons.campaign_outlined,
                        size: 56,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'No Building Notices Yet',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Announcements from buildings you own, manage, work at, or reside in will appear here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final validSelected =
                  _selectedBuildingId == 'all' ||
                      buildingMap.containsKey(_selectedBuildingId)
                  ? _selectedBuildingId
                  : 'all';

              final queryPropertyIds = validSelected == 'all'
                  ? buildings.map((b) => b.id).take(10).toList()
                  : <String>[validSelected];

              final noticesStream = FirebaseFirestore.instance
                  .collection('buildingNotices')
                  .where('propertyId', whereIn: queryPropertyIds)
                  .snapshots();

              return RefreshIndicator(
                onRefresh: () async => _refreshBuildings(profile.uid),
                child: Column(
                  children: [
                    if (buildings.length > 1)
                      SizedBox(
                        height: 48,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: const Text('All Buildings'),
                                selected: validSelected == 'all',
                                onSelected: (_) =>
                                    setState(() => _selectedBuildingId = 'all'),
                              ),
                            ),
                            for (final b in buildings)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(b.name),
                                  selected: validSelected == b.id,
                                  onSelected: (_) => setState(
                                    () => _selectedBuildingId = b.id,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: StreamBuilder<TypedQuerySnapshot>(
                        stream: noticesStream,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snap.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Unable to load notices: ${snap.error}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          final docs = [...(snap.data?.docs ?? const [])];
                          docs.sort((a, b) {
                            final at = a.data()['createdAt'];
                            final bt = b.data()['createdAt'];
                            final am = at is Timestamp
                                ? at.millisecondsSinceEpoch
                                : 0;
                            final bm = bt is Timestamp
                                ? bt.millisecondsSinceEpoch
                                : 0;
                            return bm.compareTo(am);
                          });

                          if (docs.isEmpty) {
                            return ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(32),
                              children: [
                                const SizedBox(height: 60),
                                Icon(
                                  Icons.notifications_none_rounded,
                                  size: 52,
                                  color: theme.colorScheme.outline,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No announcements posted yet',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            );
                          }

                          return ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 105),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final doc = docs[index];
                              final d = doc.data();
                              final propId = (d['propertyId'] ?? '')
                                  .toString()
                                  .trim();
                              final propName =
                                  (d['propertyName'] ??
                                          buildingMap[propId]?.name ??
                                          'Building')
                                      .toString();
                              final title = (d['title'] ?? 'Notice').toString();
                              final message = (d['message'] ?? '').toString();
                              final priority = (d['priority'] ?? 'normal')
                                  .toString()
                                  .toLowerCase();
                              final postedBy = (d['postedByName'] ?? 'Admin')
                                  .toString();
                              final postedRole = (d['postedByRole'] ?? '')
                                  .toString();

                              final isUrgent =
                                  priority == 'urgent' || priority == 'high';
                              final isImportant = priority == 'important';

                              final badgeColor = isUrgent
                                  ? Colors.red
                                  : isImportant
                                  ? Colors.orange.shade800
                                  : theme.colorScheme.primary;

                              final canDelete =
                                  buildingMap[propId]?.canDelete ?? false;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color: isUrgent
                                        ? Colors.red.withValues(alpha: 0.4)
                                        : theme.colorScheme.outlineVariant,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: badgeColor.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              priority.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: badgeColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              propName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          if (canDelete)
                                            IconButton(
                                              tooltip: 'Delete notice',
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 20,
                                                color: Colors.redAccent,
                                              ),
                                              onPressed: () =>
                                                  doc.reference.delete(),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        message,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(height: 1.4),
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            postedRole.isEmpty
                                                ? 'By $postedBy'
                                                : 'By $postedBy (${postedRole.toUpperCase()})',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                          Text(
                                            _formatDate(d['createdAt']),
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: profileAsync.value == null
          ? null
          : FutureBuilder<List<_AccessibleBuilding>>(
              future: _getBuildings(profileAsync.value!.uid),
              builder: (context, snap) {
                final postable = (snap.data ?? const <_AccessibleBuilding>[])
                    .where((b) => b.canPost)
                    .toList();
                if (postable.isEmpty) return const SizedBox.shrink();

                return FloatingActionButton.extended(
                  onPressed: () => _openCreateNoticeSheet(
                    actorUid: profileAsync.value!.uid,
                    actorName: profileAsync.value!.name,
                    postableBuildings: postable,
                  ),
                  icon: const Icon(Icons.campaign_rounded),
                  label: const Text('Post Notice'),
                );
              },
            ),
      bottomNavigationBar: const AppBottomNavigation(
        selectedDestination: GrihoNavigationDestination.notices,
      ),
    );
  }
}

class _CreateNoticeModal extends StatefulWidget {
  const _CreateNoticeModal({
    required this.actorUid,
    required this.actorName,
    required this.buildings,
  });

  final String actorUid;
  final String actorName;
  final List<_AccessibleBuilding> buildings;

  @override
  State<_CreateNoticeModal> createState() => _CreateNoticeModalState();
}

class _CreateNoticeModalState extends State<_CreateNoticeModal> {
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  late String _selectedPropertyId;
  String _priority = 'normal';
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _selectedPropertyId = widget.buildings.first.id;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final title = _titleCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both title and message.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final building = widget.buildings.firstWhere(
      (b) => b.id == _selectedPropertyId,
      orElse: () => widget.buildings.first,
    );

    setState(() => _posting = true);
    try {
      var ownerId = building.ownerId;
      if (ownerId.isEmpty) {
        final propSnap = await FirebaseFirestore.instance
            .collection('properties')
            .doc(building.id)
            .get();
        ownerId = (propSnap.data()?['ownerId'] ?? '').toString().trim();
      }

      await FirebaseFirestore.instance.collection('buildingNotices').add({
        'ownerId': ownerId,
        'propertyId': building.id,
        'propertyName': building.name,
        'title': title,
        'message': message,
        'priority': _priority,
        'postedByUid': widget.actorUid,
        'postedByName': widget.actorName,
        'postedByRole': building.userRole,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notice published!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not publish notice: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              'Publish Building Notice',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 14),
            if (widget.buildings.length > 1) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedPropertyId,
                decoration: const InputDecoration(
                  labelText: 'Target Building',
                  border: OutlineInputBorder(),
                ),
                items: widget.buildings
                    .map(
                      (b) => DropdownMenuItem<String>(
                        value: b.id,
                        child: Text(b.name),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedPropertyId = v);
                },
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notice Title *',
                hintText: 'e.g. Water Tank Cleaning Tomorrow',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Details *',
                hintText: 'Water supply will be paused from 10 AM to 1 PM.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Urgency Level',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'important', child: Text('Important')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _priority = v);
              },
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _posting ? null : _publish,
              icon: _posting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.campaign_rounded),
              label: Text(_posting ? 'Publishing...' : 'Publish Notice'),
            ),
          ],
        ),
      ),
    );
  }
}
