import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/messages/presentation/messages_screen.dart';
import '../../features/onboarding/application/onboarding_controller.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/requests/presentation/requests_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/not_found_screen.dart';
import 'app_routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects when onboarding is completed, without rebuilding the
  // router itself (which would reset navigation state).
  final refresh = ValueNotifier<int>(0);
  ref.listen(onboardingSeenProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    // Redirects are UX only; real access control is enforced by Supabase RLS,
    // never by the router. Phase 2 adds auth/role redirects here.
    redirect: (context, state) {
      final seen = ref.read(onboardingSeenProvider);
      final path = state.uri.path;
      final query = state.uri.queryParameters.isEmpty
          ? null
          : state.uri.queryParameters;

      if (!seen) {
        return path == AppRoutes.onboarding ? null : AppRoutes.onboarding;
      }
      // Bare root (also with ?utm_source=... on web) lands on Home.
      if (path == '/' || path == AppRoutes.onboarding) {
        return Uri(path: AppRoutes.home, queryParameters: query).toString();
      }
      return null;
    },
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          _branch(AppRoutes.home, (_) => const HomeScreen()),
          _branch(AppRoutes.requests, (_) => const RequestsScreen()),
          _branch(AppRoutes.messages, (_) => const MessagesScreen()),
          _branch(AppRoutes.profile, (_) => const ProfileScreen()),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

StatefulShellBranch _branch(String path, WidgetBuilder builder) =>
    StatefulShellBranch(
      routes: [
        GoRoute(path: path, builder: (context, state) => builder(context)),
      ],
    );
