import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:khidma/core/l10n/locale_controller.dart';
import 'package:khidma/core/router/app_router.dart';
import 'package:khidma/core/router/app_routes.dart';
import 'package:khidma/core/theme/app_theme.dart';
import 'package:khidma/core/theme/theme_mode_controller.dart';
import 'package:khidma/l10n/generated/app_localizations.dart';
import 'package:khidma/shared/widgets/app_shell.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../test_helpers.dart';

GoRouter _router(ProviderContainer c) => c.read(routerProvider);

String _location(GoRouter r) => r.routerDelegate.currentConfiguration.uri.path;

void main() {
  testWidgets('starts on Home with four tabs', (tester) async {
    final c = await pumpApp(tester);
    expect(_location(_router(c)), AppRoutes.home);
    for (final label in ['Accueil', 'Demandes', 'Messages', 'Profil']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Les professionnels arrivent bientôt'), findsOneWidget);
  });

  testWidgets('each tab opens its screen', (tester) async {
    final c = await pumpApp(tester);
    final expected = {
      'Demandes': ('Aucune demande pour l\'instant', AppRoutes.requests),
      'Messages': ('Aucun message', AppRoutes.messages),
      'Profil': ('Choisir la langue', AppRoutes.profile),
      'Accueil': ('Les professionnels arrivent bientôt', AppRoutes.home),
    };
    for (final e in expected.entries) {
      await tester.tap(find.text(e.key));
      await tester.pumpAndSettle();
      expect(find.text(e.value.$1), findsOneWidget, reason: e.key);
      expect(_location(_router(c)), e.value.$2, reason: e.key);
    }
  });

  testWidgets('selected tab is exposed to accessibility', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester);
    final home = tester.getSemantics(find.bySemanticsLabel('Accueil'));
    expect(
      home,
      isSemantics(
        label: 'Accueil',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    final others = tester.getSemantics(find.bySemanticsLabel('Demandes'));
    expect(
      others,
      isSemantics(label: 'Demandes', isButton: true, hasTapAction: true),
    );
    expect(others, isNot(isSemantics(isSelected: true)));
    handle.dispose();
  });

  testWidgets('unknown route shows not-found with a way home', (tester) async {
    final c = await pumpApp(tester);
    _router(c).go('/nope');
    await tester.pumpAndSettle();
    expect(find.text('Page introuvable'), findsOneWidget);
    await tester.tap(find.text('Retour à l\'accueil'));
    await tester.pumpAndSettle();
    expect(_location(_router(c)), AppRoutes.home);
  });

  testWidgets('RTL mirrors tab order', (tester) async {
    await pumpApp(tester, prefs: {'locale': 'ar'});
    final home = tester.getCenter(find.text('الرئيسية')).dx;
    final profile = tester.getCenter(find.text('حسابي')).dx;
    expect(home, greaterThan(profile));
  });

  testWidgets('theme mode is saved and applied', (tester) async {
    final c = await pumpApp(tester);
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sombre'));
    await tester.pumpAndSettle();
    expect(c.read(themeModeProvider), ThemeMode.dark);
    expect(c.read(sharedPreferencesProvider).getString('themeMode'), 'dark');
    final brightness = Theme.of(tester.element(find.byType(Scaffold).first))
        .brightness;
    expect(brightness, Brightness.dark);
  });

  testWidgets('tabs keep their state while hidden', (tester) async {
    var builds = 0;
    final router = GoRouter(
      initialLocation: '/a',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => AppShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/a',
                  builder: (_, _) => _Counter(() => builds++),
                ),
              ],
            ),
            for (final p in ['/b', '/c', '/d'])
              StatefulShellBranch(
                routes: [GoRoute(path: p, builder: (_, _) => const SizedBox())],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(const Locale('fr')),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('+'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Demandes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(builds, 1, reason: 'branch state must not be recreated');
  });
}

class _Counter extends StatefulWidget {
  const _Counter(this.onInit);
  final VoidCallback onInit;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;

  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$n'),
        TextButton(
          onPressed: () => setState(() => n++),
          child: const Text('+'),
        ),
      ],
    ),
  );
}
