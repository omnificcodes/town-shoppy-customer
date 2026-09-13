import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/web_phone_frame.dart';

void main() {
  runApp(const ProviderScope(child: TownShoppyApp()));
}

class TownShoppyApp extends ConsumerWidget {
  const TownShoppyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
