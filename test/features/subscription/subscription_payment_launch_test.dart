import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/features/subscription/presentation/subscription_page.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  test('parseSnapRedirectUrl menolak null/kosong/invalid scheme', () {
    expect(parseSnapRedirectUrl(null), isNull);
    expect(parseSnapRedirectUrl(''), isNull);
    expect(parseSnapRedirectUrl('   '), isNull);
    expect(parseSnapRedirectUrl('midtrans://pay'), isNull);
    expect(parseSnapRedirectUrl('javascript:alert(1)'), isNull);
    expect(parseSnapRedirectUrl('not-a-url'), isNull);
  });

  test('parseSnapRedirectUrl menerima url http/https valid', () {
    expect(
      parseSnapRedirectUrl('https://app.sandbox.midtrans.com/snap/v2/vtweb/abc')
          ?.toString(),
      'https://app.sandbox.midtrans.com/snap/v2/vtweb/abc',
    );
    expect(
      parseSnapRedirectUrl('http://localhost:8080/pay')?.toString(),
      'http://localhost:8080/pay',
    );
  });

  test('launchSnapRedirectUrl false jika URL null/invalid', () async {
    var called = false;
    Future<bool> fakeLauncher(
      Uri url, {
      LaunchMode mode = LaunchMode.platformDefault,
    }) async {
      called = true;
      return true;
    }

    expect(
      await launchSnapRedirectUrl(rawUrl: null, launcher: fakeLauncher),
      isFalse,
    );
    expect(
      await launchSnapRedirectUrl(rawUrl: 'not-a-url', launcher: fakeLauncher),
      isFalse,
    );
    expect(called, isFalse);
  });

  test(
    'launchSnapRedirectUrl memanggil launcher externalApplication',
    () async {
      Uri? launchedUrl;
      LaunchMode? launchedMode;
      Future<bool> fakeLauncher(
        Uri url, {
        LaunchMode mode = LaunchMode.platformDefault,
      }) async {
        launchedUrl = url;
        launchedMode = mode;
        return true;
      }

      final ok = await launchSnapRedirectUrl(
        rawUrl: 'https://app.sandbox.midtrans.com/snap/v2/vtweb/order-1',
        launcher: fakeLauncher,
      );
      expect(ok, isTrue);
      expect(launchedUrl, isNotNull);
      expect(launchedMode, LaunchMode.externalApplication);
    },
  );

  test('launchSnapRedirectUrl false jika launcher gagal', () async {
    Future<bool> fakeLauncher(
      Uri url, {
      LaunchMode mode = LaunchMode.platformDefault,
    }) async {
      return false;
    }

    final ok = await launchSnapRedirectUrl(
      rawUrl: 'https://app.sandbox.midtrans.com/snap/v2/vtweb/order-2',
      launcher: fakeLauncher,
    );
    expect(ok, isFalse);
  });
}
