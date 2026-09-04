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
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search merchants or categories',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surfaceMuted,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Material(
            color: widget.acceptsTownCoinOnly ? AppColors.orange : AppColors.surfaceMuted,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _openFilters,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  Icons.tune_rounded,
                  color: widget.acceptsTownCoinOnly ? AppColors.onOrange : AppColors.textPrimary,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
