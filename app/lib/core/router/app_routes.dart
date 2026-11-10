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
  static const editProfile = '/edit-profile';
  static const favorites = '/favorites';
  static const newRequest = '/requests/new';
  static const request = '/requests/:id';
  static String requestPath(String id) =>
      '/requests/${Uri.encodeComponent(id)}';
  static const proInbox = '/pro/requests';
  static const proRequest = '/pro/requests/:id';
  static String proRequestPath(String id) =>
      '/pro/requests/${Uri.encodeComponent(id)}';
  static const proOffers = '/pro/offers';
  static const proJobs = '/pro/jobs';
  static const notificationSettings = '/settings/notifications';
  static const chat = '/messages/:id';
  static String chatPath(String id) => '/messages/${Uri.encodeComponent(id)}';
  static const proRegistration = '/pro/profile';
  static const proDashboard = '/pro';
  static const proPortfolio = '/pro/portfolio';
  static const search = '/search';
  static const professional = '/professional/:id';
  static String professionalPath(String id) =>
      '/professional/${Uri.encodeComponent(id)}';
  static String searchPath({int? categoryId}) => Uri(
    path: search,
    queryParameters: categoryId == null ? null : {'category': '$categoryId'},
  ).toString();
  static const gallery = '/gallery'; // debug / GALLERY builds only
}
