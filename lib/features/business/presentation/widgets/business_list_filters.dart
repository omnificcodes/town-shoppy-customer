import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../application/list_range.dart';

/// The filter bar shared by the Purchases and Redemptions lists: a
/// horizontally scrolling row of status chips, a date-range menu, and a
/// debounced (350 ms, like the web) search field.
class BusinessListFilters extends StatefulWidget {
  const BusinessListFilters({
    super.key,
    required this.statusOptions,
    required this.status,
    required this.onStatusChanged,
    required this.range,
    required this.onRangeChanged,
    required this.searchHint,
    required this.onSearchChanged,
    this.extra,
    this.customRangeLabel,
    this.onCustomRange,
  });

  final List<(String, String)> statusOptions;
  final String status;
  final ValueChanged<String> onStatusChanged;
  final ListRange range;
  final ValueChanged<ListRange> onRangeChanged;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;

  /// An extra control next to the range menu (the branch picker).
  final Widget? extra;

  /// See [BusinessRangeMenu.customLabel] / [BusinessRangeMenu.onCustomRange].
  final String? customRangeLabel;
  final void Function(DateTime from, DateTime to)? onCustomRange;

  @override
  State<BusinessListFilters> createState() => _BusinessListFiltersState();
}

class _BusinessListFiltersState extends State<BusinessListFilters> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => widget.onSearchChanged(value.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BusinessStatusChips(options: widget.statusOptions, selected: widget.status, onSelected: widget.onStatusChanged),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Search',
                  hintText: widget.searchHint,
                  controller: _search,
                  prefixIcon: Icons.search_rounded,
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              BusinessRangeMenu(
                range: widget.range,
                onRangeChanged: widget.onRangeChanged,
                customLabel: widget.customRangeLabel,
                onCustomRange: widget.onCustomRange,
              ),
              if (widget.extra != null) ...[const SizedBox(width: AppSpacing.sm), widget.extra!],
            ],
          ),
        ),
      ],
    );
  }
}

/// The horizontally scrolling status chip row every merchant list opens
/// with.
class BusinessStatusChips extends StatelessWidget {
  const BusinessStatusChips({super.key, required this.options, required this.selected, required this.onSelected});

  final List<(String, String)> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Row(
        children: [
          for (final (value, label) in options) ...[
            ChoiceChip(
              label: Text(label),
              selected: value == selected,
              selectedColor: AppColors.businessTintStrong,
              labelStyle: textTheme.labelMedium?.copyWith(color: value == selected ? AppColors.businessInk : AppColors.textSecondary),
              side: BorderSide(color: value == selected ? AppColors.businessInk : AppColors.border),
              showCheckmark: false,
              onSelected: (_) => onSelected(value),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

/// The date-range control: a menu of the quick [ListRange]s and, when
/// [onCustomRange] is given, a "Custom dates…" entry that opens the
/// platform date-range picker (the web's from/to inputs, as one sheet).
class BusinessRangeMenu extends StatelessWidget {
  const BusinessRangeMenu({super.key, required this.range, required this.onRangeChanged, this.customLabel, this.onCustomRange});

  final ListRange range;
  final ValueChanged<ListRange> onRangeChanged;

  /// Shown instead of the quick range's label while a custom window is
  /// active.
  final String? customLabel;
  final void Function(DateTime from, DateTime to)? onCustomRange;

  static const _customValue = 'custom';

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Filter by date',
      saveText: 'Apply',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.businessInk)),
        child: child!,
      ),
    );
    if (picked != null) onCustomRange?.call(picked.start, picked.end);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final active = customLabel != null || range != ListRange.all;
    final label = customLabel ?? (range == ListRange.all ? 'Any date' : range.label);

    return PopupMenuButton<Object>(
      tooltip: 'Date range',
      initialValue: customLabel == null ? range : _customValue,
      onSelected: (value) {
        if (value == _customValue) {
          _pickCustom(context);
        } else if (value is ListRange) {
          onRangeChanged(value);
        }
      },
      itemBuilder: (context) => [
        for (final r in ListRange.values) PopupMenuItem<Object>(value: r, child: Text(r.label)),
        if (onCustomRange != null) ...[
          const PopupMenuDivider(),
          const PopupMenuItem<Object>(
            value: _customValue,
            child: Row(
              children: [
                Icon(Icons.edit_calendar_rounded, size: AppIconSize.md, color: AppColors.textSecondary),
                SizedBox(width: AppSpacing.sm),
                Text('Custom dates…'),
              ],
            ),
          ),
        ],
      ],
      child: Container(
        height: AppSize.field,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
          border: Border.all(color: active ? AppColors.businessInk : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.date_range_rounded, size: AppIconSize.md, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(label, style: textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.arrow_drop_down_rounded, size: AppIconSize.md, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
