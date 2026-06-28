import '../../../core/services/api_client.dart';
import '../../../core/constants/api_endpoints.dart';

class BulletinPost {
  final String id;
  final String authorName;
  final String content;
  final String createdAt;

  const BulletinPost({
    required this.id,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  factory BulletinPost.fromJson(Map<String, dynamic> json) => BulletinPost(
        id: json['id'] as String,
        authorName: json['author_name'] as String,
        content: json['content'] as String,
        createdAt: json['created_at'] as String,
      );
}

class BulletinRepository {
  final ApiClient _api;
  BulletinRepository(this._api);

  Future<List<BulletinPost>> listApproved() async {
    final resp = await _api.get(ApiEndpoints.bulletin);
    final list = resp.data as List<dynamic>? ?? [];
    return list
        .map((e) => BulletinPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> create(String content) async {
    await _api.post(ApiEndpoints.bulletin, data: {'content': content});
  }

  Future<List<Map<String, dynamic>>> listPending() async {
    final resp = await _api.get(ApiEndpoints.adminBulletinPending);
    return (resp.data as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  Future<void> review(String id, {required bool approve}) async {
    await _api.post(ApiEndpoints.adminBulletinReview(id),
        data: {'approve': approve});
  }
}
