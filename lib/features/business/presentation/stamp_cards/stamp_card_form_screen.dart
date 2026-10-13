import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/info_box.dart';
import '../../../../shared/widgets/section_header.dart';
import '../../../stamp_cards/application/stamp_cards_providers.dart';
import '../../../stamp_cards/data/models/stamp_card.dart';
import '../../../stamp_cards/data/stamp_cards_repository.dart';
import '../../../stamp_cards/presentation/stamp_card_face.dart';
import '../../../stamp_cards/presentation/stamp_card_style.dart';
import '../../application/business_context.dart';
import '../business_routes.dart';
import '../widgets/business_page_header.dart';

/// Create or edit a stamp card: how many stamps, what the reward is, an
/// optional minimum bill per stamp, and a look -- with a live preview of
/// the card the customer will carry.
class StampCardFormScreen extends ConsumerStatefulWidget {
  const StampCardFormScreen({super.key, this.programme});

  /// Present when editing.
  final StampCardProgramme? programme;

  @override
  ConsumerState<StampCardFormScreen> createState() => _StampCardFormScreenState();
}

class _StampCardFormScreenState extends ConsumerState<StampCardFormScreen> {
  late final _title = TextEditingController(text: widget.programme?.title ?? '');
  late final _reward = TextEditingController(text: widget.programme?.rewardText ?? '');
  late final _minBill = TextEditingController(
    text: widget.programme?.minBillAmount != null ? _trim(widget.programme!.minBillAmount!) : '',
  );
  late int _stamps = widget.programme?.stampsRequired ?? 5;
  late String _icon = widget.programme?.icon ?? 'coffee';
  late bool _active = widget.programme?.isActive ?? true;

  bool _touched = false;
  bool _saving = false;
  AppException? _error;
  Map<String, List<String>> _fieldErrors = const {};

  bool get _isEdit => widget.programme != null;

  static String _trim(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [_title, _reward, _minBill]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _titleError => _title.text.trim().isEmpty ? 'Give the card a name, e.g. "Coffee lovers".' : null;
  String? get _rewardError => _reward.text.trim().isEmpty ? 'Say what the customer gets, e.g. "Free coffee".' : null;

  double? get _minBillValue => _minBill.text.trim().isEmpty ? null : double.tryParse(_minBill.text.trim());

  String? get _minBillError {
    if (_minBill.text.trim().isEmpty) return null;
    final v = _minBillValue;
    return v == null || v < 1 ? 'Enter an amount, or leave blank for any bill.' : null;
  }

  Future<void> _save() async {
    setState(() => _touched = true);
    if (_titleError != null || _rewardError != null || _minBillError != null) return;

    final input = StampCardInput(
      title: _title.text,
      stampsRequired: _stamps,
      rewardText: _reward.text,
      minBillAmount: _minBillValue,
      icon: _icon,
      status: _active ? 'active' : 'inactive',
    );

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      final repo = ref.read(stampCardsRepositoryProvider);
      final merchantId = ref.read(myMerchantIdProvider);
      if (!_isEdit && merchantId == null) return;
      if (_isEdit) {
        await repo.updateProgramme(widget.programme!.id, input);
      } else {
        await repo.createProgramme(merchantId!, input);
      }
      ref.invalidate(stampCardProgrammesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isEdit ? 'Stamp card updated.' : 'Stamp card created.')));
      context.go(BusinessRoutes.stampCards);
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e;
          _fieldErrors = e is ValidationAppException ? e.fieldErrors : const {};
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String? server(String f) => _fieldErrors[f]?.firstOrNull;
    String? show(String? local) => _touched ? local : null;
    final merchantName = ref.watch(myMerchantProvider).value?.name;
    final textTheme = Theme.of(context).textTheme;

    return BusinessScaffold(
      title: _isEdit ? 'Edit stamp card' : 'New stamp card',
      padded: false,
      bottomBar: AppButton(label: _isEdit ? 'Save changes' : 'Create card', isLoading: _saving, onPressed: _save),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          StampCardFace(
            title: _title.text.trim().isEmpty ? 'Card name' : _title.text.trim(),
            rewardText: _reward.text.trim().isEmpty ? 'Reward' : _reward.text.trim(),
            stampsRequired: _stamps,
            stampsCount: (_stamps * 0.6).floor(),
            icon: _icon,
            merchantName: merchantName ?? 'Your shop',
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Preview — how customers see it', style: AppTypography.caption, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'The offer', icon: Icons.loyalty_outlined),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'Card name',
            controller: _title,
            hintText: 'e.g. Coffee lovers',
            maxLength: 80,
            errorText: server('title') ?? show(_titleError),
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.smd),
          Text('Stamps to collect', style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          _Stepper(value: _stamps, min: 2, max: 20, onChanged: (v) => setState(() => _stamps = v)),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'Reward when the card is full',
            controller: _reward,
            hintText: 'e.g. Free coffee',
            maxLength: 120,
            errorText: server('reward_text') ?? show(_rewardError),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.smd),
          AppTextField(
            label: 'Minimum bill for a stamp (₹)',
            controller: _minBill,
            hintText: 'Any bill',
            helperText: 'Optional. Leave blank to stamp any bill.',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            errorText: server('min_bill_amount') ?? show(_minBillError),
          ),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader(title: 'Look', icon: Icons.palette_outlined),
          const SizedBox(height: AppSpacing.smd),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in StampCardStyle.all)
                _StyleChip(style: s, selected: s.key == _icon, onTap: () => setState(() => _icon = s.key)),
            ],
          ),
          if (_isEdit) ...[
            const SizedBox(height: AppSpacing.section),
            const SectionHeader(title: 'Availability', icon: Icons.visibility_outlined),
            const SizedBox(height: AppSpacing.xs),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Running'),
              subtitle: const Text('Switch off to stop stamping. Customers keep the stamps they have.'),
              value: _active,
              activeColor: AppColors.businessInk,
              onChanged: (v) => setState(() => _active = v),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            InfoBox(
              icon: Icons.error_outline_rounded,
              tone: AppTone.error,
              message: _fieldErrors.isEmpty ? _error!.message : 'Please fix the highlighted fields.',
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.min, required this.max, required this.onChanged});

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
            tooltip: 'Fewer stamps',
          ),
          Expanded(
            child: Text(
              '$value stamps',
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'More stamps',
          ),
        ],
      ),
    );
  }
}

class _StyleChip extends StatelessWidget {
  const _StyleChip({required this.style, required this.selected, required this.onTap});

  final StampCardStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${style.label} look',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xs, AppSpacing.smd, AppSpacing.xs),
          decoration: BoxDecoration(
            color: selected ? AppColors.businessTint : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            border: Border.all(color: selected ? AppColors.businessInk : AppColors.border, width: selected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: style.gradient, shape: BoxShape.circle),
                child: Text(style.emoji, style: const TextStyle(fontSize: 15)),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(style.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
