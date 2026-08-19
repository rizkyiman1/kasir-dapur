import 'package:kasir_dapur/features/barcode/domain/camera_permission.dart';
import 'package:permission_handler/permission_handler.dart';

final class PermissionHandlerCameraPort implements CameraPermissionPort {
  const PermissionHandlerCameraPort();

  @override
  Future<CameraAccess> status() {
    return _map(Permission.camera.status);
  }

  @override
  Future<CameraAccess> request() {
    return _map(Permission.camera.request());
  }

  @override
  Future<bool> openSettings() => openAppSettings();

  Future<CameraAccess> _map(Future<PermissionStatus> future) async {
    try {
      final PermissionStatus status = await future;
      if (status.isGranted || status.isLimited) {
        return CameraAccess.granted;
      }
      if (status.isPermanentlyDenied || status.isRestricted) {
        return CameraAccess.permanentlyDenied;
      }
      return CameraAccess.denied;
    } catch (_) {
      return CameraAccess.unavailable;
    }
  }
}

final class MemoryCameraPermissionPort implements CameraPermissionPort {
  MemoryCameraPermissionPort({
    this.access = CameraAccess.denied,
    this.settingsOpened = false,
  });

  CameraAccess access;
  bool settingsOpened;

  @override
  Future<CameraAccess> status() async => access;

  @override
  Future<CameraAccess> request() async => access;

  @override
  Future<bool> openSettings() async {
    settingsOpened = true;
    return true;
  }
}
