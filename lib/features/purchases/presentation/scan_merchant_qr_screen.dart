import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Method 1, step 1 (3-way purchase architecture): full-screen camera scan
/// of a merchant/branch's permanent Purchase QR. On a successful decode,
/// hands the raw token to [RequestPurchaseScreen] (as route `extra`), which
/// resolves it -- the resolve itself happens on the screen that will
/// display its result, not here, so the autoDispose controller behind it
/// is never read-then-abandoned mid-flight across a navigation. The
/// customer never types or edits a merchant/branch, only what the camera
/// actually saw. An invalid/revoked/wrong-type token surfaces on that next
/// screen (it already renders an error panel for a failed resolution); this
/// screen's own job is only the camera itself -- permission denial,
/// unsupported hardware, and the brief moment before the camera is ready
/// all get an explicit state here, never a blank screen.
class ScanMerchantQrScreen extends ConsumerStatefulWidget {
  const ScanMerchantQrScreen({super.key});

  @override
  ConsumerState<ScanMerchantQrScreen> createState() => _ScanMerchantQrScreenState();
}

class _ScanMerchantQrScreenState extends ConsumerState<ScanMerchantQrScreen> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;

    _handled = true;
    HapticFeedback.mediumImpact();
    _controller.stop();

    context.pushReplacement('/purchases/request', extra: value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scrim,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.onScrim,
        title: const Text('Scan merchant QR'),
        actions: [
          // Dim counters are the common case for a printed QR -- the torch
          // is the one control worth putting on the scanner itself.
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final isOn = state.torchState == TorchState.on;
              return IconButton(
                icon: Icon(isOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded),
                tooltip: isOn ? 'Turn flashlight off' : 'Turn flashlight on',
                onPressed: state.torchState == TorchState.unavailable ? null : _controller.toggleTorch,
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            placeholderBuilder: (context) => const _ScannerPlaceholder(),
            errorBuilder: (context, error) => _ScannerErrorView(error: error),
          ),
          const _ScannerOverlay(key: ValueKey('scanner-overlay')),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                child: Text(
                  'Point your camera at the Purchase QR displayed at the counter.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onScrim),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The viewfinder frame. Purely decorative: the scanner reads the whole
/// camera feed, the frame only tells the customer where to aim.
class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({super.key});

  static const double _viewfinderSize = 260;
  static const double _borderWidth = 3;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Center(
        child: Container(
          width: _viewfinderSize,
          height: _viewfinderSize,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.orange, width: _borderWidth),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
    );
  }
}

class _ScannerPlaceholder extends StatelessWidget {
  const _ScannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.scrim,
      child: Center(child: CircularProgressIndicator(color: AppColors.onScrim, semanticsLabel: 'Starting camera')),
    );
  }
}

/// Camera-permission-denied, unsupported hardware, or any other startup
/// failure -- never a blank black screen. `permissionDenied` gets its own
/// copy pointing the customer at Settings, since this app has no in-flow
/// way to re-trigger the OS permission prompt once denied.
class _ScannerErrorView extends StatelessWidget {
  const _ScannerErrorView({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final isPermissionDenied = error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: AppColors.scrim,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_rounded, color: AppColors.onScrimMuted, size: AppIconSize.display),
            const SizedBox(height: AppSpacing.md),
            Text(
              isPermissionDenied ? 'Camera access is off' : 'Camera unavailable',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.onScrim),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isPermissionDenied
                  ? 'Town Shoppy needs camera access to scan a Purchase QR. Enable it in your device Settings, then come back.'
                  : 'This device could not start the camera. You can try again, or go back and try a different way to pay.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onScrimMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onScrim,
                side: const BorderSide(color: AppColors.onScrimMuted),
                minimumSize: const Size(0, AppSize.controlMd),
              ),
              onPressed: () => context.pop(),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}
