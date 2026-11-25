import 'package:flutter/widgets.dart';

import '../../core/l10n/app_strings.dart';

/// The person screen's copy and its date/number formatting.
///
/// Every word comes from [AppStrings], the catalog the other screens read, so
/// an Arabic and an English build state the same thing. This class only fills
/// the catalog's placeholders and formats archive values; it never authors a
/// sentence of its own and never translates exported text (names, ids, quotes).
class PersonCopy {
  const PersonCopy(this.strings);

  final AppStrings strings;

  bool get isArabic => strings.locale.languageCode == 'ar';

  /// Month names stay here, as on the messages screen: they are formatting,
  /// not sentences, and the catalog holds no per-month keys.
  static const List<String> _monthsArabic = [
    'كانون الثاني',
    'شباط',
    'آذار',
    'نيسان',
    'أيار',
    'حزيران',
    'تموز',
    'آب',
    'أيلول',
    'تشرين الأول',
    'تشرين الثاني',
    'كانون الأول',
  ];

  static const List<String> _monthsEnglish = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static PersonCopy of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PersonCopyScope>();
    assert(scope != null, 'PersonCopy.of() needs a PersonCopyScope above it');
    return scope!.copy;
  }

  List<String> get months => isArabic ? _monthsArabic : _monthsEnglish;

  String get failed => strings.personFailed;
  String get retry => strings.personRetry;
  String get emptyTitle => strings.personEmptyTitle;
  String get emptyBody => strings.personEmptyBody;
  String get openConversation => strings.personOpenConversation;
  String get viewProfile => strings.personViewProfile;
  String get statMessages => strings.personStatMessages;
  String get statPhotos => strings.personStatPhotos;
  String get statFirst => strings.personStatFirst;
  String get statLast => strings.personStatLast;
  String get recentTitle => strings.personRecentTitle;
  String get recentSubtitle => strings.personRecentSubtitle;
  String get recentBadge => strings.personRecentBadge;
  String get recentEmpty => strings.personRecentEmpty;
  String get loadOlder => strings.personLoadOlder;
  String get pageFailed => strings.personPageFailed;
  String get photosSubtitle => strings.personPhotosSubtitle;
  String get allPhotos => strings.personAllPhotos;
  String get photosEmpty => strings.personPhotosEmpty;
  String get yearsTitle => strings.personYearsTitle;
  String get yearsSubtitle => strings.personYearsSubtitle;
  String get yearsEmpty => strings.personYearsEmpty;
  String get nearbyTitle => strings.personNearbyTitle;
  String get nearbyBadge => strings.personNearbyBadge;
  String get nearbyEmpty => strings.personNearbyEmpty;
  String get nearbyNote => strings.personNearbyNote;
  String get archiveTitle => strings.personArchiveTitle;
  String get archiveSubtitle => strings.personArchiveSubtitle;
  String get archiveIndexType => strings.personArchiveIndexType;
  String get archiveRecords => strings.personArchiveRecords;
  String get archiveLast => strings.personArchiveLast;
  String get memoryTitle => strings.personMemoryTitle;
  String get memoryEmpty => strings.personMemoryEmpty;
  String get shortcutsTitle => strings.personShortcutsTitle;
  String get shortcutsSubtitle => strings.personShortcutsSubtitle;
  String get importAction => strings.personImportAction;
  String get ownershipTitle => strings.personOwnershipTitle;
  String get ownershipBody => strings.personOwnershipBody;

  /// Label of a shortcut row, keyed by the row id: «ملفي» and «الأشخاص» are
  /// different rows even though both open the people section.
  String shortcut(String id) => switch (id) {
    'me' => strings.personNavMe,
    'home' => strings.personNavHome,
    'story' => strings.personNavStory,
    'analytics' => strings.personNavAnalytics,
    'messages' => strings.personNavMessages,
    'media' => strings.personNavMedia,
    'settings' => strings.personNavSettings,
    _ => strings.personNavPeople,
  };

  String heroPhotos(int count) =>
      _fill('person.heroPhotos', {'count': number(count)});

  String rangeMessages(int count) =>
      _fill('person.rangeMessages', {'count': number(count)});

  String rangeYear(int year) => _fill('person.rangeYear', {'year': '$year'});

  String rangeYears(int from, int to) =>
      _fill('person.rangeYears', {'from': '$from', 'to': '$to'});

  /// The exported platform id, or null when the export did not record one.
  String? platformId(String? id) {
    final trimmed = id?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return _fill('person.platformId', {'id': trimmed});
  }

  String loadedCount(int loaded, int total) => _fill('person.loadedCount', {
    'loaded': number(loaded),
    'total': number(total),
  });

  String photosTitle(int count) =>
      _fill('person.photosTitle', {'count': number(count)});

  String yearsTotal(int count) =>
      _fill('person.yearsTotal', {'count': number(count)});

  String yearsPeak(int year) => _fill('person.yearsPeak', {'year': '$year'});

  String nearbyRank(int rank) =>
      _fill('person.nearbyRank', {'rank': number(rank)});

  /// Platform names are translated; an unknown platform keeps its stored id.
  String platformLabel(String platform) => switch (platform) {
    'facebook' => strings.personPlatformFacebook,
    'instagram' => strings.personPlatformInstagram,
    'whatsapp' => strings.personPlatformWhatsapp,
    _ => platform,
  };

  /// A UTC day as “12 آذار 2013” / “12 March 2013”.
  String day(DateTime? value) {
    if (value == null) return strings.personUndated;
    final utc = value.toUtc();
    return '${utc.day} ${months[utc.month - 1]} ${utc.year}';
  }

  /// A UTC day with its stored clock time.
  String moment(DateTime? value) {
    if (value == null) return strings.personUndated;
    final utc = value.toUtc();
    final hour = utc.hour % 12 == 0 ? 12 : utc.hour % 12;
    final minute = utc.minute.toString().padLeft(2, '0');
    final period = isArabic
        ? (utc.hour < 12 ? 'ص' : 'م')
        : (utc.hour < 12 ? 'AM' : 'PM');
    return '${day(utc)} · $hour:$minute $period';
  }

  /// How old the quoted line is, always from its stored year.
  String memoryAge(DateTime? value) {
    if (value == null) return strings.personUndated;
    final utc = value.toUtc();
    final years = DateTime.now().toUtc().year - utc.year;
    if (years <= 0) {
      return _fill('person.thisYear', {'year': '${utc.year}'});
    }
    return _fill(years == 1 ? 'person.yearAgo' : 'person.yearsAgo', {
      'count': '$years',
      'year': '${utc.year}',
    });
  }

  /// Thousands separators without a locale package; digits stay Latin.
  String number(int value) {
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
      buffer.write(digits[index]);
    }
    return value < 0 ? '-$buffer' : buffer.toString();
  }

  String _fill(String key, Map<String, String> values) {
    var text = strings[key];
    values.forEach((name, value) => text = text.replaceAll('{$name}', value));
    return text;
  }
}

/// Publishes one [PersonCopy] to the person screen's descendants, so a card
/// deep in the tree reads the same locale as the header without plumbing.
class PersonCopyScope extends InheritedWidget {
  const PersonCopyScope({
    super.key,
    required this.copy,
    required super.child,
  });

  final PersonCopy copy;

  @override
  bool updateShouldNotify(PersonCopyScope oldWidget) =>
      oldWidget.copy.strings != copy.strings ||
      oldWidget.copy.isArabic != copy.isArabic;
}
