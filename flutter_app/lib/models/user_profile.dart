enum UserRole { student, staff }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.campusId,
    required this.role,
  });

  final String id;
  final String name;
  final String email;

  /// Student or staff number printed on the university card.
  final String campusId;
  final UserRole role;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'campusId': campusId,
        'role': role.name,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        campusId: json['campusId'] as String,
        role: UserRole.values.byName(json['role'] as String),
      );
}
