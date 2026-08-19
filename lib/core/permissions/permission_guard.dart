import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/permissions/app_permission.dart';
import 'package:kasir_dapur/core/permissions/permission_policy.dart';
import 'package:kasir_dapur/features/auth/domain/auth_state.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';

/// Konteks akses saat ini. Bukan tombol UI.
abstract class AccessContext {
  AuthUser? get currentUser;
  bool get isLocked;
  bool get isAuthenticated;
}

final class AuthStateAccessContext implements AccessContext {
  const AuthStateAccessContext(this._state);

  final AuthState _state;

  @override
  AuthUser? get currentUser => _state.user;

  @override
  bool get isLocked => _state.status == AuthStatus.locked;

  @override
  bool get isAuthenticated => _state.status == AuthStatus.authenticated;
}

/// Pemegang konteks akses. Diisi AuthController, dibaca repository berpagar.
final class AccessHolder {
  AccessContext value = const StaticAccessContext();
}

final class StaticAccessContext implements AccessContext {
  const StaticAccessContext({this.currentUser, this.isLocked = false});

  @override
  final AuthUser? currentUser;

  @override
  final bool isLocked;

  @override
  bool get isAuthenticated => currentUser != null && !isLocked;
}

/// Penegakan izin di domain/repository. Bukan hanya penyembunyian UI.
final class PermissionGuard {
  PermissionGuard({PermissionPolicy? policy})
    : _policy = policy ?? PermissionPolicy.standard();

  final PermissionPolicy _policy;

  PermissionPolicy get policy => _policy;

  void require(AccessContext access, AppPermission permission) {
    if (access.isLocked) {
      throw const ForbiddenException('Sesi terkunci. Masukkan PIN.');
    }
    final AuthUser? user = access.currentUser;
    if (user == null || !access.isAuthenticated) {
      throw const ForbiddenException('Anda harus masuk terlebih dahulu.');
    }
    if (!_policy.allows(user.role, permission)) {
      throw ForbiddenException(
        'Peran ${user.role.label} tidak memiliki izin ${permission.name}.',
      );
    }
  }

  bool can(AccessContext access, AppPermission permission) {
    if (!access.isAuthenticated || access.isLocked) {
      return false;
    }
    final AuthUser? user = access.currentUser;
    if (user == null) {
      return false;
    }
    return _policy.allows(user.role, permission);
  }
}
