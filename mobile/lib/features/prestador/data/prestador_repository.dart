import '../../../core/services/api_client.dart';
import '../../../core/constants/api_endpoints.dart';

class PrestadorProfile {
  final String userId;
  final String fullName;
  final String city;
  final int yearsInNeighborhood;
  final String? professionalBio;
  final bool needsTransport;
  final String? transportType;
  final List<String> categorySlugs;
  final List<String> categories;

  PrestadorProfile({
    required this.userId,
    required this.fullName,
    required this.city,
    required this.yearsInNeighborhood,
    this.professionalBio,
    required this.needsTransport,
    this.transportType,
    required this.categorySlugs,
    required this.categories,
  });

  factory PrestadorProfile.fromJson(Map<String, dynamic> json) =>
      PrestadorProfile(
        userId: json['user_id'] as String,
        fullName: json['full_name'] as String,
        city: json['city'] as String? ?? '',
        yearsInNeighborhood: json['years_in_neighborhood'] as int? ?? 0,
        professionalBio: json['professional_bio'] as String?,
        needsTransport: json['needs_transport'] as bool? ?? false,
        transportType: json['transport_type'] as String?,
        categorySlugs: (json['category_slugs'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        categories: (json['categories'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}

class PrestadorRepository {
  final ApiClient _api;

  PrestadorRepository(this._api);

  Future<PrestadorProfile> getProfile() async {
    final resp = await _api.get(ApiEndpoints.providerMe);
    return PrestadorProfile.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> updateSkills({
    required List<String> categorySlugs,
    required bool needsTransport,
    String? transportType,
  }) async {
    await _api.put(ApiEndpoints.providerMe, data: {
      'category_slugs': categorySlugs,
      'needs_transport': needsTransport,
      if (needsTransport && transportType != null) 'transport_type': transportType,
      if (!needsTransport) 'transport_type': null,
    });
  }

  Future<void> updateBio(String bio) async {
    await _api.put(ApiEndpoints.providerMe, data: {
      'professional_bio': bio,
    });
  }
}
