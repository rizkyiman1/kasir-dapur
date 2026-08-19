import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/features/auth/domain/session.dart';

void main() {
  const SessionConfig config = SessionConfig(
    idleLock: Duration(minutes: 5),
    maxDuration: Duration(hours: 12),
  );

  AuthSession session({
    int startedAt = 0,
    int lastActiveAt = 0,
    bool locked = false,
  }) {
    return AuthSession(
      id: 's1',
      userId: 'u1',
      startedAt: startedAt,
      lastActiveAt: lastActiveAt,
      locked: locked,
    );
  }

  test('sesi aktif jika masih dalam idle dan durasi maksimum', () {
    expect(
      SessionPolicy.evaluate(
        session: session(),
        nowMs: const Duration(minutes: 4).inMilliseconds,
        config: config,
      ),
      SessionVerdict.active,
    );
  });

  test('idle timeout mengunci sesi', () {
    expect(
      SessionPolicy.evaluate(
        session: session(),
        nowMs: const Duration(minutes: 5).inMilliseconds,
        config: config,
      ),
      SessionVerdict.locked,
    );
  });

  test('kunci manual tetap terkunci sebelum kadaluarsa', () {
    expect(
      SessionPolicy.evaluate(
        session: session(locked: true),
        nowMs: const Duration(minutes: 1).inMilliseconds,
        config: config,
      ),
      SessionVerdict.locked,
    );
  });

  test('durasi maksimum mengakhiri sesi', () {
    expect(
      SessionPolicy.evaluate(
        session: session(locked: true),
        nowMs: const Duration(hours: 12).inMilliseconds,
        config: config,
      ),
      SessionVerdict.expired,
    );
  });
}
