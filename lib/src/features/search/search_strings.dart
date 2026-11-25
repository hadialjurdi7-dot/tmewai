import 'dart:ui' show Locale;

/// User-visible search strings, in both supported locales.
///
/// The search screen owns these strings instead of adding keys to
/// `app_strings.dart`: the screen is being extended independently, and keeping
/// its new copy together prevents a locale from silently missing a label.
class SearchStrings {
  const SearchStrings({required this.isArabic});

  factory SearchStrings.forLocale(Locale locale) =>
      SearchStrings(isArabic: locale.languageCode == 'ar');

  final bool isArabic;

  static const String everyWordEn = 'All words must match.';
  static const String everyWordAr = 'لازم تطابق كل الكلمات.';

  static const String resultOneEn = 'result';
  static const String resultsManyEn = 'results';
  static const String resultOneAr = 'نتيجة';
  static const String resultsManyAr = 'نتائج';

  static const String showingFirstEn = 'Showing the first';
  static const String showingFirstOfEn = 'of';
  static const String showingFirstAr = 'تُعرض أول';
  static const String showingFirstOfAr = 'من';

  static const String activeFiltersEn = 'Active filters';
  static const String activeFiltersAr = 'المرشحات النشطة';

  static const String typeLabelEn = 'Type';
  static const String typeLabelAr = 'النوع';
  static const String fromLabelEn = 'From';
  static const String fromLabelAr = 'من';
  static const String toLabelEn = 'To';
  static const String toLabelAr = 'إلى';

  static const String removeFilterEn = 'Remove this filter';
  static const String removeFilterAr = 'إزالة هذا المرشح';

  static const String widenEn = 'Widen the search';
  static const String widenAr = 'وسّع البحث';
  static const String widenHintEn = 'Clears every filter but keeps the words.';
  static const String widenHintAr = 'يمسح كل المرشحات ويبقي الكلمات.';

  static const String noMatchEn = 'No records contain';
  static const String noMatchAr = 'لا توجد سجلات تحتوي';
  static const String noMatchTryEn =
      'Try a shorter word or a different spelling.';
  static const String noMatchTryAr = 'جرّب كلمة أقصر أو كتابة مختلفة.';
  static const String narrowedEn = 'These filters narrowed the search.';
  static const String narrowedAr = 'هذه المرشحات ضيّقت البحث.';

  static const String conversationEn = 'Conversation';
  static const String conversationAr = 'المحادثة';
  static const String personEn = 'Person';
  static const String personAr = 'الشخص';
  static const String dateEn = 'Date';
  static const String dateAr = 'التاريخ';
  static const String unknownConversationEn = 'No conversation in the archive';
  static const String unknownConversationAr = 'لا محادثة في الأرشيف';
  static const String unknownPersonEn = 'No person recorded';
  static const String unknownPersonAr = 'لا شخص مسجّل';

  static const String semanticIndexActionEn = 'Build semantic index';
  static const String semanticIndexActionAr = 'فهرسة البحث الذكي';
  static const String semanticIndexingEn = 'Building the semantic index…';
  static const String semanticIndexingAr = 'جارٍ بناء فهرس البحث الذكي…';
  static const String semanticModeEn = 'Hybrid semantic ranking';
  static const String semanticModeAr = 'ترتيب دلالي مدمج';

  static const String semanticDownloadEn = 'Download the model';
  static const String semanticDownloadAr = 'تنزيل النموذج';
  static const String semanticDownloadingEn = 'Downloading the model…';
  static const String semanticDownloadingAr = 'جارٍ تنزيل النموذج…';
  static const String semanticDownloadFailedEn =
      'The model could not be installed. Search stays on exact words.';
  static const String semanticDownloadFailedAr =
      'ما زبط تثبيت النموذج. البحث بيضل على الكلمات.';
  static const String semanticConsentEn =
      'Downloading is your approval: the model and every embedding stay on '
      'this device. Nothing is sent.';
  static const String semanticConsentAr =
      'التنزيل هو موافقتك: النموذج وكل المعالجة بيضلوا على جهازك. ولا شي '
      'بيتبعت.';

