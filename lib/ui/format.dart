// Mise en forme à la française (virgule décimale, jours et mois en toutes lettres).

const _weekdays = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _weekdaysShort = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
const _months = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// `12.5` → `12,5` ; les décimales nulles sont supprimées (`21.0` → `21`).
String formatNumber(double value, {int decimals = 1}) {
  final fixed = value.toStringAsFixed(decimals);
  final trimmed = fixed.contains('.') ? fixed.replaceFirst(RegExp(r'\.?0+$'), '') : fixed;
  return trimmed.replaceAll('.', ',');
}

/// `21.5` → `21,5°` ; valeur absente → `--°`.
String formatTemp(double? value) => value == null ? '--°' : '${formatNumber(value)}°';

String weekdayShort(int weekday) => _weekdaysShort[(weekday - 1) % 7];

/// « samedi 7 novembre »
String formatLongDate(DateTime date) => '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';

/// « 18:05 »
String formatClock(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String greetingFor(DateTime date) {
  final h = date.hour;
  if (h >= 5 && h < 12) return 'Bonjour';
  if (h >= 12 && h < 18) return 'Bon après-midi';
  return 'Bonsoir';
}

/// Accorde un mot au pluriel : `plural(2, 'lumière')` → `2 lumières`.
String plural(int count, String singular, [String? pluralForm]) =>
    '$count ${count > 1 ? (pluralForm ?? '${singular}s') : singular}';
