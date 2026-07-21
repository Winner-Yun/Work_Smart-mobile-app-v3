class UserModel {
  final String id;
  final String email;
  final String name;
  final String avatar;
  final String gender;
  final String status;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.avatar,
    required this.gender,
    required this.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? 'User',
      avatar: json['avatar']?.toString() ?? '',
      gender: json['gender']?.toString() ?? 'unknown',
      status: json['status']?.toString() ?? 'unknown',
    );
  }
}
