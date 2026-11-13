import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/rating.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../core/motion/ambient_motion.dart';
import '../../../core/motion/motion.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/khidma_logo.dart';
import '../../freelance/data/demo_freelance_repository.dart';
import '../../marketplace/data/demo_data.dart';
import '../../marketplace/presentation/category_icon.dart';
import '../../settings/presentation/language_selector.dart';
import '../application/onboarding_controller.dart';
import 'welcome_marquee.dart';

/// Sample people for the moving rows: generic first names with an initial,
/// in Latin and Arabic script, and an illustrative rating. Not real pros.
const _samplePros = <(String, String, double)>[
  ('Mehdi B.', 'مهدي ب.', 4.9),
  ('Sarra K.', 'سارة ك.', 4.8),
  ('Youssef T.', 'يوسف ت.', 4.7),
  ('Ines H.', 'إيناس ح.', 5.0),
  ('Anis R.', 'أنيس ر.', 4.9),
  ('Lina M.', 'لينا م.', 4.8),
];

/// The first screen, shown once: logo and language button, three slowly
/// scrolling rows of services and pros, the headline "Find a [word] near
/// you." with a rotating word, a trust line, then "Get started" (enters the
/// app, or the deep link that was waiting) and "I already have an account"
/// (sign in). No permission is requested here.
///
/// Motion: a short fade-up cascade on open; the rows and the word move only
/// while the screen is visible (one ticker, muted by [TickerMode]) and not
/// at all with Reduce Motion.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  static const _wordEvery = 2.2; // seconds per rotating word
  static const _wordCount = 5;

  late final Ticker _ticker = createTicker(_tick);

  /// Seconds of motion so far (drives the rows).
  final _clock = ValueNotifier<double>(0);

  /// Index of the rotating word.
  final _word = ValueNotifier<int>(0);
  Duration _last = Duration.zero;
  double _sinceWord = 0;

  void _tick(Duration elapsed) {
    // A long gap (screen was hidden, app paused) resumes smoothly instead
    // of jumping ahead.
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _clock.value += dt;
    _sinceWord += dt;
    if (_sinceWord >= _wordEvery) {
      _sinceWord = 0;
      _word.value = (_word.value + 1) % _wordCount;
    }
  }

  void _syncMotion(bool run) {
    if (run && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    _word.dispose();
    super.dispose();
  }

  void _start() => ref.read(onboardingSeenProvider.notifier).complete();

  void _signIn() {
    ref.read(onboardingSeenProvider.notifier).complete();
    context.go(AppRoutes.login);
  }

  Future<void> _pickLanguage() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                AppLocalizations.of(sheet).chooseLanguage,
                style: Theme.of(sheet).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LanguageSelector(onSelected: (_) => Navigator.of(sheet).pop()),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final locale = ref.watch(localeProvider);
    final reduce = Motion.reduced(context);
    final moving = !reduce && ref.watch(ambientMotionProvider);
    _syncMotion(moving);

    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    // At very large text the rows give their room to the words.
    final showRows = scale <= 1.7;
    final chipScale = math.min(scale, 1.3);
    final rowHeight = math.max(34.0, 33.2 * chipScale) + 20;

    final languageName = switch (locale.languageCode) {
      'ar' => l10n.languageArabic,
      'en' => l10n.languageEnglish,
      _ => l10n.languageFrench,
    };

    Widget trade(int id) {
      final c = demoCategories.firstWhere((c) => c.id == id);
      return WelcomeCategoryChip(
        icon: categoryIcon(c.icon),
        label: c.nameFor(locale),
      );
    }

    Widget digital(int id) {
      final c = demoDigitalCategories.firstWhere((c) => c.id == id);
      return WelcomeCategoryChip(
        icon: digitalCategoryIcon(c.icon),
        label: c.nameFor(locale),
      );
    }

    final trades = [
      l10n.welcomeTradePlumber,
      l10n.welcomeTradeDesigner,
      l10n.welcomeTradeElectrician,
      l10n.welcomeTradeDeveloper,
      l10n.welcomeTradeCarpenter,
      l10n.welcomeTradeVideo,
    ];
    final ar = locale.languageCode == 'ar';
    final pros = [
      for (var i = 0; i < _samplePros.length; i++)
        WelcomeProChip(
          name: ar ? _samplePros[i].$2 : _samplePros[i].$1,
          trade: trades[i],
          rating: formatRating(_samplePros[i].$3, locale),
          colorIndex: i,
        ),
    ];
    final rows = [
      [trade(1), trade(2), digital(1), trade(5), digital(4)],
      pros,
      [digital(4), trade(3), digital(3), trade(6), digital(2), trade(1)],
    ];

    final words = [
      l10n.welcomeWordPlumber,
      l10n.welcomeWordElectrician,
      l10n.welcomeWordDeveloper,
      l10n.welcomeWordDesigner,
      l10n.welcomeWordCarpenter,
    ];

    Widget cascade(int i, Widget child) =>
        StaggerIn(index: i, stepMs: 90, child: child);

    final top = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        cascade(
          0,
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.gutter,
              AppSpacing.sm,
              AppSpacing.gutter,
              0,
            ),
            child: Row(
              children: [
                const Flexible(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: KhidmaLogo(markSize: 32),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _LanguageButton(
                  language: languageName,
                  semanticLabel: l10n.welcomeLanguageButton(languageName),
                  onTap: _pickLanguage,
                ),
              ],
            ),
          ),
        ),
        if (showRows)
          cascade(
            1,
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 26),
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: WelcomeMarquee(
                  rows: rows,
                  clock: _clock,
                  rowHeight: rowHeight,
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            AppSpacing.xl,
            showRows ? 30 : AppSpacing.xl,
            AppSpacing.xl,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cascade(
                2,
                _Headline(
                  start: l10n.welcomeHeadlineStart,
                  end: l10n.welcomeHeadlineEnd,
                  words: words,
                  index: _word,
                  sentence: l10n.welcomeHeadlineA11y,
                  animate: moving,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              cascade(
                3,
                Text(
                  l10n.welcomeSubtitle,
                  style: text.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              cascade(
                4,
                _TrustLine(
                  label: l10n.welcomeTrust,
                  faces: [for (final p in _samplePros) ar ? p.$2 : p.$1],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final actions = cascade(
      5,
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppButton(label: l10n.start, onPressed: _start),
            const SizedBox(height: 10),
            AppButton(
              label: l10n.welcomeHaveAccount,
              variant: AppButtonVariant.secondary,
              onPressed: _signIn,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.welcomeLegal,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        // Phone-width on tablets and desktop web.
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  // Content at the top, the buttons at the bottom; scrolls
                  // instead of overflowing on small screens or large text.
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [top, actions],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Globe, current language and a chevron, in a hairline pill.
class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.language,
    required this.semanticLabel,
    required this.onTap,
  });

  final String language;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shape = StadiumBorder(side: BorderSide(color: scheme.outlineVariant));
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: scheme.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.language_rounded,
                      size: 16,
                      color: scheme.onSurface,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      language,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: scheme.onSurface,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Trouvez un / [word] / près de chez vous." on three lines. The middle
/// word slides up and fades into the next one. Screen readers hear one
/// fixed sentence naming every trade, never each change.
class _Headline extends StatelessWidget {
  const _Headline({
    required this.start,
    required this.end,
    required this.words,
    required this.index,
    required this.sentence,
    required this.animate,
  });

  final String start;
  final String end;
  final List<String> words;
  final ValueListenable<int> index;
  final String sentence;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final style = theme.textTheme.displayMedium?.copyWith(
      fontSize: narrow ? 29 : 33,
      fontWeight: FontWeight.w800,
      color: theme.colorScheme.onSurface,
    );

    Widget word(int i) => FittedBox(
      key: ValueKey(i),
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(words[i], maxLines: 1, softWrap: false, style: style),
    );

    return Semantics(
      header: true,
      label: sentence,
      excludeSemantics: true,
      // Big titles may stop growing at 1.5x; the rest of the screen scales.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(start, style: style),
            ValueListenableBuilder<int>(
              valueListenable: index,
              builder: (context, current, _) {
                final i = current % words.length;
                if (!animate) return word(i);
                return ClipRect(
                  child: AnimatedSwitcher(
                    duration: Motion.slow,
                    switchInCurve: Motion.enter,
                    switchOutCurve: Motion.enter,
                    layoutBuilder: (now, before) => Stack(
                      alignment: AlignmentDirectional.centerStart,
                      children: [...before, ?now],
                    ),
                    // Rebuilt on every change, so the outgoing word gets the
                    // "leave upwards" slide and the new one "enter from
                    // below".
                    transitionBuilder: (child, a) {
                      final entering = child.key == ValueKey(i);
                      return FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(0, entering ? 1 : -1),
                            end: Offset.zero,
                          ).animate(a),
                          child: child,
                        ),
                      );
                    },
                    child: word(i),
                  ),
                );
              },
            ),
            Text(end, style: style),
          ],
        ),
      ),
    );
  }
}

/// A few overlapping initials faces and a plain claim (no numbers).
class _TrustLine extends StatelessWidget {
  const _TrustLine({required this.label, required this.faces});

  final String label;
  final List<String> faces;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const size = 28.0;
    const step = 20.0;
    final shown = faces.take(4).toList();
    return Row(
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: size + step * (shown.length - 1),
            height: size,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  PositionedDirectional(
                    start: step * i,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 2),
                      ),
                      child: WelcomeInitials(
                        name: shown[i],
                        colorIndex: i,
                        size: size - 4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
