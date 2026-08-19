library;

import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('production secret validation gagal bila JWT_SECRET kosong', () {
    final config = testConfig().copyWith(
      enforceProductionSecrets: true,
      jwtSecret: '',
    );
    expect(
      () => config.validateProductionSecrets(),
      throwsA(isA<StateError>()),
    );
  });

  test('production secret validation lolos bila secret terisi', () {
    final config = testConfig().copyWith(enforceProductionSecrets: true);
    expect(() => config.validateProductionSecrets(), returnsNormally);
  });
}
