import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/new_password_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/gallery/gallery_config.dart';
import '../../features/gallery/gallery_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/marketplace/presentation/professional_screen.dart';
import '../../features/marketplace/presentation/search_screen.dart';
import '../../features/messages/presentation/messages_screen.dart';
import '../../features/portfolio/presentation/portfolio_screen.dart';
import '../../features/professional/presentation/dashboard_screen.dart';
import '../../features/professional/presentation/registration_screen.dart';
import '../../features/onboarding/application/onboarding_controller.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
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
        if (path == AppRoutes.onboarding) return null;
        // Remember where the user was going; restored after onboarding.
        final from = path == '/' ? null : state.uri.toString();
        return Uri(
          path: AppRoutes.onboarding,
          queryParameters: from == null ? null : {'from': from},
        ).toString();
      }
      if (path == AppRoutes.onboarding) {
        return _safeDestination(state.uri.queryParameters['from']);
      }
      // Bare root (also with ?utm_source=... on web) lands on Home.
      if (path == '/') {
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
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const NewPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.proPortfolio,
        builder: (context, state) => const PortfolioScreen(),
      ),
      GoRoute(
        path: AppRoutes.proDashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.proRegistration,
        builder: (context, state) => const RegistrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.favorites,
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => SearchScreen(
          categoryId: int.tryParse(state.uri.queryParameters['category'] ?? ''),
          initialText: state.uri.queryParameters['q'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.professional,
        builder: (context, state) =>
            ProfessionalScreen(id: state.pathParameters['id'] ?? ''),
      ),
      if (kShowGallery)
        GoRoute(
          path: AppRoutes.gallery,
          builder: (context, state) => const GalleryScreen(),
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

/// Only internal, non-onboarding paths are accepted from `?from=`, so a
/// crafted link cannot redirect elsewhere.
String _safeDestination(String? from) {
  if (from == null ||
      !from.startsWith('/') ||
      from.startsWith('//') ||
      from.startsWith(AppRoutes.onboarding)) {
    return AppRoutes.home;
  }
  return from;
}
