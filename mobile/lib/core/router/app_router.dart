import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_morador_screen.dart';
import '../../features/auth/presentation/register_prestador_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/approvals/presentation/pending_approval_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/providers_list/presentation/search_screen.dart';
import '../../features/providers_list/presentation/service_picker_screen.dart';
import '../../features/recommendations/presentation/recommend_select_screen.dart';
import '../../features/recommendations/presentation/recommend_provider_screen.dart';
import '../../features/provider_profile/presentation/profile_screen.dart';
import '../../features/rating/presentation/rate_provider_screen.dart';
import '../../features/chat/presentation/conversations_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/service_requests/presentation/requests_feed_screen.dart';
import '../../features/service_requests/presentation/create_request_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/prestador/presentation/skills_screen.dart';
import '../../features/prestador/presentation/anuncio_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final authState = auth.valueOrNull;
      if (authState is AuthAuthenticated) {
        if (state.matchedLocation == '/login') return '/home';
        return null;
      }
      if (authState is AuthPending) return '/pending-approval';
      if (authState is AuthUnauthenticated) {
        if (state.matchedLocation.startsWith('/login') ||
            state.matchedLocation.startsWith('/register') ||
            state.matchedLocation.startsWith('/forgot-password') ||
            state.matchedLocation.startsWith('/reset-password')) return null;
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/register/morador',
          builder: (_, __) => const RegisterMoradorScreen()),
      GoRoute(
          path: '/register/prestador',
          builder: (_, __) => const RegisterPrestadorScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
          path: '/reset-password',
          builder: (_, state) {
            final extra = state.extra as Map<String, String>? ?? {};
            return ResetPasswordScreen(
              communityId: extra['communityId'] ?? '',
              email: extra['email'] ?? '',
            );
          }),
      GoRoute(
          path: '/pending-approval',
          builder: (_, __) => const PendingApprovalScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/service-picker', builder: (_, __) => const ServicePickerScreen()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(
          path: '/recommend',
          builder: (_, __) => const RecommendSelectScreen()),
      GoRoute(
          path: '/recommend/:id',
          builder: (_, state) => RecommendProviderScreen(
              providerId: state.pathParameters['id']!)),
      GoRoute(
          path: '/provider/:id',
          builder: (_, state) =>
              ProfileScreen(providerId: state.pathParameters['id']!)),
      GoRoute(
          path: '/rate/:id',
          builder: (_, state) =>
              RateProviderScreen(providerId: state.pathParameters['id']!)),
      GoRoute(
          path: '/conversations',
          builder: (_, __) => const ConversationsScreen()),
      GoRoute(
          path: '/chat/:id',
          builder: (_, state) =>
              ChatScreen(conversationId: state.pathParameters['id']!)),
      GoRoute(path: '/requests', builder: (_, __) => const RequestsFeedScreen()),
      GoRoute(
          path: '/requests/new',
          builder: (_, __) => const CreateRequestScreen()),
      GoRoute(
          path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(
          path: '/admin',
          builder: (_, __) => const AdminDashboardScreen()),
      GoRoute(
          path: '/prestador/skills',
          builder: (_, __) => const SkillsScreen()),
      GoRoute(
          path: '/prestador/anuncio',
          builder: (_, __) => const AnuncioScreen()),
    ],
  );
});
