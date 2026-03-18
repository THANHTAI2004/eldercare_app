class CurrentUser {
  const CurrentUser({
    required this.userId,
    required this.name,
    required this.phoneNumber,
    required this.dateOfBirth,
    required this.role,
  });

  final String userId;
  final String name;
  final String phoneNumber;
  final String? dateOfBirth;
  final String role;

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    // Primary contract is snake_case from backend.
    // camelCase and legacy fallbacks are kept only for backward compatibility.
    return CurrentUser(
      userId:
          _readString(json['user_id']) ??
          _readString(json['userId']) ??
          _readString(json['id']) ??
          '',
      name:
          _readString(json['name']) ??
          _readString(json['full_name']) ??
          _readString(json['fullName']) ??
          '',
      phoneNumber:
          _readString(json['phone_number']) ??
          _readString(json['phoneNumber']) ??
          '',
      dateOfBirth:
          _readString(json['date_of_birth']) ??
          _readString(json['dateOfBirth']),
      role: (_readString(json['role']) ?? '').toLowerCase(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user_id': userId,
      'name': name,
      'phone_number': phoneNumber,
      if (dateOfBirth != null && dateOfBirth!.trim().isNotEmpty)
        'date_of_birth': dateOfBirth,
      'role': role,
    };
  }
}

String? _readString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