  String get everyWord => isArabic ? everyWordAr : everyWordEn;

  String get activeFilters => isArabic ? activeFiltersAr : activeFiltersEn;
  String get typeLabel => isArabic ? typeLabelAr : typeLabelEn;
  String get fromLabel => isArabic ? fromLabelAr : fromLabelEn;
  String get toLabel => isArabic ? toLabelAr : toLabelEn;
  String get removeFilter => isArabic ? removeFilterAr : removeFilterEn;
  String get widen => isArabic ? widenAr : widenEn;
  String get widenHint => isArabic ? widenHintAr : widenHintEn;
  String get noMatch => isArabic ? noMatchAr : noMatchEn;
  String get noMatchTry => isArabic ? noMatchTryAr : noMatchTryEn;
  String get narrowed => isArabic ? narrowedAr : narrowedEn;
  String get conversation => isArabic ? conversationAr : conversationEn;
  String get person => isArabic ? personAr : personEn;
  String get date => isArabic ? dateAr : dateEn;
  String get unknownConversation =>
      isArabic ? unknownConversationAr : unknownConversationEn;
  String get unknownPerson => isArabic ? unknownPersonAr : unknownPersonEn;
  String get semanticIndexAction =>
      isArabic ? semanticIndexActionAr : semanticIndexActionEn;
  String get semanticIndexing =>
      isArabic ? semanticIndexingAr : semanticIndexingEn;
  String get semanticMode => isArabic ? semanticModeAr : semanticModeEn;
  String get semanticDownload =>
      isArabic ? semanticDownloadAr : semanticDownloadEn;
  String get semanticDownloading =>
      isArabic ? semanticDownloadingAr : semanticDownloadingEn;
  String get semanticDownloadFailed =>
      isArabic ? semanticDownloadFailedAr : semanticDownloadFailedEn;
  String get semanticConsent =>
      isArabic ? semanticConsentAr : semanticConsentEn;

  String quote(String term) => isArabic ? '«$term»' : '“$term”';

  /// The one-line partial-index status, e.g. "بحث ذكي على 12 من 300 رسالة".
  String semanticPartial(int indexed, int total) => isArabic
      ? 'بحث ذكي على $indexed من $total رسالة'
      : 'Semantic search on $indexed of $total messages';

  /// The model is not installed yet; [megabytes] is the real download size.
  String semanticModelMissing(int megabytes) => isArabic
      ? 'نموذج البحث الذكي غير مثبّت ($megabytes ميغابايت). كل شي بيضل على '
            'جهازك.'
      : 'The semantic search model is not installed ($megabytes MB). '
            'Everything stays on this device.';

  /// The model is installed and verified but nothing has been indexed yet.
  String semanticReady(int total) => isArabic
      ? 'البحث الذكي جاهز — $total رسالة بلا فهرس بعد'
      : 'Semantic search is ready — $total messages are not indexed yet';

  /// Rows done / planned while a run is in flight.
  String semanticProgress(int done, int total) =>
      isArabic ? '$done من $total' : '$done of $total';

  /// "3 results for “alpha”" in the active language.
  String resultsFor(int count, String term) {
    final noun = count == 1
        ? (isArabic ? resultOneAr : resultOneEn)
        : (isArabic ? resultsManyAr : resultsManyEn);
    return isArabic
        ? '$count $noun لـ${quote(term)}'
        : '$count $noun for ${quote(term)}';
  }

  /// "Showing the first 50 of 120."
  String showingFirst(int shown, int total) => isArabic
      ? '$showingFirstAr $shown $showingFirstOfAr $total.'
      : '$showingFirstEn $shown $showingFirstOfEn $total.';

  String typeFilter(String value) => '$typeLabel: $value';
  String fromFilter(String value) => '$fromLabel: $value';
  String toFilter(String value) => '$toLabel: $value';
}
