import 'dart:ui' show Locale;

/// Strings added by the paged message thread.
///
/// The screen's existing wording is unchanged; these cover paging, the honest
/// loaded count, and in-thread search. They stay in this feature so the shared
/// `app_strings.dart` catalog is not edited by another lane.
class MessagesStrings {
  const MessagesStrings._(this.isArabic);

  factory MessagesStrings.forLocale(Locale locale) =>
      MessagesStrings._(locale.languageCode == 'ar');

  final bool isArabic;

  String loadedOf(int loaded, int total) => isArabic
      ? 'تم تحميل ${_number(loaded)} من ${_number(total)}'
      : 'Loaded ${_number(loaded)} of ${_number(total)}';

  String get searchHint => isArabic
      ? 'دوّر داخل هالمحادثة'
      : 'Search this conversation';

  String searchResults(int count) => isArabic
      ? 'نتائج البحث: ${_number(count)}'
      : 'Search results: ${_number(count)}';

  String get searching => isArabic ? 'جارٍ البحث في المحادثة…' : 'Searching…';

  String get searchFailed => isArabic
      ? 'تعذّر البحث في هذه المحادثة.'
      : 'This conversation could not be searched.';

  String get noSearchResults => isArabic
      ? 'ما في رسالة بهالمحادثة تطابق البحث.'
      : 'No message in this conversation matches.';

  String get pageFailed => isArabic
      ? 'تعذّر تحميل الرسائل الأقدم.'
      : 'Older messages could not be loaded.';

  /// Tooltip of a tappable sender name in the open thread.
  String get openParticipantProfile => isArabic
      ? 'افتح ملف المشارك'
      : 'Open this participant’s profile';
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
