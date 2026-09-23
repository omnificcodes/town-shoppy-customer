import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notifications/application/push_notification_service.dart';
import 'shared/widgets/web_phone_frame.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  _configureWebScanner();
  runApp(const ProviderScope(child: TownShoppyApp()));
}

/// mobile_scanner's web "auto" default prefers the browser's native
/// BarcodeDetector API when it reports support, which is Safari 17+ as
/// well as Chrome/Edge. Safari's implementation is real but unreliable in
/// practice -- it silently returns zero results against a live camera feed
/// far more often than it should, which reads as "the camera opens but
/// never detects the code" (reported against Direct POS's "Scan customer
/// QR" on iPhone Safari; every non-camera part of the pipeline -- route,
/// button, onDetect -- checked out fine). Forcing zxing-wasm sidesteps the
/// native API everywhere on web, trading a one-time ~600KB CDN fetch
/// (cached after) for the same decoder on every browser, including the
/// Chrome/Edge path that already worked -- never a regression there, only
/// removes the Safari-specific failure mode.
void _configureWebScanner() {
  if (!kIsWeb) return;
  MobileScannerPlatform.instance.setWebBarcodeReader(WebBarcodeReader.zxingWasm);
}

/// Wrapped in its own try/catch, deliberately: this repo has no
/// `google-services.json`/`GoogleService-Info.plist` until a Firebase
/// project exists for it (see PushNotificationService's own doc comment),
/// so `Firebase.initializeApp()` throws on every build until then. The
/// rest of the app must keep working exactly as it does today either way
/// — push is the one thing that silently stays off, never a reason the
/// app fails to start.
Future<void> _initializeFirebase() async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;

  try {
    await Firebase.initializeApp();
    // Required by firebase_messaging before any message can be received
    // while the app is backgrounded or fully terminated — see the
    // handler's own doc comment for why it deliberately does almost
    // nothing.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (_) {
    // Firebase not configured yet, or unavailable on this device — push
    // stays off; nothing else about the app is affected.
  }
}

class TownShoppyApp extends ConsumerStatefulWidget {
  const TownShoppyApp({super.key});

  @override
  ConsumerState<TownShoppyApp> createState() => _TownShoppyAppState();
}

class _TownShoppyAppState extends ConsumerState<TownShoppyApp> {
  @override
  void initState() {
    super.initState();
    // Wires up the foreground/opened-app/token-refresh listeners
    // immediately (PushNotificationService.build() runs the moment this
    // provider is first read), then checks whether THIS launch was
    // triggered by tapping a push notification while the app was fully
    // terminated -- the only way to learn that.
    ref.read(pushNotificationServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pushNotificationServiceProvider.notifier).handleInitialMessage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Town Shoppy',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      // Web-only: letterboxes a wide browser window into a phone-width
      // frame. A no-op on Android/iOS -- see WebPhoneFrame's doc comment.
      builder: (context, child) => WebPhoneFrame(child: child),
    );
  }
}
