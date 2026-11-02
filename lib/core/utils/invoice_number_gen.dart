import 'package:intl/intl.dart';
import 'dart:math';

class InvoiceNumberGen {
  InvoiceNumberGen._();

  static String generate() {
    final now = DateTime.now();
    final datePart = DateFormat('yyMMdd').format(now);
    final timePart = DateFormat('HHmmss').format(now);
    final rand = Random().nextInt(9999).toString().padLeft(4, '0');
    return 'TI-$datePart-$timePart-$rand';
  }
}
