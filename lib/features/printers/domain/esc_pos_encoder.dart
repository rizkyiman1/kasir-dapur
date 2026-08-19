/// ESC/POS minimal untuk printer thermal 58mm/80mm.
abstract final class EscPosEncoder {
  static const List<int> _init = <int>[0x1B, 0x40];
  static const List<int> _alignCenter = <int>[0x1B, 0x61, 0x01];
  static const List<int> _alignLeft = <int>[0x1B, 0x61, 0x00];
  static const List<int> _boldOn = <int>[0x1B, 0x45, 0x01];
  static const List<int> _boldOff = <int>[0x1B, 0x45, 0x00];
  static const List<int> _feed = <int>[0x1B, 0x64, 0x04];
  static const List<int> _partialCut = <int>[0x1D, 0x56, 0x41, 0x03];

  static List<int> encodeLines(
    List<String> lines, {
    int centeredHeaderLines = 3,
  }) {
    final List<int> bytes = [..._init, ..._alignCenter, ..._boldOn];
    for (int i = 0; i < lines.length; i++) {
      if (i == centeredHeaderLines) {
        bytes
          ..addAll(_boldOff)
          ..addAll(_alignLeft);
      }
      bytes
        ..addAll(_latin(lines[i]))
        ..add(0x0A);
    }
    bytes
      ..addAll(_feed)
      ..addAll(_partialCut);
    return bytes;
  }

  static List<int> _latin(String text) {
    return [for (final int code in text.runes) code <= 0xFF ? code : 0x3F];
  }
}
