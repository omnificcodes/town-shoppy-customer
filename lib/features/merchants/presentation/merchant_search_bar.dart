import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// A name search field plus a filter button that opens a real, backend-
/// backed toggle (`accepts_town_coin` — see `MerchantsRepository`'s own
/// docblock) — deliberately not a "Sort by" control, since `GET /merchants`
/// only ever orders by name and has no popularity/rating concept to sort
/// on for real.
class MerchantSearchBar extends StatefulWidget {
  const MerchantSearchBar({
    super.key,
    required this.onSearchChanged,
    required this.acceptsTownCoinOnly,
    required this.onToggleAcceptsTownCoin,
  });

  final ValueChanged<String> onSearchChanged;
  final bool acceptsTownCoinOnly;
  final ValueChanged<bool> onToggleAcceptsTownCoin;

  @override
  State<MerchantSearchBar> createState() => _MerchantSearchBarState();
}

class _MerchantSearchBarState extends State<MerchantSearchBar> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => widget.onSearchChanged(value));
  }

  Future<void> _openFilters() async {
    var accepted = widget.acceptsTownCoinOnly;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filters', style: Theme.of(sheetContext).textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: accepted,
                  onChanged: (value) {
                    setSheetState(() => accepted = value);
                    widget.onToggleAcceptsTownCoin(value);
                  },
                  title: const Text('Accepts Town Coin'),
                  subtitle: const Text('Only show merchants where you can redeem Town Coin.'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filterActive = widget.acceptsTownCoinOnly;
    final fieldRadius = BorderRadius.circular(AppSpacing.radiusMd);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search merchants or categories',
                prefixIcon: const Icon(Icons.search_rounded, size: AppIconSize.md, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: fieldRadius,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: fieldRadius,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: fieldRadius,
                  borderSide: const BorderSide(color: AppColors.orangeDeep, width: 1.5),
                ),
                // Real vertical padding (the theme's own field height), not
                // zero: a zero-height content box clipped the hint and the
                // typed text at 1.3x system text scale.
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            button: true,
            label: filterActive ? 'Filters, Accepts Town Coin on' : 'Filters',
            child: Material(
              color: filterActive ? AppColors.orangeDeep : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: fieldRadius,
                side: BorderSide(color: filterActive ? AppColors.orangeDeep : AppColors.border),
              ),
              child: InkWell(
                customBorder: RoundedRectangleBorder(borderRadius: fieldRadius),
                onTap: _openFilters,
                child: SizedBox(
                  width: AppSize.controlMd,
                  height: AppSize.controlMd,
                  child: Icon(
                    Icons.filter_alt_outlined,
                    color: filterActive ? AppColors.onCrimson : AppColors.textPrimary,
                    size: AppIconSize.lg,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
