import 'package:intl/intl.dart';

class CurrencyFormatter {
  CurrencyFormatter._();

  static final _fmt = NumberFormat('#,##0.00', 'en_US');

  /// Returns e.g. "GHC 1,250.00"
  static String format(double amount) => 'GHC ${_fmt.format(amount)}';

  /// Returns e.g. "1,250.00"
  static String formatRaw(double amount) => _fmt.format(amount);
}
