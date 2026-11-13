import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khidma/core/format/rating.dart';
import 'package:khidma/core/theme/app_theme.dart';
import 'package:khidma/l10n/generated/app_localizations.dart';
import 'package:khidma/shared/widgets/app_avatar.dart';
import 'package:khidma/shared/widgets/app_badge.dart';
import 'package:khidma/shared/widgets/app_button.dart';
import 'package:khidma/shared/widgets/app_card.dart';
import 'package:khidma/shared/widgets/app_chip.dart';
import 'package:khidma/shared/widgets/app_text_field.dart';
import 'package:khidma/shared/widgets/error_state.dart';
import 'package:khidma/shared/widgets/rating_stars.dart';
import 'package:khidma/shared/widgets/section_header.dart';
import 'package:khidma/shared/widgets/skeleton.dart';

import '../test_helpers.dart';

Widget host(
  Widget child, {
  String lang = 'fr',
  bool dark = false,
  bool disableAnimations = false,
}) {
  final locale = Locale(lang);
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('fr'), Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: dark ? AppTheme.dark(locale) : AppTheme.light(locale),
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(disableAnimations: disableAnimations),
      child: c!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}

double _ratio(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  setUpAll(loadAppFonts);

  group('AppButton', () {
    testWidgets('fires onPressed once per tap', (tester) async {
      var n = 0;
      await tester.pumpWidget(
        host(AppButton(label: 'Envoyer', onPressed: () => n++)),
      );
      await tester.tap(find.text('Envoyer'));
      expect(n, 1);
    });

    testWidgets('loading ignores taps and announces loading', (tester) async {
      final handle = tester.ensureSemantics();
      var n = 0;
      await tester.pumpWidget(
        host(
          AppButton(label: 'Envoyer', onPressed: () => n++, isLoading: true),
        ),
      );
      await tester.tap(find.text('Envoyer'), warnIfMissed: false);
      expect(n, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The spinner's label merges into the (disabled) button's own node.
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Envoyer')),
      );
      expect(node.label, contains('Chargement'));
      expect(
        node,
        isSemantics(isButton: true, isEnabled: false, hasEnabledState: true),
      );
      handle.dispose();
    });

    testWidgets('null onPressed is disabled', (tester) async {
      await tester.pumpWidget(
        host(const AppButton(label: 'Envoyer', onPressed: null)),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('all variants render with 48+ tap targets', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          Column(
            children: [
              AppButton(label: 'A', onPressed: () {}),
              AppButton(
                label: 'B',
                onPressed: () {},
                variant: AppButtonVariant.secondary,
                icon: Icons.phone,
              ),
              AppButton(
                label: 'C',
                onPressed: () {},
                variant: AppButtonVariant.text,
              ),
            ],
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  group('AppTextField', () {
    testWidgets('shows label, hint and validator error', (tester) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(
        host(
          Form(
            key: key,
            child: AppTextField(
              label: 'Téléphone',
              hint: '20 123 456',
              validator: (v) => (v ?? '').isEmpty ? 'Obligatoire' : null,
            ),
          ),
        ),
      );
      expect(find.text('Téléphone'), findsOneWidget);
      expect(find.text('20 123 456'), findsOneWidget);
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Obligatoire'), findsOneWidget);
    });

    testWidgets('password toggle shows and hides with localized tooltip', (
      tester,
    ) async {
      final c = TextEditingController(text: 'secret');
      await tester.pumpWidget(
        host(
          AppTextField(label: 'Mot de passe', controller: c, obscureText: true),
        ),
      );
      EditableText field() =>
          tester.widget<EditableText>(find.byType(EditableText));
      expect(field().obscureText, isTrue);
      expect(find.byTooltip('Afficher le mot de passe'), findsOneWidget);
      await tester.tap(find.byTooltip('Afficher le mot de passe'));
      await tester.pump();
      expect(field().obscureText, isFalse);
      expect(find.byTooltip('Masquer le mot de passe'), findsOneWidget);
    });

    testWidgets('password toggle is its own actionable node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(const AppTextField(label: 'Mot de passe', obscureText: true)),
      );
      expect(
        tester.getSemantics(find.byTooltip('Afficher le mot de passe')),
        isSemantics(isButton: true, hasTapAction: true),
      );
      expect(find.bySemanticsLabel(RegExp('Mot de passe')), findsWidgets);
      handle.dispose();
    });

    testWidgets('disabled field disables the password toggle', (tester) async {
      await tester.pumpWidget(
        host(
          const AppTextField(
            label: 'Mot de passe',
            obscureText: true,
            enabled: false,
          ),
        ),
      );
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
    });

    testWidgets('obscureText change re-syncs the toggle state', (tester) async {
      Widget field(bool o) => host(AppTextField(label: 'x', obscureText: o));
      EditableText e() =>
          tester.widget<EditableText>(find.byType(EditableText));
      await tester.pumpWidget(field(true));
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(e().obscureText, isFalse);
      await tester.pumpWidget(field(false));
      await tester.pumpWidget(field(true));
      expect(e().obscureText, isTrue);
    });

    testWidgets('label is part of the field semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(const AppTextField(label: 'Nom')));
      expect(find.bySemanticsLabel(RegExp('Nom')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('forced LTR for phone in an RTL screen', (tester) async {
      await tester.pumpWidget(
        host(
          const AppTextField(label: 'الهاتف', textDirection: TextDirection.ltr),
          lang: 'ar',
        ),
      );
      final e = tester.widget<EditableText>(find.byType(EditableText));
      expect(e.textDirection, TextDirection.ltr);
    });
  });

  group('AppChip', () {
    testWidgets('toggles and exposes selected state', (tester) async {
      final handle = tester.ensureSemantics();
      var selected = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => host(
            AppChip(
              label: 'Plomberie',
              selected: selected,
              onSelected: (v) => setState(() => selected = v),
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Plomberie')),
        isNot(isSemantics(isSelected: true)),
      );
      await tester.tap(find.text('Plomberie'));
      await tester.pump();
      expect(selected, isTrue);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Plomberie')),
        isSemantics(label: 'Plomberie', isButton: true, isSelected: true),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('layout', () {
    testWidgets('chips pack side by side in a Wrap', (tester) async {
      await tester.pumpWidget(
        host(
          Wrap(
            children: [
              AppChip(label: 'Plomberie', selected: false, onSelected: (_) {}),
              AppChip(
                label: 'Électricité',
                selected: false,
                onSelected: (_) {},
              ),
              AppChip(
                label: 'Climatisation',
                selected: true,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      );
      final y = [
        for (final l in ['Plomberie', 'Électricité', 'Climatisation'])
          tester.getCenter(find.text(l)).dy,
      ];
      expect(y.toSet().length, 1, reason: 'all on one run: $y');
    });

    testWidgets('long chip label wraps instead of overflowing', (tester) async {
      tester.view.physicalSize = const Size(200 * 3, 600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(
          AppChip(
            label: 'Réparation et entretien de climatiseurs',
            selected: false,
            onSelected: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('inline (non-expanded) buttons lay out in a Row', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Row(
            children: [
              AppButton(
                label: 'Appeler',
                onPressed: () {},
                expand: false,
                icon: Icons.phone,
              ),
              const SizedBox(width: 8),
              AppButton(
                label: 'WhatsApp',
                onPressed: () {},
                expand: false,
                variant: AppButtonVariant.secondary,
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Appeler'), findsOneWidget);
    });

    testWidgets('long header action stays on screen at 320 px', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 600 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(
          SectionHeader(
            title: 'Professionnels les mieux notés près de chez vous',
            actionLabel: 'Voir tous les professionnels',
            onAction: () {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AppCard / SectionHeader', () {
    testWidgets('tappable card calls onTap; plain card is not a button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var n = 0;
      await tester.pumpWidget(
        host(
          Column(
            children: [
              AppCard(
                onTap: () => n++,
                semanticLabel: 'Profil',
                child: const Text('Karim'),
              ),
              const AppCard(child: Text('Info')),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Karim'));
      expect(n, 1);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Profil')),
        isSemantics(label: 'Profil', isButton: true, hasTapAction: true),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('header action works and is a header for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var n = 0;
      await tester.pumpWidget(
        host(
          SectionHeader(
            title: 'Populaires',
            actionLabel: 'Voir tout',
            onAction: () => n++,
          ),
        ),
      );
      expect(
        tester.getSemantics(find.text('Populaires')),
        isSemantics(label: 'Populaires', isHeader: true),
      );
      await tester.tap(find.text('Voir tout'));
      expect(n, 1);
      handle.dispose();
    });

    testWidgets('RTL puts the action on the left of the title', (tester) async {
      await tester.pumpWidget(
        host(
          SectionHeader(
            title: 'الأكثر شعبية',
            actionLabel: 'عرض الكل',
            onAction: () {},
          ),
          lang: 'ar',
        ),
      );
      expect(
        tester.getCenter(find.text('عرض الكل')).dx,
        lessThan(tester.getCenter(find.text('الأكثر شعبية')).dx),
      );
    });
  });

  group('RatingStars', () {
    testWidgets('no reviews: honest text, no stars, no score', (tester) async {
      await tester.pumpWidget(
        host(const RatingStars(rating: 5, reviewCount: 0)),
      );
      expect(find.text("Pas encore d'avis"), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.textContaining('5'), findsNothing);
    });

    testWidgets('shows value, count and a spoken summary', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(const RatingStars(rating: 4.5, reviewCount: 12)),
      );
      expect(find.text('4,5 (12)', findRichText: true), findsOneWidget);
      expect(find.bySemanticsLabel('Note 4,5 sur 5, 12 avis'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('English uses a dot; Arabic keeps Western digits', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const RatingStars(rating: 4.5, reviewCount: 1), lang: 'en'),
      );
      expect(find.text('4.5 (1)', findRichText: true), findsOneWidget);
      await tester.pumpWidget(
        host(const RatingStars(rating: 4.5, reviewCount: 3), lang: 'ar'),
      );
      expect(find.text('4,5 (3)', findRichText: true), findsOneWidget);
    });

    test('formatRating handles infinity', () {
      expect(formatRating(double.infinity, const Locale('fr')), '5,0');
      expect(formatRating(double.negativeInfinity, const Locale('fr')), '0,0');
    });

    test('formatRating clamps and survives NaN', () {
      const fr = Locale('fr');
      expect(formatRating(7, fr), '5,0');
      expect(formatRating(-1, fr), '0,0');
      expect(formatRating(double.nan, fr), '0,0');
      expect(formatRating(4.25, const Locale('en')), '4.3');
    });

    testWidgets('fractional fill: 4.5 fills 4 stars and half of the 5th', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const RatingStars(rating: 4.5, reviewCount: 2)),
      );
      final clips = tester
          .widgetList<ClipRect>(find.byType(ClipRect))
          .where((c) => c.clipper.runtimeType.toString() == '_FillClipper')
          .map((c) => (c.clipper as dynamic).fill as double)
          .toList();
      expect(clips, [1.0, 1.0, 1.0, 1.0, 0.5]);
    });
  });

  group('AppAvatar', () {
    test('initials', () {
      expect(AppAvatar.initialsOf('Karim Ben Salah'), 'KB');
      expect(AppAvatar.initialsOf('  samir  '), 'S');
      expect(AppAvatar.initialsOf('خالد المنصوري'), 'خا');
      expect(AppAvatar.initialsOf('Salma (démo)'), 'S');
      expect(AppAvatar.initialsOf(''), '?');
      expect(AppAvatar.initialsOf('   '), '?');
      // Grapheme clusters: a decomposed accent and skin-tone emoji stay whole.
      expect(AppAvatar.initialsOf('E\u0301mile Ben'), 'E\u0301B');
      expect(
        AppAvatar.initialsOf('\u{1F44B}\u{1F3FD} Sam').characters.first,
        '\u{1F44B}\u{1F3FD}',
      );
    });

    testWidgets(
      'decorative and nameless avatars are hidden from screen readers',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          host(
            const Column(
              children: [
                AppAvatar(name: 'Karim Ben Salah', decorative: true),
                AppAvatar(name: ''),
              ],
            ),
          ),
        );
        expect(find.bySemanticsLabel('Karim Ben Salah'), findsNothing);
        handle.dispose();
      },
    );

    testWidgets('tiny device pixel ratio does not crash', (tester) async {
      tester.view.devicePixelRatio = 0.0001;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        host(
          const AppAvatar(
            name: 'Karim',
            imageUrl: 'http://localhost/a.png',
            size: 2,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('missing or failing image falls back to initials', (
      tester,
    ) async {
      await tester.pumpWidget(host(const AppAvatar(name: 'Karim Ben Salah')));
      expect(find.text('KB'), findsOneWidget);
      await tester.pumpWidget(
        host(
          const AppAvatar(
            name: 'Karim Ben Salah',
            imageUrl: 'http://localhost/404.png',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('KB'), findsOneWidget);
    });
  });

  group('AppBadge', () {
    testWidgets('verified badge is localized with an icon', (tester) async {
      await tester.pumpWidget(
        host(Builder(builder: (c) => AppBadge.verified(c)), lang: 'ar'),
      );
      expect(find.text('موثّق'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });

    test('every tone meets 4.5:1 on its own background, light and dark', () {
      for (final theme in [
        AppTheme.light(const Locale('fr')),
        AppTheme.dark(const Locale('fr')),
      ]) {
        for (final tone in BadgeTone.values) {
          final fg = AppBadge.foreground(tone, theme.colorScheme);
          final bg = AppBadge.background(tone, theme.colorScheme);
          expect(
            _ratio(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: '$tone ${theme.brightness}',
          );
        }
      }
    });
  });

  group('color contrast of component pairings', () {
    test('text and control boundaries meet WCAG AA in both themes', () {
      for (final theme in [
        AppTheme.light(const Locale('fr')),
        AppTheme.dark(const Locale('fr')),
      ]) {
        final cs = theme.colorScheme;
        final b = theme.brightness;
        final bgPage = theme.scaffoldBackgroundColor;
        final textPairs = <String, (Color, Color)>{
          'onSurface/surface': (cs.onSurface, cs.surface),
          'onSurface/background': (cs.onSurface, bgPage),
          'onSurfaceVariant/surface': (cs.onSurfaceVariant, cs.surface),
          'onSurfaceVariant/background': (cs.onSurfaceVariant, bgPage),
          'primary/surface': (cs.primary, cs.surface),
          'onPrimary/primary': (cs.onPrimary, cs.primary),
          'onPrimaryContainer/primaryContainer': (
            cs.onPrimaryContainer,
            cs.primaryContainer,
          ),
        };
        textPairs.forEach((name, p) {
          expect(
            _ratio(p.$1, p.$2),
            greaterThanOrEqualTo(4.5),
            reason: '$b $name',
          );
        });
        for (final bg in [cs.surface, bgPage]) {
          expect(
            _ratio(cs.outline, bg),
            greaterThanOrEqualTo(3.0),
            reason: '$b outline',
          );
        }
        expect(
          _ratio(cs.outlineVariant, cs.surface),
          lessThan(_ratio(cs.outline, cs.surface)),
        );
      }
    });
  });

  group('Skeleton / ErrorState', () {
    testWidgets('shimmers, unless the system reduces motion', (tester) async {
      await tester.pumpWidget(host(const Skeleton(width: 100)));
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(Animate), findsOneWidget);
      await tester.pumpWidget(
        host(const Skeleton(width: 100), disableAnimations: true),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(Animate), findsNothing);
    });

    testWidgets('group announces loading once', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const SkeletonGroup(
            child: Column(children: [Skeleton(width: 80), Skeleton(width: 40)]),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.bySemanticsLabel('Chargement…'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('error state offers retry', (tester) async {
      var n = 0;
      await tester.pumpWidget(host(ErrorState(onRetry: () => n++)));
      expect(find.text('Une erreur est survenue'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      expect(n, 1);
    });
  });

  group('kitchen sink: no exceptions in every locale and brightness', () {
    for (final lang in ['fr', 'ar', 'en']) {
      for (final dark in [false, true]) {
        testWidgets('$lang dark=$dark at 1.5x text, 320 px wide', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320 * 3, 900 * 3);
          tester.view.devicePixelRatio = 3;
          tester.platformDispatcher.textScaleFactorTestValue = 1.5;
          addTearDown(() {
            tester.view.reset();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          await tester.pumpWidget(
            host(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: 'T', actionLabel: 'A', onAction: () {}),
                  AppButton(label: 'Go', onPressed: () {}),
                  const AppTextField(label: 'L', hint: 'h'),
                  Wrap(
                    children: [
                      AppChip(label: 'a', selected: true, onSelected: (_) {}),
                      AppChip(label: 'b', selected: false, onSelected: (_) {}),
                    ],
                  ),
                  const AppCard(
                    child: Row(
                      children: [
                        AppAvatar(name: 'Karim B'),
                        SizedBox(width: 8),
                        Expanded(
                          child: RatingStars(rating: 4.2, reviewCount: 8),
                        ),
                      ],
                    ),
                  ),
                  Builder(builder: AppBadge.verified),
                  const Skeleton(width: 120),
                ],
              ),
              lang: lang,
              dark: dark,
            ),
          );
          await tester.pump(const Duration(milliseconds: 1));
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
