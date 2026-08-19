import 'package:kasir_dapur/features/auth/domain/auth_user.dart';

enum AuthStatus {
  unknown,
  needsOnboarding,
  unauthenticated,
  authenticated,
  locked,
}

final class AuthState {
  const AuthState({required this.status, this.user});

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  const AuthState.needsOnboarding() : this(status: AuthStatus.needsOnboarding);

  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  const AuthState.authenticated(AuthUser user)
    : this(status: AuthStatus.authenticated, user: user);

  const AuthState.locked(AuthUser user)
    : this(status: AuthStatus.locked, user: user);

  final AuthStatus status;
  final AuthUser? user;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  bool get isLocked => status == AuthStatus.locked;
}
