import 'package:dio/dio.dart';
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

/// Resultado de uma tentativa de login/reativação. É RETORNADO para a tela em
/// vez de virar estado do authProvider de propósito: o routerProvider observa
/// o authProvider, então mexer no estado a cada erro recriaria o GoRouter — e
/// isso destrói a LoginScreen (o formulário se apaga e qualquer diálogo aberto
/// vai junto). O estado só muda quando a sessão realmente muda.
sealed class LoginResult {
  const LoginResult();
}

class LoginOk extends LoginResult {
  const LoginOk();
}

class LoginFailed extends LoginResult {
  final String message;
  const LoginFailed(this.message);
}

/// Senha certa, mas a conta foi excluída pelo próprio dono: dá pra reativar.
class LoginDeletedAccount extends LoginResult {
  final String message;
  const LoginDeletedAccount(this.message);
}
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

  Future<LoginResult> login({
    required String communityId,
    required String email,
    required String password,
  }) async {
    try {
      final tokens = await ref.read(authRepositoryProvider).login(
            communityId: communityId,
            email: email,
            password: password,
          );
      final role = AuthRepository.extractRole(tokens.accessToken);
      state = AsyncValue.data(AuthAuthenticated(tokens.userId, role: role));
      return const LoginOk();
    } on DioException catch (e) {
      return _resultFromDio(e, 'Não foi possível entrar. Tente novamente.');
    } catch (_) {
      return const LoginFailed('Não foi possível entrar. Tente novamente.');
    }
  }

  LoginResult _resultFromDio(DioException e, String fallback) {
    final data = e.response?.data;
    final code = data is Map ? data['code'] as String? : null;
    final msg = data is Map ? data['error'] as String? : null;
    // O backend marca a conta autoexcluída com esse code justamente pra
    // podermos oferecer "Reativar" em vez de só barrar a entrada.
    if (code == 'account_deleted') {
      return LoginDeletedAccount(msg ?? 'Esta conta foi excluída.');
    }
    return LoginFailed(msg ?? fallback);
  }

  /// Reativa a conta que o próprio usuário excluiu e já entra com ela.
  Future<LoginResult> reactivate({
    required String communityId,
    required String email,
    required String password,
  }) async {
    try {
      final tokens = await ref.read(authRepositoryProvider).reactivate(
            communityId: communityId,
            email: email,
            password: password,
          );
      final role = AuthRepository.extractRole(tokens.accessToken);
      state = AsyncValue.data(AuthAuthenticated(tokens.userId, role: role));
      return const LoginOk();
    } on DioException catch (e) {
      return _resultFromDio(
          e, 'Não foi possível reativar a conta. Tente novamente.');
    } catch (_) {
      return const LoginFailed(
          'Não foi possível reativar a conta. Tente novamente.');
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = AsyncValue.data(AuthUnauthenticated());
  }

  Future<void> deleteAccount() async {
    await ref.read(authRepositoryProvider).deleteAccount();
    state = AsyncValue.data(AuthUnauthenticated());
  }
}

final authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
