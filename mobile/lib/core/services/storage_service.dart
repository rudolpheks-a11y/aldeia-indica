import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _communityKey = 'community_id';

  final FlutterSecureStorage _storage;

  StorageService() : _storage = const FlutterSecureStorage();

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _accessKey, value: accessToken),
      _storage.write(key: _refreshKey, value: refreshToken),
    ]);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshKey);

  Future<void> saveCommunityId(String id) =>
      _storage.write(key: _communityKey, value: id);
  Future<String?> getCommunityId() => _storage.read(key: _communityKey);

  Future<void> clear() => _storage.deleteAll();
}
