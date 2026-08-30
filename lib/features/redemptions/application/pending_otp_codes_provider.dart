import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds a just-created redemption's one-time OTP code in memory only, for
/// exactly one read — `POST /redemptions` is the only response that ever
/// carries it; no later GET can retrieve it again, so this must never be
/// written to secure storage, logs, or analytics. [consume] removes it
/// immediately after the verification screen reads it once.
class PendingOtpCodes extends Notifier<Map<int, String>> {
  @override
  Map<int, String> build() => {};

  void stash(int redemptionId, String code) => state = {...state, redemptionId: code};

  String? consume(int redemptionId) {
    final code = state[redemptionId];
    if (code != null) {
      final next = Map<int, String>.from(state)..remove(redemptionId);
      state = next;
    }
    return code;
  }
}

final pendingOtpCodesProvider = NotifierProvider<PendingOtpCodes, Map<int, String>>(PendingOtpCodes.new);
