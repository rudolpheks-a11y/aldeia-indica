import '../../../core/services/api_client.dart';
import '../../../core/constants/api_endpoints.dart';

class AvailabilitySlot {
  final int dayOfWeek; // 0=Dom … 6=Sáb
  final String startTime; // "08:00"
  final String endTime;   // "18:00"

  const AvailabilitySlot({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) =>
      AvailabilitySlot(
        dayOfWeek: json['day_of_week'] as int,
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
      );

  Map<String, dynamic> toJson() => {
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
      };
}

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
  final List<AvailabilitySlot> availability;

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
    required this.availability,
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
        availability: (json['availability'] as List<dynamic>?)
                ?.map((e) => AvailabilitySlot.fromJson(e as Map<String, dynamic>))
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

  Future<void> updateAvailability(List<AvailabilitySlot> slots) async {
    await _api.put(ApiEndpoints.providerMeAvailability, data: {
      'slots': slots.map((s) => s.toJson()).toList(),
    });
  }

  Future<void> updateBio(String bio) async {
    await _api.put(ApiEndpoints.providerMe, data: {
      'professional_bio': bio,
    });
  }
}
