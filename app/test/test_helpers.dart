import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/storage/preferences_provider.dart';
import 'package:khidma/app.dart';
import 'package:khidma/core/theme/app_theme.dart';
import 'package:khidma/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the full app with mock preferences and returns its container.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  // Tests start past onboarding unless they say otherwise.
  SharedPreferences.setMockInitialValues({'onboardingSeen': true, ...prefs});
  final sp = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [keyValueStoreProvider.overrideWithValue(PrefsStore(sp))],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const KhidmaApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Direction of the visible screen.
TextDirection screenDirection(WidgetTester tester) =>
    Directionality.of(tester.element(find.byType(Scaffold).first));

/// A bare MaterialApp (localized, themed, no router) showing [home]. Animations
/// are disabled so repeating shimmers do not keep the test busy.
Widget bareApp(Widget home, {String lang = 'fr', bool dark = false}) {
  final locale = Locale(lang);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    supportedLocales: const [Locale('fr'), Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: dark ? AppTheme.dark(locale) : AppTheme.light(locale),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: home,
  );
}

/// Loads the bundled fonts so tests measure and paint real glyphs instead of
/// the test engine's wide placeholder font. Call from setUpAll.
Future<void> loadAppFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }

  // Icons: without this the test engine paints every icon as a square.
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();

  await load('Inter', ['Inter.ttf']);
  await load('IBMPlexSansArabic', [
    'IBMPlexSansArabic-Regular.ttf',
    'IBMPlexSansArabic-Medium.ttf',
    'IBMPlexSansArabic-SemiBold.ttf',
    'IBMPlexSansArabic-Bold.ttf',
  ]);
}
