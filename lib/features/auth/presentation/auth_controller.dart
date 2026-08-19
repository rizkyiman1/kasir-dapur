import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/core/logging/app_logger.dart';
import 'package:kasir_dapur/core/permissions/app_permission.dart';
import 'package:kasir_dapur/core/permissions/permission_guard.dart';
import 'package:kasir_dapur/core/result/result.dart';
import 'package:kasir_dapur/features/auth/domain/auth_repository.dart';
import 'package:kasir_dapur/features/auth/domain/auth_state.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/auth/domain/session.dart';
import 'package:kasir_dapur/features/auth/domain/session_repository.dart';
import 'package:kasir_dapur/features/auth/data/cloud_auth_session_service.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/services/clock_service.dart';

final class AuthController extends Notifier<AuthState> {
  Timer? _watchdog;
  int _lastTouchAt = 0;
  String? _sessionId;

  @override
  AuthState build() {
    final SessionConfig config = ref.read(sessionConfigProvider);
    if (config.checkInterval > Duration.zero) {
      _watchdog = Timer.periodic(config.checkInterval, (_) {
        unawaited(checkSession());
      });
      ref.onDispose(() => _watchdog?.cancel());
    }
    listenSelf((AuthState? previous, AuthState next) {
      ref.read(accessHolderProvider).value = AuthStateAccessContext(next);
    });
    return const AuthState.unknown();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  SessionRepository get _sessions => ref.read(sessionRepositoryProvider);
  CloudAuthSessionService get _cloudAuth =>
      ref.read(cloudAuthSessionServiceProvider);

  ClockService get _clock => ref.read(clockProvider);

  SessionConfig get _config => ref.read(sessionConfigProvider);

  PermissionGuard get _guard => ref.read(permissionGuardProvider);

  Future<void> restore() async {
    try {
      final List<AuthUser> users = await _repository.listUsers();
      if (users.isEmpty) {
        _sessionId = null;
        state = const AuthState.needsOnboarding();
        return;
      }
      await _applySession();
    } catch (error, stackTrace) {
      AppLogger.instance.error(
        'Gagal memulihkan sesi',
        error: error,
        stackTrace: stackTrace,
      );
      state = const AuthState.needsOnboarding();
    }
  }

  Future<Result<void>> completeOnboarding({
    required String displayName,
    required String pin,
  }) async {
    try {
      final AuthUser user = await _repository.registerOwner(
        displayName: displayName,
        pin: pin,
      );
      await _beginSession(user);
      await _syncCloudToken(userId: user.id, pin: pin);
      return const Success<void>(null);
    } on AppException catch (error) {
      return Failure<void>(error);
    } catch (error, stackTrace) {
      AppLogger.instance.error(
        'Onboarding gagal',
        error: error,
        stackTrace: stackTrace,
      );
      return Failure<void>(
        UnexpectedException(ErrorHandler.userMessage(error)),
      );
    }
  }

  Future<Result<void>> login({required String pin, String? userId}) async {
    try {
      final AuthUser? user = await _repository.authenticate(
        pin: pin,
        userId: userId,
      );
      if (user == null) {
        return const Failure<void>(AuthException('PIN tidak sesuai'));
      }
      await _beginSession(user);
      await _syncCloudToken(userId: user.id, pin: pin);
      return const Success<void>(null);
    } on AppException catch (error) {
      return Failure<void>(error);
    } catch (error, stackTrace) {
      AppLogger.instance.error(
        'Login gagal',
        error: error,
        stackTrace: stackTrace,
      );
      return Failure<void>(
        UnexpectedException(ErrorHandler.userMessage(error)),
      );
    }
  }

  Future<Result<AuthUser>> createUser({
    required String displayName,
    required String pin,
    required UserRole role,
  }) async {
    try {
      _guard.require(AuthStateAccessContext(state), AppPermission.manageUsers);
      await _assertPlanSeat(role);
      final AuthUser user = await _repository.createUser(
        displayName: displayName,
        pin: pin,
        role: role,
      );
      return Success<AuthUser>(user);
    } on AppException catch (error) {
      return Failure<AuthUser>(error);
    } catch (error, stackTrace) {
      AppLogger.instance.error(
        'Gagal menambah pengguna',
        error: error,
        stackTrace: stackTrace,
      );
      return Failure<AuthUser>(
        UnexpectedException(ErrorHandler.userMessage(error)),
      );
    }
  }

  Future<Result<void>> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final AuthUser? user = state.user;
    if (user == null || state.status != AuthStatus.authenticated) {
      return const Failure<void>(AuthException('Masuk terlebih dahulu.'));
    }
    try {
      await _repository.changePin(
        userId: user.id,
        currentPin: currentPin,
        newPin: newPin,
      );
      return const Success<void>(null);
    } on AppException catch (error) {
      return Failure<void>(error);
    } catch (error, stackTrace) {
      AppLogger.instance.error(
        'Gagal mengganti PIN',
        error: error,
        stackTrace: stackTrace,
      );
      return Failure<void>(
        UnexpectedException(ErrorHandler.userMessage(error)),
      );
    }
  }

  Future<Result<void>> deleteAccount() async {
    try {
      _guard.require(AuthStateAccessContext(state), AppPermission.manageUsers);
      if (state.user?.role != UserRole.owner) {
        return const Failure<void>(
          ForbiddenException(
            'Hanya Owner yang dapat menghapus akun perangkat.',
          ),
        );
      }
      await _sessions.clear();
      await _cloudAuth.clear();
      await _repository.deleteAllLocalUsers();
      _sessionId = null;
      state = const AuthState.needsOnboarding();
      return const Success<void>(null);
    } on AppException catch (error) {
      return Failure<void>(error);
    } catch (error, stackTrace) {
      AppLogger.instance.error(
        'Gagal menghapus akun perangkat',
        error: error,
        stackTrace: stackTrace,
      );
      return Failure<void>(
        UnexpectedException(ErrorHandler.userMessage(error)),
      );
    }
  }

