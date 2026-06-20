import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_morador_screen.dart';
import '../../features/auth/presentation/register_prestador_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/approvals/presentation/pending_approval_screen.dart';
import '../../features/providers_list/presentation/search_screen.dart';
import '../../features/provider_profile/presentation/profile_screen.dart';
import '../../features/rating/presentation/rate_provider_screen.dart';
import '../../features/chat/presentation/conversations_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/service_requests/presentation/requests_feed_screen.dart';
import '../../features/service_requests/presentation/create_request_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final authState = auth.valueOrNull;
      if (authState is AuthAuthenticated) {
        if (state.matchedLocation == '/login') return '/search';
        return null;
      }
      if (authState is AuthPending) return '/pending-approval';
      if (authState is AuthUnauthenticated) {
        if (state.matchedLocation.startsWith('/login') ||
            state.matchedLocation.startsWith('/register')) return null;
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
          path: '/pending-approval',
          builder: (_, __) => const PendingApprovalScreen()),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
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
    ],
  );
});
