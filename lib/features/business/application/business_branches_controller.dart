import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/merchant_branches_repository.dart';
import '../data/models/merchant_branch.dart';
import 'business_context.dart';

/// All of the merchant's branches, primary first then A-Z (the backend's
/// fixed order). Mutations re-fetch the whole list rather than patching a
/// row: promoting a primary demotes another row, so a single-row update
/// would leave the list lying.
class BusinessBranchesController extends AsyncNotifier<List<MerchantBranch>> {
  @override
  Future<List<MerchantBranch>> build() async {
    ref.watch(sessionEpochProvider);
    final merchantId = ref.watch(myMerchantIdProvider);
    if (merchantId == null) return const [];
    return ref.watch(merchantBranchesRepositoryProvider).list(merchantId: merchantId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<MerchantBranch> create(BranchInput input) async {
    final merchantId = ref.read(myMerchantIdProvider)!;
    final created = await ref.read(merchantBranchesRepositoryProvider).create(merchantId: merchantId, input: input);
    await refresh();
    _invalidateDependents();
    return created;
  }

  /// Named `patch`, not `update`: AsyncNotifier already has an `update`.
  Future<MerchantBranch> patch(int branchId, Map<String, dynamic> fields) async {
    final updated = await ref.read(merchantBranchesRepositoryProvider).update(branchId, fields);
    await refresh();
    _invalidateDependents();
    return updated;
  }

  Future<MerchantBranch> setPrimary(int branchId) => patch(branchId, {'is_primary': true});

  Future<MerchantBranch> setStatus(int branchId, {required bool active}) => patch(branchId, {'status': active ? 'active' : 'inactive'});

  /// The dashboard's identity band shows the primary branch address and
  /// the profile screen lists it -- both come from `GET /merchants/{id}`.
  void _invalidateDependents() => ref.invalidate(myMerchantProvider);
}

final businessBranchesControllerProvider =
    AsyncNotifierProvider<BusinessBranchesController, List<MerchantBranch>>(BusinessBranchesController.new);

/// Active branches only -- what Direct POS lets the merchant pick from.
final activeBranchesProvider = Provider<List<MerchantBranch>>((ref) {
  return (ref.watch(businessBranchesControllerProvider).value ?? const []).where((b) => b.isActive).toList();
});

/// A branch's permanent Purchase QR token: `null` until generated (or
/// after a revoke). Generate/regenerate replaces it in place.
class BranchQrController extends AsyncNotifier<String?> {
  // Riverpod 3 family notifiers receive their argument via the constructor.
  BranchQrController(this._branchId);

  final int _branchId;

  @override
  Future<String?> build() async {
    ref.watch(sessionEpochProvider);
    return ref.watch(merchantBranchesRepositoryProvider).purchaseQr(_branchId);
  }

  Future<void> generate() async {
    final token = await ref.read(merchantBranchesRepositoryProvider).generatePurchaseQr(_branchId);
    state = AsyncData(token);
  }

  Future<void> revoke() async {
    await ref.read(merchantBranchesRepositoryProvider).revokePurchaseQr(_branchId);
    state = const AsyncData(null);
  }
}

final branchQrProvider = AsyncNotifierProvider.family<BranchQrController, String?, int>(BranchQrController.new);
