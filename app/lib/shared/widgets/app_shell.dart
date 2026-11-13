import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import 'app_bottom_nav.dart';

/// Scaffold around the tab branches. Each branch keeps its own state and
/// navigation stack while hidden (IndexedStack under the hood).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shell = navigationShell;
    return Scaffold(
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
            Icons.search_rounded,
            Icons.manage_search_rounded,
            l10n.navExplore,
          ),
          NavItem(
            Icons.description_outlined,
            Icons.description_rounded,
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
    );
  }
}
