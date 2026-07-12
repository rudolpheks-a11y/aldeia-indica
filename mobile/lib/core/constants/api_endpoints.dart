class ApiEndpoints {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api/v1',
  );
  static const String wsUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://localhost:8080',
  );

  static const String registerMorador = '/auth/register/morador';
  static const String registerPrestador = '/auth/register/prestador';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  static const String categories = '/categories';
  static const String providers = '/providers';
  static const String providerMe = '/providers/me';
  static const String providerMeAvailability = '/providers/me/availability';
  static String providerById(String id) => '/providers/$id';
  static const String favorites = '/providers/favorites';
  static String favoriteProvider(String id) => '/providers/$id/favorite';
  static String providerQuestions(String id) => '/providers/$id/questions';
  static String providerQuestionAnswers(String id, String qid) =>
      '/providers/$id/questions/$qid/answers';

  static const String ratings = '/ratings';
  static String ratingsByProvider(String id) => '/ratings/provider/$id';

  static const String recommendations = '/recommendations';
  static String recommendationsByProvider(String id) =>
      '/recommendations/provider/$id';

  static const String requests = '/requests';
  static String requestById(String id) => '/requests/$id';
  static String requestResponses(String id) => '/requests/$id/responses';

  static const String conversations = '/chat/conversations';
  static String messages(String id) => '/chat/conversations/$id/messages';

  static const String presign = '/uploads/presign';

  static const String invites = '/invites';

  static const String dashboardSummary = '/dashboard/summary';


  static const String communities = '/communities';
  static const String adminCommunities = '/admin/communities';

  static const String providersFeatured = '/providers/featured';
  static const String providerMeRatingsSummary = '/providers/me/ratings/summary';

  static const String bulletin = '/bulletin';
  static const String adminBulletinPending = '/admin/bulletin/pending';
  static String adminBulletinReview(String id) => '/admin/bulletin/$id/review';

  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static const String notificationsReadAll = '/notifications/read-all';

  static const String reactivate = '/auth/reactivate';
  static const String usersMe = '/users/me';
  static String adminUser(String id) => '/admin/users/$id';

  static const String wsChat = '/ws/chat';
}
