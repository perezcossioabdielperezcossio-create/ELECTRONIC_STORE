import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String toDisplay(DateTime dt) =>
      DateFormat('dd/MM/yyyy HH:mm').format(dt);

  static String toIso(DateTime dt) => dt.toIso8601String();

  static DateTime fromIso(String iso) => DateTime.parse(iso);
}
