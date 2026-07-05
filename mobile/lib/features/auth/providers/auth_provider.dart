import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/storage_service.dart';

final storageServiceProvider = Provider((ref) => StorageService());

final apiClientProvider = Provider((ref) {
  return ApiClient(ref.watch(storageServiceProvider));
});

final authRepositoryProvider = Provider((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(storageServiceProvider),
  );
});

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final String userId;
  final String role;
  const AuthAuthenticated(this.userId, {this.role = ''});
}
class AuthUnauthenticated extends AuthState {}
class AuthPending extends AuthState {}
class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final storage = ref.watch(storageServiceProvider);
    final token = await storage.getAccessToken();
    if (token != null) {
      final userId = await storage.getUserId() ?? '';
      final role = await storage.getRole() ?? '';
      return AuthAuthenticated(userId, role: role);
    }
    return AuthUnauthenticated();
  }

  Future<void> login({
    required String communityId,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final tokens = await ref.read(authRepositoryProvider).login(
            communityId: communityId,
            email: email,
            password: password,
          );
      final role = AuthRepository.extractRole(tokens.accessToken);
      state = AsyncValue.data(AuthAuthenticated(tokens.userId, role: role));
    } catch (e) {
      state = AsyncValue.data(AuthError(e.toString()));
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = AsyncValue.data(AuthUnauthenticated());
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
