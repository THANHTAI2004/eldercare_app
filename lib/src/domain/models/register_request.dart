class RegisterRequest {
  const RegisterRequest({
    required this.name,
    required this.phoneNumber,
    required this.dateOfBirth,
    required this.password,
  });

  final String name;
  final String phoneNumber;
  final String dateOfBirth;
  final String password;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'phone_number': phoneNumber,
      'date_of_birth': dateOfBirth,
      'password': password,
    };
  }
}
