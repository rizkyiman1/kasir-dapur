import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/features/barcode/data/camera_permission_port.dart';
import 'package:kasir_dapur/features/barcode/domain/camera_permission.dart';

void main() {
  test('port memori tidak melempar saat izin ditolak', () async {
    final MemoryCameraPermissionPort port = MemoryCameraPermissionPort(
      access: CameraAccess.denied,
    );
    expect(await port.status(), CameraAccess.denied);
    expect(await port.request(), CameraAccess.denied);
    expect(await port.openSettings(), isTrue);
    expect(port.settingsOpened, isTrue);
  });
}
