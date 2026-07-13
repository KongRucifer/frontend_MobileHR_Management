class AppUser {
  final String id;
  final String email;
  final String? username;
  final String role;
  final String? employeeId;

  AppUser({
    required this.id,
    required this.email,
    this.username,
    required this.role,
    this.employeeId,
  });

  /// Handles both /auth/login (nested user) and /auth/me (flat) shapes.
  factory AppUser.fromJson(Map<String, dynamic> j) {
    return AppUser(
      id: (j['id'] ?? j['userId'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      username: j['username']?.toString(),
      role: (j['role'] ?? 'employee').toString(),
      employeeId: j['employeeId']?.toString(),
    );
  }
}
