import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/business_offers_controller.dart';
import '../../data/models/business_offer.dart';
import '../business_routes.dart';
import '../widgets/business_dialogs.dart';

/// The Owner's actions on one offer, as a bottom sheet -- the mobile form
/// of the web's row menu. Mirrors `OfferStatus::allowedNextStates()`:
/// draft -> edit / publish / withdraw; active -> end; expired -> nothing.
Future<void> showOfferActionsSheet(BuildContext context, WidgetRef ref, BusinessOffer offer) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.sm),
            child: Align(alignment: Alignment.centerLeft, child: Text(offer.title, style: Theme.of(sheetContext).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ),
          if (offer.isDraft) ...[
            ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Edit'), onTap: () => Navigator.of(sheetContext).pop('edit')),
            ListTile(leading: const Icon(Icons.send_rounded, color: AppColors.success), title: const Text('Publish'), subtitle: const Text('Make it visible to customers'), onTap: () => Navigator.of(sheetContext).pop('publish')),
            ListTile(leading: const Icon(Icons.block_rounded, color: AppColors.error), title: const Text('Withdraw', style: TextStyle(color: AppColors.error)), onTap: () => Navigator.of(sheetContext).pop('withdraw')),
          ],
          if (offer.isActive)
            ListTile(leading: const Icon(Icons.stop_circle_outlined, color: AppColors.error), title: const Text('End offer', style: TextStyle(color: AppColors.error)), onTap: () => Navigator.of(sheetContext).pop('end')),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  await runOfferAction(context, ref, offer, action);
}

Future<void> runOfferAction(BuildContext context, WidgetRef ref, BusinessOffer offer, String action) async {
  final controller = ref.read(businessOffersControllerProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  try {
    switch (action) {
      case 'edit':
        context.push('${BusinessRoutes.offers}/${offer.id}/edit', extra: offer);
      case 'publish':
        final ok = await showBusinessConfirmDialog(context, title: 'Publish this offer?', message: 'It will become visible to customers immediately.', confirmLabel: 'Publish');
        if (!ok) return;
        await controller.publish(offer.id);
        messenger.showSnackBar(const SnackBar(content: Text('Offer published.')));
      case 'withdraw':
        final reason = await showBusinessReasonDialog(context, title: 'Withdraw this offer?', message: 'A withdrawn offer never goes live and cannot be published later.', confirmLabel: 'Withdraw', placeholder: 'Optional context for this change');
        if (reason == null) return;
        await controller.withdraw(offer.id, reason: reason);
        messenger.showSnackBar(const SnackBar(content: Text('Offer withdrawn.')));
      case 'end':
        final reason = await showBusinessReasonDialog(context, title: 'End this offer?', message: 'Customers will stop seeing it right away. This cannot be undone.', confirmLabel: 'End offer', placeholder: 'Optional context for this change');
        if (reason == null) return;
        await controller.end(offer.id, reason: reason);
        messenger.showSnackBar(const SnackBar(content: Text('Offer ended.')));
    }
  } on AppException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}
