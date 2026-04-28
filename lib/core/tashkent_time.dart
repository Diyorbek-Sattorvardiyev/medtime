DateTime tashkentNow() => DateTime.now().toUtc().add(const Duration(hours: 5));

String tashkentDateOnly() {
  final now = tashkentNow();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}
