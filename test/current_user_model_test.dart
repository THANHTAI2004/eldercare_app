import 'package:flutter_test/flutter_test.dart';

import 'package:eldercare_app/src/domain/models/current_user.dart';

void main() {
  test('CurrentUser.fromJson prioritizes snake_case backend contract', () {
    final user = CurrentUser.fromJson(const <String, dynamic>{
      'user_id': 'user-001',
      'name': 'Nguyen Van A',
      'phone_number': '0987654321',
      'date_of_birth': '1950-01-02',
      'role': 'member',
      'userId': 'legacy-user',
      'phoneNumber': '0000000000',
    });

    expect(user.userId, 'user-001');
    expect(user.name, 'Nguyen Van A');
    expect(user.phoneNumber, '0987654321');
    expect(user.dateOfBirth, '1950-01-02');
    expect(user.role, 'member');
  });
}
