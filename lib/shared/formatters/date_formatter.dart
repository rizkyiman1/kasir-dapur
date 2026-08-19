import 'package:intl/intl.dart';

abstract final class DateFormatter {
  static String dateTimeId(DateTime value) {
    return DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(value);
  }

  static String dateId(DateTime value) {
    return DateFormat('dd MMM yyyy', 'id_ID').format(value);
  }
}
