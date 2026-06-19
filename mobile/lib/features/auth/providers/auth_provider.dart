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
  const AuthAuthenticated(this.userId);
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
    final token = await ref.watch(storageServiceProvider).getAccessToken();
    if (token != null) return const AuthAuthenticated('');
    return AuthUnauthenticated();
  }

  Future<void> login({
    required String communityId,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(authRepositoryProvider).login(
            communityId: communityId,
            email: email,
            password: password,
          );
      state = AsyncValue.data(const AuthAuthenticated(''));
    } catch (e) {
      state = AsyncValue.data(AuthError(e.toString()));
    }
  }

  Future<void> registerMorador({
    required String communityId,
    required String email,
    required String password,
    required String fullName,
    required String streetAddress,
    required String houseNumber,
  }) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(authRepositoryProvider).registerMorador(
            communityId: communityId,
            email: email,
            password: password,
            fullName: fullName,
            streetAddress: streetAddress,
            houseNumber: houseNumber,
          );
      state = AsyncValue.data(AuthPending());
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