  Future<void> logout() async {
    await _sessions.clear();
    await _cloudAuth.clear();
    _sessionId = null;
    if (state.status != AuthStatus.needsOnboarding &&
        state.status != AuthStatus.unknown) {
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> lock() async {
    final AuthUser? user = state.user;
    final String? sessionId = _sessionId;
    if (user == null ||
        (state.status != AuthStatus.authenticated &&
            state.status != AuthStatus.locked)) {
      return;
    }
    if (sessionId != null) {
      await _sessions.setLocked(id: sessionId, locked: true);
    }
    state = AuthState.locked(user);
  }

  Future<Result<void>> unlock(String pin) async {
    final AuthUser? user = state.user;
    if (user == null || state.status != AuthStatus.locked) {
      return const Failure<void>(AuthException('Sesi tidak terkunci.'));
    }
    try {
      final AuthUser? matched = await _repository.authenticate(
        pin: pin,
        userId: user.id,
      );
      if (matched == null) {
        return const Failure<void>(AuthException('PIN tidak sesuai'));
      }
      final String? sessionId = _sessionId;
      if (sessionId != null) {
        await _sessions.setLocked(id: sessionId, locked: false);
      }
      await _syncCloudToken(userId: matched.id, pin: pin);
      _lastTouchAt = _clock.nowEpochMs();
      state = AuthState.authenticated(matched);
      return const Success<void>(null);
    } on AppException catch (error) {
      return Failure<void>(error);
    } catch (error, stackTrace) {
      AppLogger.instance.error(
        'Buka kunci gagal',
        error: error,
        stackTrace: stackTrace,
      );
      return Failure<void>(
        UnexpectedException(ErrorHandler.userMessage(error)),
      );
    }
  }

  Future<void> onUserActivity() async {
    await checkSession(touchIfActive: true);
  }

  Future<void> checkSession({bool touchIfActive = false}) async {
    if (state.status != AuthStatus.authenticated &&
        state.status != AuthStatus.locked) {
      return;
    }
    await _applySession(touchIfActive: touchIfActive);
  }

  Future<void> _beginSession(AuthUser user) async {
    final AuthSession session = await _sessions.start(userId: user.id);
    _sessionId = session.id;
    _lastTouchAt = session.lastActiveAt;
    state = AuthState.authenticated(user);
  }

  Future<void> _applySession({bool touchIfActive = false}) async {
    final AuthSession? session = await _sessions.current();
    if (session == null) {
      _sessionId = null;
      state = const AuthState.unauthenticated();
      return;
    }
    _sessionId = session.id;
    final AuthUser? user = await _repository.getById(session.userId);
    if (user == null) {
      await _sessions.clear();
      _sessionId = null;
      state = const AuthState.unauthenticated();
      return;
    }
    final SessionVerdict verdict = SessionPolicy.evaluate(
      session: session,
      nowMs: _clock.nowEpochMs(),
      config: _config,
    );
    switch (verdict) {
      case SessionVerdict.expired:
        await _sessions.clear();
        await _cloudAuth.clear();
        _sessionId = null;
        state = const AuthState.unauthenticated();
      case SessionVerdict.locked:
        if (!session.locked) {
          await _sessions.setLocked(id: session.id, locked: true);
        }
        state = AuthState.locked(user);
      case SessionVerdict.active:
        final String? activeToken = await _cloudAuth.readAccessToken(
          expectedUserId: user.id,
        );
        if (activeToken == null) {
          await _cloudAuth.clear();
        }
        if (touchIfActive) {
          await _touchIfDue(session.id);
        }
        state = AuthState.authenticated(user);
    }
  }

  Future<void> _syncCloudToken({
    required String userId,
    required String pin,
  }) async {
    try {
      await _cloudAuth.issueToken(userId: userId, pin: pin);
    } on AppException catch (error) {
      AppLogger.instance.warning('Sesi cloud tidak tersedia: ${error.message}');
      await _cloudAuth.clear();
    } catch (error, stackTrace) {
      AppLogger.instance.error(
        'Gagal sinkronisasi sesi cloud.',
        error: error,
        stackTrace: stackTrace,
      );
      await _cloudAuth.clear();
    }
  }

  Future<void> _assertPlanSeat(UserRole role) async {
    final String businessId = await ref.read(activeBusinessIdProvider.future);
    final gate = await ref.read(subscriptionServiceProvider).gate(businessId);
    final List<AuthUser> users = await _repository.listUsers();
    if (role == UserRole.cashier) {
      final int used = users
          .where((AuthUser user) => user.role == UserRole.cashier)
          .length;
      gate.requireWithinLimit(FeatureKey.maxCashiers, used);
      return;
    }
    if (role == UserRole.admin) {
      gate.require(FeatureKey.multiUser);
    }
  }

  Future<void> _touchIfDue(String sessionId) async {
    final int now = _clock.nowEpochMs();
    if (now - _lastTouchAt < _config.touchDebounce.inMilliseconds) {
      return;
    }
    final AuthSession touched = await _sessions.touch(sessionId);
    _lastTouchAt = touched.lastActiveAt;
  }
}

@visibleForTesting
final class SeededAuthController extends AuthController {
  SeededAuthController({required this.user});

  final AuthUser user;

  @override
  AuthState build() => AuthState.authenticated(user);
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
