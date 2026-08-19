import 'package:flutter/material.dart';
import 'package:kasir_dapur/widgets/kd_snack.dart';

extension ContextExt on BuildContext {
  void showError(Object error) => KdSnack.error(this, error);

  void showMessage(String message) => KdSnack.success(this, message);

  void showWarning(String message) => KdSnack.warning(this, message);

  void showInfo(String message) => KdSnack.info(this, message);
}
