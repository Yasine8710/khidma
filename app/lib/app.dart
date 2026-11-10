import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/locale_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'core/router/app_routes.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/notifications/application/notifications_providers.dart';
import 'features/profile/application/profile_providers.dart';
import 'l10n/generated/app_localizations.dart';

class KhidmaApp extends ConsumerWidget {
  const KhidmaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    ref.watch(accountSetupProvider);
    ref.watch(pushRegistrationProvider);
    // Opening a password-reset link brings the user to the new-password screen.
    ref.listen(passwordRecoveryProvider, (_, next) {
      if (next.hasValue) ref.read(routerProvider).go(AppRoutes.resetPassword);
    });
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(locale),
      darkTheme: AppTheme.dark(locale),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
