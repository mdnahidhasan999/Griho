// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';

import '../design_system.dart';

class GrihoPickerField<T> extends FormField<T> {
  GrihoPickerField({
    super.key,
    required String label,
    required List<T> items,
    required T? value,
    required String Function(T item) itemTitle,
    String? Function(T item)? itemSubtitle,
    required ValueChanged<T> onChanged,
    String? hint,
    String? sheetTitle,
    String? searchHint,
    IconData? icon,
    IconData? itemIcon,
    bool enabled = true,
    int searchThreshold = 5,
    String? emptyMessage,
    super.validator,
    super.autovalidateMode,
  }) : super(
         initialValue: value,
         builder: (field) {
           return _GrihoPickerFieldView<T>(
             field: field,
             label: label,
             hint: hint ?? 'Select $label',
             sheetTitle: sheetTitle ?? 'Select $label',
             searchHint: searchHint ?? 'Search...',
             icon: icon,
             itemIcon: itemIcon ?? icon,
             items: items,
             selectedValue: value,
             itemTitle: itemTitle,
             itemSubtitle: itemSubtitle,
             enabled: enabled,
             searchThreshold: searchThreshold,
             emptyMessage: emptyMessage ?? 'No options available.',
             onSelected: (picked) {
               field.didChange(picked);
               onChanged(picked);
             },
           );
         },
       );
}

class _GrihoPickerFieldView<T> extends StatelessWidget {
  const _GrihoPickerFieldView({
    required this.field,
    required this.label,
    required this.hint,
    required this.sheetTitle,
    required this.searchHint,
    required this.icon,
    required this.itemIcon,
    required this.items,
    required this.selectedValue,
    required this.itemTitle,
    required this.itemSubtitle,
    required this.enabled,
    required this.searchThreshold,
    required this.emptyMessage,
    required this.onSelected,
  });

  final FormFieldState<T> field;
  final String label;
  final String hint;
  final String sheetTitle;
  final String searchHint;
  final IconData? icon;
  final IconData? itemIcon;
  final List<T> items;
  final T? selectedValue;
  final String Function(T item) itemTitle;
  final String? Function(T item)? itemSubtitle;
  final bool enabled;
  final int searchThreshold;
  final String emptyMessage;
  final ValueChanged<T> onSelected;

  Future<void> _openSheet(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GrihoPickerBottomSheet<T>(
        title: sheetTitle,
        searchHint: searchHint,
        items: items,
        selectedValue: selectedValue,
        itemTitle: itemTitle,
        itemSubtitle: itemSubtitle,
        itemIcon: itemIcon,
        showSearch: items.length >= searchThreshold,
        emptyMessage: emptyMessage,
      ),
    );

    if (picked != null) {
      onSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = selectedValue != null;
    final subtitle = hasValue ? itemSubtitle?.call(selectedValue as T) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? () => _openSheet(context) : null,
          child: InputDecorator(
            isEmpty: !hasValue,
            decoration: InputDecoration(
              labelText: label,
              errorText: field.errorText,
              enabled: enabled,
              prefixIcon: icon == null
                  ? null
                  : Icon(
                      icon,
                      size: 20,
                      color: enabled
                          ? GrihoColors.emerald
                          : theme.colorScheme.onSurfaceVariant,
                    ),
              suffixIcon: Icon(
                Iconsax.arrow_down_1,
                size: 18,
                color: enabled
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.disabledColor,
              ),
            ),
            child: hasValue
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        itemTitle(selectedValue as T),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null && subtitle.trim().isNotEmpty)
                        Text(
                          subtitle.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _GrihoPickerBottomSheet<T> extends StatefulWidget {
  const _GrihoPickerBottomSheet({
    required this.title,
    required this.searchHint,
    required this.items,
    required this.selectedValue,
    required this.itemTitle,
    required this.itemSubtitle,
    required this.itemIcon,
    required this.showSearch,
    required this.emptyMessage,
  });

  final String title;
  final String searchHint;
  final List<T> items;
  final T? selectedValue;
  final String Function(T item) itemTitle;
  final String? Function(T item)? itemSubtitle;
  final IconData? itemIcon;
  final bool showSearch;
  final String emptyMessage;

  @override
  State<_GrihoPickerBottomSheet<T>> createState() =>
      _GrihoPickerBottomSheetState<T>();
}

class _GrihoPickerBottomSheetState<T>
    extends State<_GrihoPickerBottomSheet<T>> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();

    final filtered = q.isEmpty
        ? widget.items
        : widget.items.where((item) {
            final title = widget.itemTitle(item).toLowerCase();
            final sub = (widget.itemSubtitle?.call(item) ?? '').toLowerCase();
            return title.contains(q) || sub.contains(q);
          }).toList();

    final maxSheetHeight = MediaQuery.of(context).size.height * 0.72;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Iconsax.close_circle, size: 22),
                  ),
                ],
              ),
            ),
            if (widget.showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    isDense: true,
                    prefixIcon: const Icon(
                      Iconsax.search_normal_1,
                      size: 18,
                      color: GrihoColors.emerald,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Iconsax.close_circle, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
            const Divider(height: 1),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 36,
                  horizontal: 24,
                ),
                child: Text(
                  q.isEmpty
                      ? widget.emptyMessage
                      : 'No matching results found.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final isSelected = item == widget.selectedValue;
                    final sub = widget.itemSubtitle?.call(item);

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.of(context).pop(item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? GrihoColors.emerald.withValues(alpha: 0.12)
                              : theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? GrihoColors.emerald
                                : theme.colorScheme.outlineVariant,
                            width: isSelected ? 1.4 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (widget.itemIcon != null) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? GrihoColors.emerald.withValues(
                                          alpha: 0.18,
                                        )
                                      : theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  widget.itemIcon,
                                  size: 18,
                                  color: isSelected
                                      ? GrihoColors.emerald
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.itemTitle(item),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: isSelected
                                          ? GrihoColors.emerald
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  if (sub != null && sub.trim().isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      sub.trim(),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Iconsax.tick_circle,
                                color: GrihoColors.emerald,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
