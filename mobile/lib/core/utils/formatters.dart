import 'package:intl/intl.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _inrDecimal = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _date = DateFormat('d MMM yyyy');
final _dateTime = DateFormat('d MMM yyyy, h:mm a');

String formatInr(num amount) => _inr.format(amount);
String formatInrDecimal(num amount) => _inrDecimal.format(amount);
String formatDate(DateTime dt) => _date.format(dt);
String formatDateTime(DateTime dt) => _dateTime.format(dt);

String formatDateString(String? iso) {
  if (iso == null) return '—';
  return formatDate(DateTime.parse(iso).toLocal());
}
