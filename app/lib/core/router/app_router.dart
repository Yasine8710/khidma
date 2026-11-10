import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/messages/presentation/messages_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/requests/presentation/requests_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/not_found_screen.dart';
import 'app_routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    // Phase 2 hooks auth/role redirects here. Redirects are UX only; real
    // access control is enforced by Supabase RLS, never by the router.
    redirect: (context, state) {
      // Bare root (also with ?utm_source=... on web) lands on Home.
      if (state.uri.path == '/') {
        return Uri(
          path: AppRoutes.home,
          queryParameters: state.uri.queryParameters.isEmpty
              ? null
              : state.uri.queryParameters,
        ).toString();
      }
      return null;
    },
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
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
  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _branch(String path, WidgetBuilder builder) =>
    StatefulShellBranch(
      routes: [
        GoRoute(path: path, builder: (context, state) => builder(context)),
      ],
    );
