// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import 'griho_home_components.dart';

typedef JsonMap = Map<String, dynamic>;

JsonMap asJsonMap(Object? raw) => homeAsMap(raw);

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
// SHARED OPEN ISSUES BANNER (CACHED STREAM + SERVER-SIDE STATUS FILTER)
// ============================================================================

class OpenIssuesBanner extends StatefulWidget {
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
  State<OpenIssuesBanner> createState() => _OpenIssuesBannerState();
}

class _OpenIssuesBannerState extends State<OpenIssuesBanner> {
  Stream<QuerySnapshot>? _stream;
  String _streamKey = '';

  void _ensureStream() {
    final values = widget.filterValues.take(10).toList()..sort();
    final key = '${widget.filterField}:${values.join(',')}';
    if (_stream != null && _streamKey == key) {
      return;
    }
    _streamKey = key;

    if (values.isEmpty) {
      _stream = null;
      return;
    }

    final col = FirebaseFirestore.instance.collection('maintenanceRequests');
    final baseQuery = widget.filterField == 'ownerId'
        ? col.where('ownerId', isEqualTo: values.first)
        : col.where('propertyId', whereIn: values);

    // Filter only open/in-progress tickets on Firestore to avoid reading resolved history.
    _stream = baseQuery
        .where('status', whereIn: const ['open', 'in_progress'])
        .limit(50)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _ensureStream();
  }

