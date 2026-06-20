class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final String userId;

  TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) => TokenResponse(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        userId: json['user_id'] as String? ?? '',
      );
}
