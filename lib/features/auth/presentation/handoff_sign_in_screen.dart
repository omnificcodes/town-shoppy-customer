import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_mode/app_mode.dart';
import '../../../core/app_mode/app_mode_controller.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/state_panel.dart';
import '../application/auth_controller.dart';

/// Landing page for a Super Admin's "Login as customer" link
/// (`/impersonate?code=…`). Trades the single-use code for a session and
/// drops the admin on Home as that customer. There is nothing to type and
/// nothing to choose — it either works, or says why and offers the normal
/// login instead. The code is never shown, logged, or kept: a reload after
/// success simply finds the stored session, and a reload after failure
/// finds a code the server has already burned.
class HandoffSignInScreen extends ConsumerStatefulWidget {
  const HandoffSignInScreen({super.key, required this.code});

  final String? code;

  @override
  ConsumerState<HandoffSignInScreen> createState() => _HandoffSignInScreenState();
}

class _HandoffSignInScreenState extends ConsumerState<HandoffSignInScreen> {
  AppException? _error;

  @override
  void initState() {
    super.initState();
    // After the first frame: signing in changes auth state, which the
    // router listens to, and that must not happen during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _signIn());
  }

  Future<void> _signIn() async {
    final code = widget.code;
    if (code == null || code.isEmpty) {
      setState(() => _error = const NotFoundException('This sign-in link is incomplete.'));
      return;
    }

    try {
      await ref.read(authControllerProvider.notifier).signInWithHandoffCode(code);
      // This link is "login as CUSTOMER": a customer who also owns a shop
      // must not land in the mode chooser or the Business app.
      await ref.read(appModeControllerProvider.notifier).select(AppMode.customer);
      if (mounted) context.go('/home');
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  /// A burned or expired code comes back as a 422 whose useful sentence is
  /// the field error, not the generic envelope message.
  static String _messageFor(AppException error) {
    if (error is ValidationAppException) {
      final first = error.fieldErrors.values.expand((m) => m).firstOrNull;
      if (first != null) return first;
    }
    return error.message;
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;

    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      body: SafeArea(
        child: error == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox.square(
                      dimension: AppIconSize.lg,
                      child: CircularProgressIndicator(strokeWidth: 2.5, semanticsLabel: 'Signing in'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('Signing you in…', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              )
            : StatePanel(
                icon: Icons.link_off_rounded,
                iconColor: AppColors.error,
                title: 'This sign-in link did not work',
                message: _messageFor(error),
                action: FilledButton(onPressed: () => context.go('/login'), child: const Text('Go to login')),
              ),
      ),
    );
  }
}
