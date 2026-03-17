import 'dart:convert';

class DeviceLinkedUser {
  const DeviceLinkedUser({
    required this.id,
    required this.name,
    this.role,
    this.phoneNumber,
  });

  final String id;
  final String name;
  final String? role;
  final String? phoneNumber;

  String get displayName => name.trim().isEmpty ? id : name;

  factory DeviceLinkedUser.fromJson(Map<String, dynamic> json) {
    final id =
        _readString(json['user_id']) ??
        _readString(json['userId']) ??
        _readString(json['uid']) ??
        _readString(json['id']) ??
        '';
    final name =
        _readString(json['full_name']) ??
        _readString(json['fullName']) ??
        _readString(json['display_name']) ??
        _readString(json['displayName']) ??
        _readString(json['name']) ??
        id;
    final role =
        _readString(json['role']) ??
        _readString(json['link_role']) ??
        _readString(json['linkRole']) ??
        _readString(json['relationship']);
    final phoneNumber =
        _readString(json['phone_number']) ??
        _readString(json['phoneNumber']) ??
        _readString(json['phone']);

    return DeviceLinkedUser(
      id: id,
      name: name,
      role: role,
      phoneNumber: phoneNumber,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (role != null && role!.trim().isNotEmpty) 'role': role,
    if (phoneNumber != null && phoneNumber!.trim().isNotEmpty)
      'phoneNumber': phoneNumber,
  };
}

class Device {
  Device({
    required this.id,
    required this.name,
    this.legacyUserId,
    this.linkedUsers = const <DeviceLinkedUser>[],
    this.isLocalOnly = false,
  });

  final String id;
  final String? legacyUserId;
  final List<DeviceLinkedUser> linkedUsers;
  final bool isLocalOnly;

  String name;

  String get resolvedDeviceId => id.trim();

  bool get hasExplicitDeviceId {
    final userId = legacyUserId?.trim();
    if (userId == null || userId.isEmpty) return true;
    return resolvedDeviceId != userId;
  }

  String? get primaryUserId {
    for (final user in linkedUsers) {
      final id = user.id.trim();
      if (id.isNotEmpty) return id;
    }

    final fallback = legacyUserId?.trim();
    if (fallback == null || fallback.isEmpty) return null;
    return fallback;
  }

  Device copyWith({
    String? id,
    String? name,
    String? legacyUserId,
    List<DeviceLinkedUser>? linkedUsers,
    bool? isLocalOnly,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      legacyUserId: legacyUserId ?? this.legacyUserId,
      linkedUsers: linkedUsers ?? this.linkedUsers,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
    );
  }

  factory Device.fromQr(String qrRaw) {
    String? userId;
    String? deviceId;
    String? name;

    final text = qrRaw.trim();
    try {
      final data = jsonDecode(text) as Map<String, dynamic>;
      userId =
          _readString(data['userId']) ??
          _readString(data['user_id']) ??
          _readString(data['uid']);
      deviceId =
          _readString(data['deviceId']) ??
          _readString(data['device_id']) ??
          _readString(data['id']);
      name = _readString(data['name']);
    } catch (_) {
      userId = text;
    }

    final resolvedDeviceId = (deviceId?.trim().isNotEmpty ?? false)
        ? deviceId!.trim()
        : (userId ?? text).trim();
    final resolvedUserId = userId?.trim();

    return Device(
      id: resolvedDeviceId,
      name: (name?.trim().isNotEmpty ?? false)
          ? name!.trim()
          : 'Thiet bi $resolvedDeviceId',
      legacyUserId: (resolvedUserId?.isNotEmpty ?? false)
          ? resolvedUserId
          : null,
      linkedUsers: (resolvedUserId?.isNotEmpty ?? false)
          ? <DeviceLinkedUser>[
              DeviceLinkedUser(id: resolvedUserId!, name: resolvedUserId),
            ]
          : const <DeviceLinkedUser>[],
      isLocalOnly: true,
    );
  }

  factory Device.fromServerJson(Map<String, dynamic> json) {
    final deviceId =
        _readString(json['device_id']) ??
        _readString(json['deviceId']) ??
        _readString(json['device']) ??
        _readString(json['id']) ??
        '';

    final links = _extractLinkedUsers(json);
    final legacyUserId =
        _readString(json['user_id']) ??
        _readString(json['userId']) ??
        _readString(json['owner_user_id']) ??
        _readString(json['ownerUserId']) ??
        (links.isEmpty ? null : links.first.id);
    final name =
        _readString(json['display_name']) ??
        _readString(json['displayName']) ??
        _readString(json['device_name']) ??
        _readString(json['deviceName']) ??
        _readString(json['name']) ??
        'Thiet bi $deviceId';

    return Device(
      id: deviceId,
      name: name,
      legacyUserId: legacyUserId,
      linkedUsers: links,
      isLocalOnly: false,
    );
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    final linkedUsers = <DeviceLinkedUser>[];
    final rawLinks = json['linkedUsers'];
    if (rawLinks is List) {
      for (final entry in rawLinks) {
        if (entry is Map<String, dynamic>) {
          linkedUsers.add(DeviceLinkedUser.fromJson(entry));
        } else if (entry is Map) {
          linkedUsers.add(
            DeviceLinkedUser.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
    }

    final id =
        _readString(json['id']) ??
        _readString(json['deviceId']) ??
        _readString(json['device_id']) ??
        _readString(json['userId']) ??
        '';
    final name =
        _readString(json['name']) ??
        _readString(json['displayName']) ??
        'Thiet bi $id';

    return Device(
      id: id,
      name: name,
      legacyUserId:
          _readString(json['legacyUserId']) ??
          _readString(json['userId']) ??
          _readString(json['user_id']),
      linkedUsers: linkedUsers,
      isLocalOnly: json['isLocalOnly'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (legacyUserId != null && legacyUserId!.trim().isNotEmpty)
      'legacyUserId': legacyUserId,
    if (linkedUsers.isNotEmpty)
      'linkedUsers': linkedUsers.map((entry) => entry.toJson()).toList(),
    if (isLocalOnly) 'isLocalOnly': true,
  };

  static List<DeviceLinkedUser> _extractLinkedUsers(Map<String, dynamic> json) {
    final output = <DeviceLinkedUser>[];
    final seen = <String>{};
    final candidates = <dynamic>[
      json['linked_users'],
      json['linkedUsers'],
      json['users'],
      json['members'],
      json['device_links'],
      json['deviceLinks'],
      json['links'],
    ];

    for (final candidate in candidates) {
      if (candidate is! List) continue;
      for (final item in candidate) {
        DeviceLinkedUser? user;
        if (item is Map<String, dynamic>) {
          user = DeviceLinkedUser.fromJson(item);
        } else if (item is Map) {
          user = DeviceLinkedUser.fromJson(Map<String, dynamic>.from(item));
        } else if (item != null) {
          final id = item.toString().trim();
          if (id.isNotEmpty) {
            user = DeviceLinkedUser(id: id, name: id);
          }
        }

        if (user == null) continue;
        final normalizedId = user.id.trim();
        if (normalizedId.isEmpty || seen.contains(normalizedId)) continue;
        seen.add(normalizedId);
        output.add(user);
      }

      if (output.isNotEmpty) return output;
    }

    return output;
  }
}

String? _readString(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
