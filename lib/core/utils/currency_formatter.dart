import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final _fmt = NumberFormat.currency(locale: 'es_DO', symbol: 'RD\$');

  static String format(double amount) => _fmt.format(amount);
}
