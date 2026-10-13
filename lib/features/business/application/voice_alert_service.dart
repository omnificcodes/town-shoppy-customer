import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/storage/secure_storage_service.dart';
import 'business_context.dart';

/// The payment voice alert (BR-43 `voice_alert`): a spoken "Payment
/// received" like a UPI soundbox, read out by the phone whenever a bill is
/// recorded or approved. On per device (the counter phone), only while the
/// shop's plan carries the item.
class VoiceAlertService {
  VoiceAlertService(this._ref, this._storage);

  static const _storageKey = 'voice_alert_enabled';

  final Ref _ref;
  final SecureStorageService _storage;
  FlutterTts? _tts;
  bool _enabled = false;
  bool _loaded = false;

  bool get isEnabled => _enabled;

  Future<bool> load() async {
    if (_loaded) return _enabled;
    try {
      _enabled = (await _storage.read(_storageKey)) == '1';
    } catch (_) {
      _enabled = false;
    }
    _loaded = true;
    return _enabled;
  }

  Future<void> setEnabled(bool on) async {
    _enabled = on;
    _loaded = true;
    try {
      await _storage.write(_storageKey, on ? '1' : '0');
    } catch (_) {
      // A storage hiccup only loses the preference, never the alert.
    }
    if (on) await speak('Voice alert is on. You will hear every payment.');
  }

  /// Whether the alert may play right now: switched on here, and the plan has it.
  bool get _allowed {
    if (!_enabled) return false;
    final entitlement = _ref.read(merchantEntitlementProvider).value;
    return entitlement == null || entitlement.has('voice_alert');
  }

  /// "Payment received. 300 rupees from Asha."
  Future<void> announcePayment({required double amount, String? customerName}) async {
    if (!_allowed) return;
    final rupees = amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
    final who = (customerName ?? '').trim();
    await speak('Payment received. $rupees rupees${who.isEmpty ? '' : ' from $who'}.');
  }

  /// "Coins redeemed. 50 rupees off."
  Future<void> announceRedemption({required double discountAmount}) async {
    if (!_allowed || discountAmount <= 0) return;
    await speak('Coins redeemed. ${discountAmount.toStringAsFixed(0)} rupees off.');
  }

  Future<void> speak(String text) async {
    try {
      final tts = _tts ??= await _create();
      await tts.stop();
      await tts.speak(text);
    } catch (e) {
      // Text-to-speech is unavailable on some devices and on the web
      // build's test runner; a silent miss is better than a crash at the counter.
      debugPrint('[voice-alert] $e');
    }
  }

  Future<FlutterTts> _create() async {
    final tts = FlutterTts();
    try {
      await tts.setLanguage('en-IN');
      await tts.setSpeechRate(0.5);
      await tts.setVolume(1.0);
    } catch (_) {
      // Keep the engine's defaults where a setting is unsupported.
    }
    return tts;
  }
}

final voiceAlertServiceProvider = Provider<VoiceAlertService>((ref) {
  return VoiceAlertService(ref, ref.watch(secureStorageServiceProvider));
});

/// The on/off shown in Security: loaded once from storage, then kept in step.
final voiceAlertEnabledProvider = FutureProvider<bool>((ref) => ref.watch(voiceAlertServiceProvider).load());
