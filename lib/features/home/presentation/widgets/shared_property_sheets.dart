import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

typedef JsonMap = Map<String, dynamic>;

JsonMap asJsonMap(Object? raw) {
  if (raw is JsonMap) return raw;
  if (raw is Map) return JsonMap.from(raw);
  return <String, dynamic>{};
}

class NoticePropertyOption {
  const NoticePropertyOption({
    required this.id,
    required this.name,
    required this.ownerId,
  });

  final String id;
  final String name;
  final String ownerId;
}

// ============================================================================
// SHARED OPEN ISSUES BANNER (OWNER & MANAGER)
// ============================================================================

class OpenIssuesBanner extends StatelessWidget {
  const OpenIssuesBanner({
    super.key,
    required this.filterField,
    required this.filterValues,
    required this.onTap,
    this.subtitle = 'Tap to review, assign or mark resolved',
  });

  final String filterField;
  final List<String> filterValues;
  final VoidCallback onTap;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    if (filterValues.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final query = filterField == 'ownerId'
        ? FirebaseFirestore.instance
              .collection('maintenanceRequests')
              .where('ownerId', isEqualTo: filterValues.first)
        : FirebaseFirestore.instance
              .collection('maintenanceRequests')
              .where('propertyId', whereIn: filterValues.take(10).toList());

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const <QueryDocumentSnapshot>[];

        final openCount = docs.where((d) {
          final s = (asJsonMap(d.data())['status'] ?? 'open').toString();
          return s == 'open' || s == 'in_progress';
        }).length;

        if (openCount == 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                Icons.report_problem_rounded,
                color: theme.colorScheme.onErrorContainer,
              ),
              title: Text(
                openCount == 1
                    ? '1 tenant maintenance issue open'
                    : '$openCount tenant maintenance issues open',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onErrorContainer,
              ),
              onTap: onTap,
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// SHARED MAINTENANCE ISSUES SHEET (OWNER & MANAGER)
// ============================================================================

class BuildingMaintenanceSheet extends StatelessWidget {
  const BuildingMaintenanceSheet({
    super.key,
    required this.filterField,
    required this.filterValues,
    required this.actorName,
    required this.actorRole,
    this.title = 'Maintenance & Tenant Issues',
  });

  final String filterField;
  final List<String> filterValues;
  final String actorName;
  final String actorRole;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (filterValues.isEmpty) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No properties assigned yet.')),
        ),
      );
    }

    final query = filterField == 'ownerId'
        ? FirebaseFirestore.instance
              .collection('maintenanceRequests')
              .where('ownerId', isEqualTo: filterValues.first)
        : FirebaseFirestore.instance
              .collection('maintenanceRequests')
              .where('propertyId', whereIn: filterValues.take(10).toList());

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = [...snap.data!.docs];
            docs.sort((a, b) {
              final at = asJsonMap(a.data())['createdAt'];
              final bt = asJsonMap(b.data())['createdAt'];
              final am = at is Timestamp ? at.millisecondsSinceEpoch : 0;
              final bm = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
              return bm.compareTo(am);
            });

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('No issues reported yet.')),
                  ),
                for (final doc in docs)
                  Builder(
                    builder: (context) {
                      final d = asJsonMap(doc.data());
                      final issueTitle = (d['title'] ?? 'Issue').toString();
                      final desc = (d['description'] ?? '').toString();
                      final prop = (d['propertyName'] ?? '').toString();
                      final unit = (d['unitName'] ?? '').toString();
                      final cat = (d['category'] ?? 'general').toString();
                      final status = (d['status'] ?? 'open').toString();
                      final tenantName = (d['tenantName'] ?? '').toString();
                      final isDone = status == 'resolved';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      issueTitle,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  Chip(
                                    label: Text(
                                      status.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              Text(
                                '$prop • $unit (${cat.toUpperCase()})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              if (tenantName.isNotEmpty)
                                Text(
                                  'Reported by: $tenantName',
                                  style: theme.textTheme.bodySmall,
                                ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(desc, style: theme.textTheme.bodySmall),
                              ],
                              if (!isDone) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    if (status == 'open')
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {
                                            doc.reference.update({
                                              'status': 'in_progress',
                                              'handledByName': actorName,
                                              'handledByRole': actorRole,
                                              'updatedAt':
                                                  FieldValue.serverTimestamp(),
                                            });
                                          },
                                          child: const Text('In Progress'),
                                        ),
                                      ),
                                    if (status == 'open')
                                      const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.tonal(
                                        onPressed: () {
                                          doc.reference.update({
                                            'status': 'resolved',
                                            'handledByName': actorName,
                                            'handledByRole': actorRole,
                                            'updatedAt':
                                                FieldValue.serverTimestamp(),
                                          });
                                        },
                                        child: const Text('Mark Resolved'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// SHARED BUILDING NOTICES SHEET (OWNER & MANAGER)
// ============================================================================

class BuildingNoticesSheet extends StatefulWidget {
  const BuildingNoticesSheet({
    super.key,
    required this.actorUid,
    required this.actorName,
    required this.actorRole,
    required this.properties,
  });

  final String actorUid;
  final String actorName;
  final String actorRole; // 'owner' or 'manager'
  final List<NoticePropertyOption> properties;

  @override
  State<BuildingNoticesSheet> createState() => _BuildingNoticesSheetState();
}

class _BuildingNoticesSheetState extends State<BuildingNoticesSheet> {
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  late String _selectedPropertyId;
  String _priority = 'normal';
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _selectedPropertyId = widget.properties.isNotEmpty
        ? widget.properties.first.id
        : '';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _publishNotice() async {
    final title = _titleCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (_selectedPropertyId.isEmpty || title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a building and enter title & message.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final prop = widget.properties.firstWhere(
      (p) => p.id == _selectedPropertyId,
      orElse: () => widget.properties.first,
    );

    setState(() => _posting = true);
    try {
      var ownerId = prop.ownerId.trim();
      final propertyId = prop.id.trim();

      if (ownerId.isEmpty && propertyId.isNotEmpty) {
        final propSnap = await FirebaseFirestore.instance
            .collection('properties')
            .doc(propertyId)
            .get();
        ownerId = (asJsonMap(propSnap.data())['ownerId'] ?? '')
            .toString()
            .trim();
      }

      await FirebaseFirestore.instance.collection('buildingNotices').add({
        'ownerId': ownerId,
        'propertyId': propertyId,
        'propertyName': prop.name,
        'title': title,
        'message': message,
        'priority': _priority,
        'postedByUid': widget.actorUid,
        'postedByName': widget.actorName,
        'postedByRole': widget.actorRole,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _titleCtrl.clear();
      _messageCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notice published to residents!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not publish notice: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.properties.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              widget.actorRole == 'owner'
                  ? 'Add a building first to post notices.'
                  : 'Accept a building assignment first to post notices.',
            ),
          ),
        ),
      );
    }

    final activePropId =
        widget.properties.any((p) => p.id == _selectedPropertyId)
        ? _selectedPropertyId
        : widget.properties.first.id;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const Text(
                'Building Notices',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Post announcements directly to residents of your building.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              if (widget.properties.length > 1) ...[
                DropdownButtonFormField<String>(
                  initialValue: activePropId,
                  decoration: const InputDecoration(
                    labelText: 'Target Building',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: widget.properties
                      .map(
                        (p) => DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(p.name),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedPropertyId = v);
                  },
                ),
                const SizedBox(height: 10),
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
              const SizedBox(height: 10),
              TextField(
                controller: _messageCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Details / Schedule *',
                  hintText: 'Water supply will be paused from 10 AM to 1 PM.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Urgency Level',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'normal',
                          child: Text('Normal'),
                        ),
                        DropdownMenuItem(
                          value: 'important',
                          child: Text('Important'),
                        ),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text('Urgent'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _priority = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    onPressed: _posting ? null : _publishNotice,
                    icon: _posting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.campaign_rounded, size: 18),
                    label: const Text('Publish'),
                  ),
                ],
              ),
              const Divider(height: 28),
              const Text(
                'Published Notices',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('buildingNotices')
                    .where('propertyId', isEqualTo: activePropId)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = [...snap.data!.docs];
                  docs.sort((a, b) {
                    final at = asJsonMap(a.data())['createdAt'];
                    final bt = asJsonMap(b.data())['createdAt'];
                    final am = at is Timestamp ? at.millisecondsSinceEpoch : 0;
                    final bm = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
                    return bm.compareTo(am);
                  });

                  if (docs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'No notices posted for this building yet.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (final doc in docs)
                        Builder(
                          builder: (context) {
                            final d = asJsonMap(doc.data());
                            final isUrgent =
                                (d['priority'] ?? 'normal') == 'urgent';
                            final postedBy = (d['postedByName'] ?? 'Admin')
                                .toString();
                            final roleLabel =
                                (d['postedByRole'] ?? widget.actorRole)
                                    .toString()
                                    .toUpperCase();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Icon(
                                  isUrgent
                                      ? Icons.priority_high_rounded
                                      : Icons.campaign_outlined,
                                  color: isUrgent
                                      ? Colors.red
                                      : theme.colorScheme.primary,
                                ),
                                title: Text(
                                  (d['title'] ?? '').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  '${d['message'] ?? ''}\nBy $postedBy ($roleLabel)',
                                ),
                                isThreeLine: true,
                                trailing: IconButton(
                                  tooltip: 'Delete notice',
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => doc.reference.delete(),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
