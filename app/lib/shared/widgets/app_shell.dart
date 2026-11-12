import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/motion.dart';
import '../../core/theme/world_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import 'app_bottom_nav.dart';

/// Scaffold around the tab branches. Each branch keeps its own state and
/// navigation stack while hidden (IndexedStack under the hood). It also plays
/// the colour flood when the person switches world (trades <-> digital).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flood = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  Color _floodColor = Colors.transparent;
  Offset _origin = Offset.zero;

  @override
  void dispose() {
    _flood.dispose();
    super.dispose();
  }

  void _play(WorldState next) {
    if (Motion.reduced(context)) return;
    final b = Theme.of(context).brightness;
    final size = MediaQuery.sizeOf(context);
    setState(() {
      _floodColor = next.world.accent(b);
      _origin = next.origin ?? Offset(size.width / 2, size.height / 3);
    });
    _flood.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen<WorldState>(worldProvider, (prev, next) {
      if (prev == null || prev.tick == next.tick) return;
      _play(next);
    });
    final shell = widget.navigationShell;
    return Stack(
      children: [
        Scaffold(
          body: shell,
          bottomNavigationBar: AppBottomNav(
            currentIndex: shell.currentIndex,
            onSelected: (i) => shell.goBranch(
              i,
              // Tapping the active tab returns to its root screen.
              initialLocation: i == shell.currentIndex,
            ),
            items: [
              NavItem(Icons.home_outlined, Icons.home_rounded, l10n.navHome),
              NavItem(
                Icons.assignment_outlined,
                Icons.assignment_rounded,
                l10n.navRequests,
              ),
              NavItem(
                Icons.chat_bubble_outline_rounded,
                Icons.chat_bubble_rounded,
                l10n.navMessages,
              ),
              NavItem(
                Icons.person_outline_rounded,
                Icons.person_rounded,
                l10n.navProfile,
              ),
            ],
          ),
        ),
        // The flood: a disc of the new colour grows from the tapped switch and
        // fades once the new theme is in place underneath.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _flood,
              builder: (context, _) => _flood.isDismissed
                  ? const SizedBox.shrink()
                  : CustomPaint(
                      painter: _FloodPainter(
                        t: _flood.value,
                        color: _floodColor,
                        origin: _origin,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FloodPainter extends CustomPainter {
  _FloodPainter({required this.t, required this.color, required this.origin});

  final double t;
  final Color color;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    final far = [
      origin.distance,
      (origin - Offset(size.width, 0)).distance,
      (origin - Offset(0, size.height)).distance,
      (origin - Offset(size.width, size.height)).distance,
    ].reduce((a, b) => a > b ? a : b);
    final grow = Curves.easeInCubic.transform((t / 0.6).clamp(0, 1));
    final fade = t < 0.6 ? 1.0 : 1 - Curves.easeOut.transform((t - 0.6) / 0.4);
    canvas.drawCircle(
      origin,
      far * grow,
      Paint()..color = color.withValues(alpha: fade),
    );
  }

  @override
  bool shouldRepaint(_FloodPainter old) =>
      old.t != t || old.color != color || old.origin != origin;
}
