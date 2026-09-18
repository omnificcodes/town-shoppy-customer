import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// What the Business scanner is being asked to read -- shown as the title
/// and the hint under the viewfinder.
class BusinessScanArgs {
  const BusinessScanArgs({required this.title, required this.hint});

  final String title;
  final String hint;

  static const customerQr = BusinessScanArgs(
    title: 'Scan customer QR',
    hint: "Point the camera at the QR code in the customer's Town Shoppy app.",
  );

  static const redemptionQr = BusinessScanArgs(
    title: 'Scan redemption QR',
    hint: "Point the camera at the redemption QR on the customer's screen.",
  );
}

/// Full-screen camera scanner for the merchant side. Pops with the raw
/// decoded string (`context.pop<String>`), so any form can `await
/// context.push(...)` and read the result -- the same camera chrome the
/// customer's `ScanMerchantQrScreen` has, generalised.
class BusinessQrScanScreen extends StatefulWidget {
  const BusinessQrScanScreen({super.key, required this.args});

  final BusinessScanArgs args;

  @override
  State<BusinessQrScanScreen> createState() => _BusinessQrScanScreenState();
}

class _BusinessQrScanScreenState extends State<BusinessQrScanScreen> {
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
    context.pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scrim,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.onScrim,
        titleTextStyle: AppTypography.sectionTitle.copyWith(color: AppColors.onScrim),
        title: Text(widget.args.title),
        actions: [
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
            placeholderBuilder: (context) => const ColoredBox(
              color: AppColors.scrim,
              child: Center(child: CircularProgressIndicator(color: AppColors.onScrim, semanticsLabel: 'Starting camera')),
            ),
            errorBuilder: (context, error) => _ScannerErrorView(error: error),
          ),
          ExcludeSemantics(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.orange, width: 3),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                child: Text(
                  widget.args.hint,
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

class _ScannerErrorView extends StatelessWidget {
  const _ScannerErrorView({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: AppColors.scrim,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_rounded, color: AppColors.onScrimMuted, size: AppIconSize.display),
            const SizedBox(height: AppSpacing.md),
            Text(denied ? 'Camera access is off' : 'Camera unavailable',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.onScrim), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              denied
                  ? 'Town Shoppy needs camera access to scan codes at the counter. Enable it in your device Settings, then come back.'
                  : 'This device could not start the camera. You can go back and type the code instead.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.onScrimMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.onScrim, side: const BorderSide(color: AppColors.onScrimMuted), minimumSize: const Size(0, AppSize.controlMd)),
              onPressed: () => context.pop(),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}
