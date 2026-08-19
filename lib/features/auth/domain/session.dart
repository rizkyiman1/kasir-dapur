import 'package:kasir_dapur/core/constants/app_constants.dart';

enum SessionVerdict { active, locked, expired }

final class SessionConfig {
  const SessionConfig({
    this.idleLock = AppConstants.sessionIdleLock,
    this.maxDuration = AppConstants.sessionMaxDuration,
    this.checkInterval = AppConstants.sessionCheckInterval,
    this.touchDebounce = AppConstants.sessionTouchDebounce,
  });

  final Duration idleLock;
  final Duration maxDuration;
  final Duration checkInterval;
  final Duration touchDebounce;
}

final class AuthSession {
  const AuthSession({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.lastActiveAt,
    required this.locked,
  });

  final String id;
  final String userId;
  final int startedAt;
  final int lastActiveAt;
  final bool locked;

  AuthSession copyWith({int? lastActiveAt, bool? locked}) {
    return AuthSession(
      id: id,
      userId: userId,
      startedAt: startedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      locked: locked ?? this.locked,
    );
  }
}

abstract final class SessionPolicy {
  static SessionVerdict evaluate({
    required AuthSession session,
    required int nowMs,
    required SessionConfig config,
  }) {
    if (nowMs - session.startedAt >= config.maxDuration.inMilliseconds) {
      return SessionVerdict.expired;
    }
    if (session.locked) {
      return SessionVerdict.locked;
    }
    if (nowMs - session.lastActiveAt >= config.idleLock.inMilliseconds) {
      return SessionVerdict.locked;
    }
    return SessionVerdict.active;
  }
}
