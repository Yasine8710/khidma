import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/khidma_logo.dart';
import '../../settings/presentation/language_selector.dart';
import '../application/onboarding_controller.dart';
import 'onboarding_page.dart';

/// First-run flow: language, then three short value pages. Shown once; the
/// router sends the user to Home when it is completed or skipped. Location
/// permission is intentionally not requested here.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _pageCount = 4; // language + 3 value pages
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _pageCount - 1;

  /// Moves to [page]; jumps instead of animating when the system asks to
  /// reduce motion (animateToPage rejects a zero duration).
  void _goTo(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _next() {
    if (_isLast) {
      ref.read(onboardingSeenProvider.notifier).complete();
      return;
    }
    _goTo(_index + 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    String two(int n) => n.toString().padLeft(2, '0');

    final titles = [
      l10n.chooseLanguage,
      l10n.onbTitle1,
      l10n.onbTitle2,
      l10n.onbTitle3,
    ];
    final reduce = MediaQuery.disableAnimationsOf(context);
    // One flat colour field per page; fg is the ink printed on it.
    final fields = <(Color, Color)>[
      (scheme.surfaceContainer, scheme.onSurface),
      (scheme.primaryContainer, scheme.onPrimaryContainer),
      (scheme.onSurface, scheme.surface),
      (scheme.secondary, scheme.onSecondary),
    ];
    final (bg, fg) = fields[_index];
    final pages = <Widget>[
      OnboardingPage(
        active: _index == 0,
        foreground: fields[0].$2,
        leading: const KhidmaLogo(markSize: 48),
        title: l10n.chooseLanguage,
        body: l10n.languageStepBody,
        extra: const LanguageSelector(),
        hideIconWhenCompact: true,
      ),
      OnboardingPage(
        active: _index == 1,
        foreground: fields[1].$2,
        step: '01',
        icon: Icons.verified_user_outlined,
        title: l10n.onbTitle1,
        body: l10n.onbBody1,
      ),
      OnboardingPage(
        active: _index == 2,
        foreground: fields[2].$2,
        step: '02',
        icon: Icons.request_quote_outlined,
        title: l10n.onbTitle2,
        body: l10n.onbBody2,
      ),
      OnboardingPage(
        active: _index == 3,
        foreground: fields[3].$2,
        step: '03',
        icon: Icons.forum_outlined,
        title: l10n.onbTitle3,
        body: l10n.onbBody3,
      ),
    ];

    // The button is the inverse of the field (ink on yellow, paper on ink).
    final base = Theme.of(context);
    final inverse = ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(fg),
      foregroundColor: WidgetStatePropertyAll(bg),
    );
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedContainer(
        duration: reduce ? Duration.zero : Motion.base,
        curve: Motion.enter,
        color: bg,
        child: SafeArea(
          // Keep the flow phone-width on tablets and desktop web.
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  // Reserved height keeps the layout still when Skip disappears.
                  SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        if (_index > 0)
                          IconButton(
                            tooltip: l10n.back,
                            icon: Icon(Icons.arrow_back_rounded, color: fg),
                            onPressed: () => _goTo(_index - 1),
                          )
                        else
                          const SizedBox(width: AppSpacing.gutter - 4),
                        // Folio, like a numbered leaflet. Screen readers get the
                        // same information from the live region below.
                        ExcludeSemantics(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: AppSpacing.xs,
                            ),
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: two(_index + 1),
                                      style: text.titleMedium?.copyWith(
                                        color: fg,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' / ${two(_pageCount)}',
                                      style: text.titleMedium?.copyWith(
                                        color: fg,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (_index > 0 && !_isLast)
                          Theme(
                            data: base.copyWith(
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: fg,
                                ),
                              ),
                            ),
                            child: AppButton(
                              label: l10n.skip,
                              variant: AppButtonVariant.text,
                              expand: false,
                              onPressed: () => ref
                                  .read(onboardingSeenProvider.notifier)
                                  .complete(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      allowImplicitScrolling: true,
                      onPageChanged: (i) => setState(() => _index = i),
                      children: pages,
                    ),
                  ),
                  Semantics(
                    // Live region: screen readers announce the new page and title.
                    label:
                        '${l10n.pageOf(_index + 1, _pageCount)}, ${titles[_index]}',
                    liveRegion: true,
                    excludeSemantics: true,
                    // Plain progress marks: one ruled segment per page, inked up
                    // to the current one.
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: AppSpacing.gutter,
                      ),
                      child: Row(
                        children: [
                          for (var i = 0; i < _pageCount; i++) ...[
                            if (i > 0) const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: AnimatedContainer(
                                duration: reduce
                                    ? Duration.zero
                                    : const Duration(milliseconds: 180),
                                height: 6,
                                decoration: BoxDecoration(
                                  color: i <= _index ? fg : Colors.transparent,
                                  border: Border.all(color: fg, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.gutter,
                      AppSpacing.lg,
                      AppSpacing.gutter,
                      AppSpacing.lg,
                    ),
                    child: Theme(
                      data: base.copyWith(
                        filledButtonTheme: FilledButtonThemeData(
                          style:
                              base.filledButtonTheme.style?.merge(inverse) ??
                              inverse,
                        ),
                      ),
                      child: AppButton(
                        label: _isLast ? l10n.start : l10n.next,
                        onPressed: _next,
                      ),
                    ),
                  ),
                  if (_index == 0)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: AppSpacing.lg,
                      ),
                      child: Text(
                        l10n.tagline,
                        style: text.bodySmall?.copyWith(color: fg),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
