import 'dart:convert';

import '../../../core/services/api_client.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/constants/api_endpoints.dart';
import 'models/token_response.dart';

class AuthRepository {
  final ApiClient _api;
  final StorageService _storage;

  AuthRepository(this._api, this._storage);

  Future<TokenResponse> login({
    required String communityId,
    required String email,
    required String password,
    String platform = 'android',
  }) async {
    final resp = await _api.post(ApiEndpoints.login, data: {
      'community_id': communityId,
      'email': email,
      'password': password,
      'platform': platform,
    });
    final tokens = TokenResponse.fromJson(resp.data as Map<String, dynamic>);
    await _storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );
    await _storage.saveCommunityId(communityId);
    if (tokens.userId.isNotEmpty) {
      await _storage.saveUserId(tokens.userId);
    }
    final role = extractRole(tokens.accessToken);
    if (role.isNotEmpty) await _storage.saveRole(role);
    return tokens;
  }

  Future<String> registerMorador({
    required String communityId,
    required String email,
    required String password,
    required String fullName,
    required String streetAddress,
    required String houseNumber,
    String neighborhoodBlock = '',
  }) async {
    final resp = await _api.post(ApiEndpoints.registerMorador, data: {
      'community_id': communityId,
      'email': email,
      'password': password,
      'full_name': fullName,
      'street_address': streetAddress,
      'house_number': houseNumber,
      'neighborhood_block': neighborhoodBlock,
    });
    return (resp.data as Map<String, dynamic>)['user_id'] as String;
  }

  Future<String> registerPrestador({
    required String communityId,
    required String email,
    required String password,
    required String fullName,
    required String city,
    required int yearsInNeighborhood,
    String professionalBio = '',
  }) async {
    final resp = await _api.post(ApiEndpoints.registerPrestador, data: {
      'community_id': communityId,
      'email': email,
      'password': password,
      'full_name': fullName,
      'city': city,
      'years_in_neighborhood': yearsInNeighborhood,
      'professional_bio': professionalBio,
    });
    return (resp.data as Map<String, dynamic>)['user_id'] as String;
  }

  Future<void> forgotPassword({
    required String communityId,
    required String email,
  }) async {
    await _api.post(ApiEndpoints.forgotPassword, data: {
      'community_id': communityId,
      'email': email,
    });
  }

  Future<void> resetPassword({
    required String communityId,
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _api.post(ApiEndpoints.resetPassword, data: {
      'community_id': communityId,
      'email': email,
      'code': code,
      'new_password': newPassword,
    });
  }

  static String extractRole(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return '';
      String payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = base64Decode(payload);
      final map = jsonDecode(utf8.decode(decoded)) as Map<String, dynamic>;
      return map['role'] as String? ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> logout() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken != null) {
      await _api.post(ApiEndpoints.logout, data: {'refresh_token': refreshToken});
    }
    await _storage.clear();
  }
}
