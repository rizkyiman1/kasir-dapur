enum UserRole {
  owner,
  admin,
  cashier;

  String get label {
    return switch (this) {
      UserRole.owner => 'Owner',
      UserRole.admin => 'Admin',
      UserRole.cashier => 'Kasir',
    };
  }

  static UserRole fromStorage(String value) {
    return UserRole.values.firstWhere(
      (UserRole role) => role.name == value,
      orElse: () => UserRole.owner,
    );
  }
}

final class AuthUser {
  const AuthUser({
    required this.id,
    required this.displayName,
    required this.role,
  });

  final String id;
  final String displayName;
  final UserRole role;
}
