import 'package:kasir_dapur/features/auth/domain/auth_user.dart';

abstract class AuthRepository {
  Future<AuthUser?> getById(String id);
  Future<List<AuthUser>> listUsers();
  Future<bool> hasLocalUser();
  Future<AuthUser> registerOwner({
    required String displayName,
    required String pin,
  });
  Future<AuthUser> createUser({
    required String displayName,
    required String pin,
    required UserRole role,
  });
  Future<AuthUser?> authenticate({required String pin, String? userId});
  Future<void> changePin({
    required String userId,
    required String currentPin,
    required String newPin,
  });
  Future<void> deleteAllLocalUsers();
}
