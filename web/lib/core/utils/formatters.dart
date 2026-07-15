import 'package:intl/intl.dart';

final _dateTimeFmt = DateFormat('d MMM yyyy, HH:mm');
final _dateFmt = DateFormat('EEE, d MMM yyyy');
final _shortDateFmt = DateFormat('d MMM');
final _currencyFmt = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);

String formatDateTime(dynamic value) {
  if (value == null) return '—';
  final dt = value is DateTime ? value : DateTime.tryParse(value.toString());
  if (dt == null) return value.toString();
  return _dateTimeFmt.format(dt.toLocal());
}

String formatDate(dynamic value) {
  if (value == null) return '—';
  final dt = value is DateTime ? value : DateTime.tryParse(value.toString());
  if (dt == null) return value.toString();
  return _dateFmt.format(dt.toLocal());
}

String formatShortDate(dynamic value) {
  if (value == null) return '—';
  final dt = value is DateTime ? value : DateTime.tryParse(value.toString());
  if (dt == null) return value.toString();
  return _shortDateFmt.format(dt.toLocal());
}

String formatCurrency(num? value) {
  if (value == null) return '—';
  return _currencyFmt.format(value);
}

String formatLitres(num? value) {
  if (value == null) return '—';
  return '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)} L';
}

String formatPercent(num? value) => value == null ? '—' : '${value.toStringAsFixed(1)}%';

/// API JSON may return decimals as strings (e.g. Django DecimalField).
double? parseApiDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? parseApiInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String formatRole(String role) => switch (role) {
      'station_manager' => 'Station Manager',
      'super_admin' => 'Super Admin',
      'attendant' => 'Attendant',
      'admin' => 'Admin',
      'driver' => 'Driver',
      _ => role,
    };

String wsBaseFromApi(String apiBase) {
  var normalized = apiBase.trim();
  while (normalized.endsWith('/') || normalized.endsWith('\\')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  // Strip /api suffix for websocket root (ws://host:port)
  if (normalized.endsWith('/api')) {
    normalized = normalized.substring(0, normalized.length - 4);
  }
  final uri = Uri.parse(normalized);
  final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
  return '$scheme://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
}
