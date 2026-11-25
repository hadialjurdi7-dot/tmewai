import '../../core/l10n/import_labels.dart';
import '../../data/repositories/event_search_repository.dart';
import '../../data/repositories/overview_repository.dart';

/// One event type and how many events carry it.
class AnalyticsType {
  const AnalyticsType({required this.type, required this.count});

  final String type;
  final int count;
}

/// One person and their message count in the selected period.
class AnalyticsPerson {
  const AnalyticsPerson({
    required this.id,
    required this.name,
    required this.count,
  });

  final int id;
  final String name;
  final int count;
}

/// A word counted by the local full-text index.
class AnalyticsTerm {
  const AnalyticsTerm({required this.term, required this.occurrences});

  final String term;
  final int occurrences;
}

/// Everything «التحليلات» shows for one year filter (or the whole archive).
class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.selectedYear,
    required this.years,
    required this.totals,
    required this.months,
    required this.hours,
    required this.types,
    required this.people,
    this.terms = const [],
    this.longestConversationCount,
    this.busiestYear,
    this.busiestYearCount,
  });

  /// Null means «كل السنوات»: no year filter.
  final int? selectedYear;

  /// The last five years with messages, newest first — the chip row.
  final List<int> years;

  final ArchiveTotals totals;

  /// Twelve buckets, January first. Missing months are zero.
  final List<({int month, int count})> months;

  /// Twenty-four buckets, 00:00 UTC first.
  final List<({int hour, int count})> hours;

  final List<AnalyticsType> types;
  final List<AnalyticsPerson> people;

  /// Words ranked by the local FTS index, highest first.
  final List<AnalyticsTerm> terms;

  /// The conversation with the most archived messages.
  final int? longestConversationCount;

  /// The archive year with the most events, with its event count.
  final int? busiestYear;
  final int? busiestYearCount;

  bool get isEmpty => totals.events == 0 && totals.photos == 0;

  int get typeTotal => types.fold<int>(0, (sum, type) => sum + type.count);

  /// «شو أكثر شي بتشارك» counts shares, not messages: a message is a
  /// conversation, not something the user shared. Typed payloads
  /// (`message_photo`, `message_link`, …) are messages too.
  List<AnalyticsType> get shareTypes => [
    for (final type in types)
      if (!isMessageEventType(type.type)) type,
  ];

  int get shareTotal =>
      shareTypes.fold<int>(0, (sum, type) => sum + type.count);

  int get monthMax =>
      months.fold<int>(0, (max, m) => m.count > max ? m.count : max);

  int get hourMax =>
      hours.fold<int>(0, (max, h) => h.count > max ? h.count : max);

  int? get busiestMonth {
    if (monthMax == 0) return null;
    return months.firstWhere((m) => m.count == monthMax).month;
  }

  /// Hour bucket with the most messages, or null when nothing is dated.
  int? get busiestHour {
    if (hourMax == 0) return null;
    return hours.firstWhere((h) => h.count == hourMax).hour;
  }

  /// Distinct record types present in the period.
  int get recordTypeCount => types.length;

  /// Average messages per dated day in the period.
  int? get dailyAverage {
    if (totals.days == 0) return null;
    return totals.messages ~/ totals.days;
  }
}

/// Builds the analytics screen from single-statement aggregates.
class AnalyticsService {
  const AnalyticsService(this.repository, this.search);

  final OverviewRepository repository;
  final EventSearchRepository search;

  Future<AnalyticsSnapshot> load({int? year}) async {
    // Chips come from every dated event type, not messages only, so a year the
    // charts below can show is never missing from the filter.
    final yearRows = await repository.countsByYear(eventType: null);
    final years = yearRows.reversed
        .take(5)
        .map((row) => row.year)
        .toList(growable: false);

    int? busiestYear;
    int? busiestYearCount;
    for (final row in yearRows) {
      if (busiestYearCount == null || row.count > busiestYearCount) {
        busiestYear = row.year;
        busiestYearCount = row.count;
      }
    }

    final totals = await repository.archiveTotals(year: year);
    final monthRows = await repository.countsByMonth(year: year);
    final hourRows = await repository.countsByHour(year: year);
    final typeRows = await repository.countsByEventType(year: year);
    final peopleRows = await repository.topPeople(limit: 7, year: year);
    final conversations = await repository.topConversations(
      limit: 1,
      year: year,
    );
    final terms = await search.topTerms(limit: 9);

    final monthCounts = {for (final row in monthRows) row.month: row.count};
    final hourCounts = {for (final row in hourRows) row.hour: row.count};

    return AnalyticsSnapshot(
      selectedYear: year,
      years: List.unmodifiable(years),
      totals: totals,
      months: List.unmodifiable([
        for (var month = 1; month <= 12; month++)
          (month: month, count: monthCounts[month] ?? 0),
      ]),
      hours: List.unmodifiable([
        for (var hour = 0; hour < 24; hour++)
          (hour: hour, count: hourCounts[hour] ?? 0),
      ]),
      types: List.unmodifiable([
        for (final row in typeRows)
          AnalyticsType(type: row.eventType, count: row.count),
      ]),
      people: List.unmodifiable([
        for (final row in peopleRows)
          AnalyticsPerson(id: row.id, name: row.name, count: row.count),
      ]),
      terms: List.unmodifiable([
        for (final term in terms)
          AnalyticsTerm(term: term.term, occurrences: term.occurrences),
      ]),
      longestConversationCount: conversations.isEmpty
          ? null
          : conversations.first.count,
      busiestYear: busiestYear,
      busiestYearCount: busiestYearCount,
    );
  }
}
