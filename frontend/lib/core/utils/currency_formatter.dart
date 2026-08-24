import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _indianFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _compactIndianFormat = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  static String format(double? amount, {bool showSymbol = true}) {
    if (amount == null) return showSymbol ? '₹0.00' : '0.00';
    if (!showSymbol) {
      return NumberFormat.currency(
        locale: 'en_IN',
        symbol: '',
        decimalDigits: 2,
      ).format(amount).trim();
    }
    return _indianFormat.format(amount);
  }

  static String formatCompact(double? amount) {
    if (amount == null) return '₹0';
    return _compactIndianFormat.format(amount);
  }

  static String formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String formatDateShort(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd/MM/yyyy').format(date);
  }
}
