import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    final titles = [
      l10n.chooseLanguage,
      l10n.onbTitle1,
      l10n.onbTitle2,
      l10n.onbTitle3,
    ];
    final reduce = MediaQuery.disableAnimationsOf(context);
    final pages = <Widget>[
      OnboardingPage(
        leading: const KhidmaLogo(markSize: 56),
        title: l10n.chooseLanguage,
        body: l10n.languageStepBody,
        extra: const LanguageSelector(),
        hideIconWhenCompact: true,
      ),
      OnboardingPage(
        icon: Icons.verified_user_outlined,
        photo: 'assets/photos/onb-find.jpg',
        title: l10n.onbTitle1,
        body: l10n.onbBody1,
      ),
      OnboardingPage(
        icon: Icons.request_quote_outlined,
        photo: 'assets/photos/onb-compare.jpg',
        title: l10n.onbTitle2,
        body: l10n.onbBody2,
      ),
      OnboardingPage(
        icon: Icons.forum_outlined,
        photo: 'assets/photos/onb-trust.jpg',
        title: l10n.onbTitle3,
        body: l10n.onbBody3,
      ),
    ];

    return Scaffold(
      body: SafeArea(
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
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => _goTo(_index - 1),
                        ),
                      const Spacer(),
                      if (_index > 0 && !_isLast)
                        AppButton(
                          label: l10n.skip,
                          variant: AppButtonVariant.text,
                          expand: false,
                          onPressed: () => ref
                              .read(onboardingSeenProvider.notifier)
                              .complete(),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _pageCount; i++)
                        AnimatedContainer(
                          duration: reduce
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          margin: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          width: i == _index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _index
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.gutter,
                    AppSpacing.xl,
                    AppSpacing.gutter,
                    AppSpacing.xl,
                  ),
                  child: AppButton(
                    label: _isLast ? l10n.start : l10n.next,
                    onPressed: _next,
                  ),
                ),
                if (_index == 0)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: AppSpacing.lg,
                    ),
                    child: Text(
                      l10n.tagline,
                      style: text.bodySmall?.copyWith(color: muted),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
