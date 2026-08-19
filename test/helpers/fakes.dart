import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/features/auth/domain/auth_repository.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/auth/domain/session.dart';
import 'package:kasir_dapur/features/auth/domain/session_repository.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_period.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_repository.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:kasir_dapur/features/reports/domain/report_filter.dart';
import 'package:kasir_dapur/features/reports/domain/report_repository.dart';
import 'package:kasir_dapur/features/reports/domain/report_snapshot.dart';
import 'package:kasir_dapur/services/settings_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    AuthUser? user,
    this.authenticateSucceeds = true,
    List<AuthUser>? users,
  }) : users = users ?? [?user];

  List<AuthUser> users;
  bool authenticateSucceeds;
  String? lastPin;

  @override
  Future<AuthUser?> getById(String id) async {
    for (final AuthUser user in users) {
      if (user.id == id) {
        return user;
      }
    }
    return null;
  }

  @override
  Future<List<AuthUser>> listUsers() async => List<AuthUser>.from(users);

  @override
  Future<bool> hasLocalUser() async => users.isNotEmpty;

  @override
  Future<AuthUser> registerOwner({
    required String displayName,
    required String pin,
  }) async {
    lastPin = pin;
    final AuthUser user = AuthUser(
      id: 'user-1',
      displayName: displayName.trim(),
      role: UserRole.owner,
    );
    users = [user];
    return user;
  }

  @override
  Future<AuthUser> createUser({
    required String displayName,
    required String pin,
    required UserRole role,
  }) async {
    lastPin = pin;
    final AuthUser user = AuthUser(
      id: 'user-${users.length + 1}',
      displayName: displayName.trim(),
      role: role,
    );
    users = [...users, user];
    return user;
  }

  @override
  Future<AuthUser?> authenticate({required String pin, String? userId}) async {
    lastPin = pin;
    if (!authenticateSucceeds) {
      return null;
    }
    if (userId != null) {
      return getById(userId);
    }
    return users.isEmpty ? null : users.first;
  }

  @override
  Future<void> changePin({
    required String userId,
    required String currentPin,
    required String newPin,
  }) async {
    lastPin = newPin;
    if (!authenticateSucceeds) {
      throw const AuthException('PIN saat ini tidak sesuai');
    }
  }

  @override
  Future<void> deleteAllLocalUsers() async {
    users = const <AuthUser>[];
  }
}

class FakeSessionRepository implements SessionRepository {
  AuthSession? session;

  @override
  Future<AuthSession?> current() async => session;

  @override
  Future<AuthSession> start({required String userId}) async {
    session = AuthSession(
      id: 'session-1',
      userId: userId,
      startedAt: 1,
      lastActiveAt: 1,
      locked: false,
    );
    return session!;
  }

  @override
  Future<AuthSession> touch(String id) async {
    final AuthSession current =
        session ??
        AuthSession(
          id: id,
          userId: '',
          startedAt: 1,
          lastActiveAt: 1,
          locked: false,
        );
    session = current.copyWith(lastActiveAt: current.lastActiveAt + 1);
    return session!;
  }

  @override
  Future<AuthSession> setLocked({
    required String id,
    required bool locked,
  }) async {
    final AuthSession current =
        session ??
        AuthSession(
          id: id,
          userId: '',
          startedAt: 1,
          lastActiveAt: 1,
          locked: locked,
        );
    session = current.copyWith(locked: locked);
    return session!;
  }

  @override
  Future<void> clear() async {
    session = null;
  }
}

class FakeSettingsRepository implements SettingsRepository {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class FakeDashboardRepository implements DashboardRepository {
  FakeDashboardRepository({
    this.snapshot = const DashboardSnapshot.empty(),
    this.error,
  });

  DashboardSnapshot snapshot;
  Object? error;
  DashboardDateRange? lastRange;

  @override
  Future<DashboardSnapshot> load({required DashboardDateRange range}) async {
    lastRange = range;
    final Object? fail = error;
    if (fail != null) {
      throw fail;
    }
    return snapshot;
  }
}

class FakeReportRepository implements ReportRepository {
  FakeReportRepository({
    this.snapshot = const ReportSnapshot.empty(),
    this.options = const ReportFilterOptions(),
    this.error,
  });

  ReportSnapshot snapshot;
  ReportFilterOptions options;
  Object? error;
  ReportQuery? lastQuery;

  @override
  Future<ReportSnapshot> load(ReportQuery query) async {
    lastQuery = query;
    final Object? fail = error;
    if (fail != null) {
      throw fail;
    }
    return snapshot;
  }

  @override
  Future<ReportFilterOptions> filterOptions() async {
    final Object? fail = error;
    if (fail != null) {
      throw fail;
    }
    return options;
  }
}
