/// Route paths. Tabs are top-level; detail screens nest under them later.
abstract final class AppRoutes {
  static const home = '/home';
  static const requests = '/requests';
  static const messages = '/messages';
  static const profile = '/profile';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const gallery = '/gallery'; // debug / GALLERY builds only
}
