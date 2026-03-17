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
    return CurrentUser(
      userId:
          _readString(json['user_id']) ??
          _readString(json['userId']) ??
          _readString(json['id']) ??
          _readString(json['username']) ??
          '',
      name:
          _readString(json['name']) ??
          _readString(json['full_name']) ??
          _readString(json['fullName']) ??
          _readString(json['display_name']) ??
          _readString(json['displayName']) ??
          '',
      phoneNumber:
          _readString(json['phone_number']) ??
          _readString(json['phoneNumber']) ??
          _readString(json['phone']) ??
          '',
      dateOfBirth:
          _readString(json['date_of_birth']) ??
          _readString(json['dateOfBirth']) ??
          _readString(json['birth_date']),
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