  @override
  void didUpdateWidget(covariant OpenIssuesBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureStream();
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    if (stream == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snap) {
        final openCount = snap.data?.docs.length ?? 0;
        if (openCount == 0) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: Icon(
                Iconsax.warning_2,
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
                widget.subtitle,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
              trailing: Icon(
                Iconsax.arrow_right_3,
                size: 18,
                color: theme.colorScheme.onErrorContainer,
              ),
              onTap: widget.onTap,
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

class BuildingMaintenanceSheet extends StatefulWidget {
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
  State<BuildingMaintenanceSheet> createState() =>
      _BuildingMaintenanceSheetState();
}

class _BuildingMaintenanceSheetState extends State<BuildingMaintenanceSheet> {
  Stream<QuerySnapshot>? _issuesStream;

  @override
  void initState() {
    super.initState();
    if (widget.filterValues.isNotEmpty) {
      final col = FirebaseFirestore.instance.collection('maintenanceRequests');
      final query = widget.filterField == 'ownerId'
          ? col.where('ownerId', isEqualTo: widget.filterValues.first)
          : col.where(
              'propertyId',
              whereIn: widget.filterValues.take(10).toList(),
            );
      _issuesStream = query.limit(50).snapshots();
    }
  }

  Future<void> _updateIssue(DocumentSnapshot doc, String nextStatus) async {
    try {
      await doc.reference.update({
        'status': nextStatus,
        'handledByName': widget.actorName,
        'handledByRole': widget.actorRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) {
        return;
      }
      GrihoFeedback.showSuccess(
        context,
        nextStatus == 'resolved'
            ? 'Issue marked resolved.'
            : 'Issue marked in progress.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, 'Could not update issue: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stream = _issuesStream;

    if (stream == null) {
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: GrihoStatusState(
            icon: Iconsax.buildings_2,
            title: 'No properties assigned',
            subtitle: 'Assigned building issues will appear here.',
          ),
        ),
      );
    }

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const GrihoLoadingView(message: 'Loading issues...');
            }

            final docs = [...snap.data!.docs];
            docs.sort((a, b) {
              final at = homeAsMap(a.data())['createdAt'];
              final bt = homeAsMap(b.data())['createdAt'];
              final am = at is Timestamp ? at.millisecondsSinceEpoch : 0;
              final bm = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
              return bm.compareTo(am);
            });

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: GrihoStatusState(
                      icon: Iconsax.tick_circle,
                      title: 'No issues reported',
                      subtitle:
                          'Resident maintenance requests will show up here.',
                    ),
                  ),
                for (final doc in docs)
                  Builder(
                    builder: (context) {
                      final d = homeAsMap(doc.data());
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
                                    if (status == 'open') ...[
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              _updateIssue(doc, 'in_progress'),
                                          child: const Text('In Progress'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: FilledButton.tonal(
                                        onPressed: () =>
                                            _updateIssue(doc, 'resolved'),
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
// SHARED BUILDING NOTICES SHEET (OWNER & MANAGER — CACHED STREAM)
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
  final String actorRole;
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

  Stream<QuerySnapshot>? _noticesStream;
  String? _noticesStreamPropId;

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

  Stream<QuerySnapshot> _getNoticesStream(String propertyId) {
    if (_noticesStream == null || _noticesStreamPropId != propertyId) {
      _noticesStreamPropId = propertyId;
      _noticesStream = FirebaseFirestore.instance
          .collection('buildingNotices')
          .where('propertyId', isEqualTo: propertyId)
          .limit(40)
          .snapshots();
    }
    return _noticesStream!;
  }

  Future<void> _publishNotice() async {
    final title = _titleCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (_selectedPropertyId.isEmpty || title.isEmpty || message.isEmpty) {
      GrihoFeedback.showError(
        context,
        'Please select a building and enter title & message.',
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
        ownerId = (homeAsMap(propSnap.data())['ownerId'] ?? '')
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
      if (!mounted) {
        return;
      }
      GrihoFeedback.showSuccess(context, 'Notice published to residents!');
    } catch (e) {
      if (!mounted) {
        return;
      }
      GrihoFeedback.showError(context, 'Could not publish notice: $e');
    } finally {
      if (mounted) {
        setState(() => _posting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.properties.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GrihoStatusState(
            icon: Iconsax.buildings_2,
            title: 'No building available',
            subtitle: widget.actorRole == 'owner'
                ? 'Add a building first to post notices.'
                : 'Accept a building assignment first to post notices.',
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
                    if (v != null) {
                      setState(() => _selectedPropertyId = v);
                    }
                  },
                ),
                const SizedBox(height: 10),
              ],
              GrihoTextField(
                controller: _titleCtrl,
                label: 'Notice Title *',
                hint: 'e.g. Water Tank Cleaning Tomorrow',
                prefixIcon: Iconsax.notification_bing,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 10),
              GrihoTextField(
                controller: _messageCtrl,
                label: 'Details / Schedule *',
                hint: 'Water supply will be paused from 10 AM to 1 PM.',
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Urgency Level',
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
                        if (v != null) {
                          setState(() => _priority = v);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  GrihoPrimaryButton(
                    label: 'Publish',
                    icon: Iconsax.send_2,
                    isLoading: _posting,
                    fullWidth: false,
                    onPressed: _publishNotice,
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
                stream: _getNoticesStream(activePropId),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: GrihoLoadingView(message: 'Loading notices...'),
                    );
                  }
                  final docs = [...snap.data!.docs];
                  docs.sort((a, b) {
                    final at = homeAsMap(a.data())['createdAt'];
                    final bt = homeAsMap(b.data())['createdAt'];
                    final am = at is Timestamp ? at.millisecondsSinceEpoch : 0;
                    final bm = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
                    return bm.compareTo(am);
                  });

                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: GrihoStatusState(
                        icon: Iconsax.notification_bing,
                        title: 'No notices posted',
                        subtitle:
                            'Published announcements for this building will appear here.',
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (final doc in docs)
                        Builder(
                          builder: (context) {
                            final d = homeAsMap(doc.data());
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
                                      ? Iconsax.warning_2
                                      : Iconsax.notification_bing,
                                  color: isUrgent
                                      ? GrihoColors.error
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
                                    Iconsax.trash,
                                    size: 19,
                                    color: GrihoColors.error,
                                  ),
                                  onPressed: () async {
                                    await doc.reference.delete();
                                    if (!context.mounted) {
                                      return;
                                    }
                                    GrihoFeedback.showInfo(
                                      context,
                                      'Notice deleted.',
                                    );
                                  },
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
