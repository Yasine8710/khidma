import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/app_spacing.dart';

/// One titled part of a profile page (Services, Réalisations, Avis, À propos).
class ProfileSection {
  const ProfileSection({required this.label, required this.child});

  /// The tab's label; sections have no heading of their own.
  final String label;
  final Widget child;
}

/// Height of the tab bar.
const double _barHeight = 48;

/// A profile page in one scroll: [header] (full bleed), [stats], a tab bar,
/// every section one after the other, then [footer]. Tapping a tab scrolls
/// to its section; the tab bar pins to the top once it reaches it, and the
/// selected tab follows the reading position. Everything stays in one list,
/// so nothing is hidden behind a tab.
class SectionedProfile extends StatefulWidget {
  const SectionedProfile({
    super.key,
    required this.controller,
    required this.header,
    required this.stats,
    required this.sections,
    required this.footer,
    required this.side,
  });

  final ScrollController controller;
  final Widget header;
  final Widget stats;
  final List<ProfileSection> sections;
  final Widget footer;

  /// Horizontal inset of the content.
  final double side;

  @override
  State<SectionedProfile> createState() => _SectionedProfileState();
}

class _SectionedProfileState extends State<SectionedProfile>
    with TickerProviderStateMixin {
  late TabController _tabs = _newTabs();
  final _barKey = GlobalKey();
  final _keys = <String, GlobalKey>{};
  bool _pinned = false;
  bool _jumping = false;

  TabController _newTabs([int index = 0]) => TabController(
    length: widget.sections.length,
    initialIndex: index.clamp(0, widget.sections.length - 1),
    vsync: this,
  );

  GlobalKey _keyFor(String label) => _keys.putIfAbsent(label, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(SectionedProfile old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
    if (old.sections.length != widget.sections.length) {
      // A section appeared (photos loaded) or went: a new controller. The
      // old one goes after the tab bars have let go of it.
      final previous = _tabs;
      _tabs = _newTabs(previous.index);
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _tabs.dispose();
    super.dispose();
  }

  /// The scroll offset that puts the top of [key]'s box at the top of the
  /// list, or null when it is not laid out.
  double? _topOf(GlobalKey key) {
    final ro = key.currentContext?.findRenderObject();
    if (ro == null || !ro.attached) return null;
    final viewport = RenderAbstractViewport.maybeOf(ro);
    if (viewport == null) return null;
    return viewport.getOffsetToReveal(ro, 0).offset;
  }

  double get _inset => MediaQuery.paddingOf(context).top;

  void _onScroll() {
    if (!mounted || !widget.controller.hasClients) return;
    final offset = widget.controller.offset;
    final barTop = _topOf(_barKey);
    final pinned = barTop != null && offset >= barTop - _inset;
    if (pinned != _pinned) setState(() => _pinned = pinned);
    if (_jumping) return;
    var current = 0;
    for (var i = 0; i < widget.sections.length; i++) {
      final top = _topOf(_keyFor(widget.sections[i].label));
      if (top != null && top - _inset - _barHeight <= offset + 1) current = i;
    }
    if (current != _tabs.index) _tabs.animateTo(current);
  }

  Future<void> _go(int i) async {
    final c = widget.controller;
    final top = _topOf(_keyFor(widget.sections[i].label));
    if (top == null || !c.hasClients) return;
    final pos = c.position;
    final target = (top - _inset - _barHeight).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    _jumping = true;
    _tabs.animateTo(i);
    if (Motion.reduced(context)) {
      c.jumpTo(target);
    } else {
      await c.animateTo(target, duration: Motion.slow, curve: Motion.enter);
    }
    _jumping = false;
    _onScroll();
  }

  Widget _bar(ColorScheme scheme) => TabBar(
    controller: _tabs,
    isScrollable: true,
    tabAlignment: TabAlignment.start,
    padding: EdgeInsetsDirectional.symmetric(
      horizontal: widget.side - AppSpacing.lg,
    ),
    dividerColor: scheme.outlineVariant,
    onTap: _go,
    tabs: [for (final s in widget.sections) Tab(text: s.label)],
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget pad(Widget child) => Padding(
      padding: EdgeInsetsDirectional.symmetric(horizontal: widget.side),
      child: child,
    );
    return Stack(
      children: [
        ListView(
          controller: widget.controller,
          // Built whole so every section can be scrolled to at once.
          scrollCacheExtent: const ScrollCacheExtent.pixels(100000),
          padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xl),
          children: [
            widget.header,
            const SizedBox(height: AppSpacing.lg),
            pad(widget.stats),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              key: _barKey,
              height: _barHeight,
              // Hidden while its pinned copy shows at the top.
              child: Offstage(offstage: _pinned, child: _bar(scheme)),
            ),
            for (final s in widget.sections)
              KeyedSubtree(
                key: _keyFor(s.label),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    widget.side,
                    AppSpacing.lg,
                    widget.side,
                    AppSpacing.md,
                  ),
                  child: s.child,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            pad(widget.footer),
          ],
        ),
        if (_pinned)
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            child: Material(
              color: scheme.surface,
              child: Padding(
                padding: EdgeInsetsDirectional.only(top: _inset),
                child: SizedBox(height: _barHeight, child: _bar(scheme)),
              ),
            ),
          ),
      ],
    );
  }
}
