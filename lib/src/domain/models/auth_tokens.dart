class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  bool get hasRefreshToken => refreshToken.trim().isNotEmpty;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    final accessToken =
        _readString(json['access_token']) ??
        _readString(json['accessToken']) ??
        _readString(json['token']) ??
        '';
    final refreshToken =
        _readString(json['refresh_token']) ??
        _readString(json['refreshToken']) ??
        '';

    return AuthTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}

String? _readString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
