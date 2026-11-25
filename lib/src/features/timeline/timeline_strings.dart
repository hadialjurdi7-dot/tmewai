import 'dart:ui' show Locale;

/// Strings added by the paged timeline.
///
/// Everything the screen already said stays in `AppStrings`; these are the
/// pagination and archive-size lines, kept here so the shared catalog is not
/// touched by this feature.
class TimelineStrings {
  const TimelineStrings._(this.isArabic);

  factory TimelineStrings.forLocale(Locale locale) =>
      TimelineStrings._(locale.languageCode == 'ar');

  final bool isArabic;

  String summary(int events, int groups) => isArabic
      ? '${_number(events)} حدثاً في ${_number(groups)} مجموعة'
      : '${_number(events)} events across ${_number(groups)} groups';

  String loadedOf(int loaded, int total) => isArabic
      ? 'المعروض ${_number(loaded)} من ${_number(total)}'
      : 'Showing ${_number(loaded)} of ${_number(total)}';

  String get loadMore => isArabic ? 'عرض المزيد' : 'Load more';

  String loadMoreRemaining(int remaining) => isArabic
      ? '$loadMore · ${_number(remaining)} متبقية'
      : '$loadMore · ${_number(remaining)} remaining';

  String get loadFailed => isArabic
      ? 'تعذّر تحميل أحداث هذه المجموعة.'
      : 'This group’s events could not be loaded.';
}

String _number(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}
