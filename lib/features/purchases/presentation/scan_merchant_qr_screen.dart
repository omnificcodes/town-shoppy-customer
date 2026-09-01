import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/customer_purchase_request_controller.dart';

/// Method 1, step 1 (3-way purchase architecture): full-screen camera scan
/// of a merchant/branch's permanent Purchase QR. On a successful decode,
/// resolves the token through [CustomerPurchaseRequestController] and
/// pushes to [RequestPurchaseScreen] once resolution succeeds -- the
/// customer never types or edits a merchant/branch, only what the camera
/// actually saw. An invalid/revoked/wrong-type token surfaces on that next
/// screen (it already renders [ErrorState] for a failed resolution); this
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
    _controller.stop();

    ref.read(customerPurchaseRequestControllerProvider.notifier).resolveScannedToken(value);
    context.pushReplacement('/purchases/request');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scan merchant QR'),
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
          _ScannerOverlay(),
          Positioned(
            left: 0,
            right: 0,
            bottom: AppSpacing.xl,
            child: Text(
              'Point your camera at the Purchase QR displayed at the counter.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.orange, width: 3),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
      color: Colors.black,
      child: Center(child: CircularProgressIndicator(color: Colors.white)),
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
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_rounded, color: Colors.white70, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              isPermissionDenied ? 'Camera access is off' : 'Camera unavailable',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isPermissionDenied
                  ? 'Town Shoppy needs camera access to scan a Purchase QR. Enable it in your device Settings, then come back.'
                  : 'This device could not start the camera. You can try again, or go back and try a different way to pay.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
              onPressed: () => context.pop(),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}
