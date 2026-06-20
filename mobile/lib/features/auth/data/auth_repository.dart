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

  Future<void> logout() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken != null) {
      await _api.post(ApiEndpoints.logout, data: {'refresh_token': refreshToken});
    }
    await _storage.clear();
  }
}
