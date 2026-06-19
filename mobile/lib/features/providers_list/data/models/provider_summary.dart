class ProviderSummary {
  final String userId;
  final String fullName;
  final String? avatarKey;
  final String city;
  final int yearsInNeighborhood;
  final double scoreAldeia;
  final double? avgRating;
  final int recommendationCount;
  final List<String> categories;

  ProviderSummary({
    required this.userId,
    required this.fullName,
    this.avatarKey,
    required this.city,
    required this.yearsInNeighborhood,
    required this.scoreAldeia,
    this.avgRating,
    required this.recommendationCount,
    required this.categories,
  });

  factory ProviderSummary.fromJson(Map<String, dynamic> json) =>
      ProviderSummary(
        userId: json['user_id'] as String,
        fullName: json['full_name'] as String,
        avatarKey: json['avatar_key'] as String?,
        city: json['city'] as String,
        yearsInNeighborhood: json['years_in_neighborhood'] as int,
        scoreAldeia: (json['score_aldeia'] as num).toDouble(),
        avgRating: json['avg_rating'] != null
            ? (json['avg_rating'] as num).toDouble()
            : null,
        recommendationCount: json['recommendation_count'] as int,
        categories: (json['categories'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );
}
