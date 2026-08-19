import 'package:kasir_dapur/features/auth/domain/session.dart';

abstract class SessionRepository {
  Future<AuthSession?> current();
  Future<AuthSession> start({required String userId});
  Future<AuthSession> touch(String id);
  Future<AuthSession> setLocked({required String id, required bool locked});
  Future<void> clear();
}
