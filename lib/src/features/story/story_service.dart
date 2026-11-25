import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/event_search_repository.dart';
import '../../data/repositories/overview_repository.dart';

/// One year of message counts.
class StoryYear {
  const StoryYear({required this.year, required this.count});

  final int year;
  final int count;
}

/// A word counted by the local full-text index.
class StoryTerm {
  const StoryTerm({required this.term, required this.occurrences});

  final String term;
  final int occurrences;
}

/// One person of the «مع مين كنت تحكي» ranking.
class StoryPerson {
  const StoryPerson({
    required this.id,
    required this.name,
    required this.count,
  });

  final int id;
  final String name;
  final int count;
}

/// One image the memories card can show; metadata only, bytes are never read.
class StoryMemory {
  const StoryMemory({
    required this.id,
    required this.at,
    required this.mediaType,
  });

  final int id;

  /// UTC instant of the event that carries the image.
  final DateTime at;
  final String mediaType;
}

/// Everything «قصتك بالأرقام» shows, all read from the local archive.
class StorySnapshot {
  const StorySnapshot({
    required this.totals,
    required this.years,
    required this.terms,
    this.people = const [],
    this.memories = const [],
    this.memoryMonth,
    this.busiestYear,
    this.busiestTotals,
    this.topPersonName,
    this.topPersonCount,
    this.longestConversationCount,
    this.busiestMonth,
    this.recordTypes = 0,
    this.datedEvents = 0,
    this.undatedEvents = 0,
  });

  final ArchiveTotals totals;

  /// Message counts per year, oldest first.
  final List<StoryYear> years;

  /// Words ranked by the FTS index; empty when no text is indexed yet.
  final List<StoryTerm> terms;

  /// The people talked to most, highest first.
  final List<StoryPerson> people;

  /// Images of [memoryMonth], newest first, at most two.
  final List<StoryMemory> memories;

  /// The UTC month (1..12) the newest archived image belongs to.
  final int? memoryMonth;

  /// Year with the most message events, and its own totals.
  final int? busiestYear;
  final ArchiveTotals? busiestTotals;

  final String? topPersonName;
  final int? topPersonCount;

  /// The conversation with the most archived messages.
  final int? longestConversationCount;

  /// Month (1..12) with the most messages across every year.
  final int? busiestMonth;

  /// Distinct event types present in the archive, e.g. message/post/comment.
  final int recordTypes;

  /// Dated and undated record counts, for the index coverage card.
  final int datedEvents;
  final int undatedEvents;

  bool get isEmpty => totals.events == 0 && totals.photos == 0;

  int? get firstYear => totals.first?.toUtc().year;
  int? get lastYear => totals.last?.toUtc().year;

  /// Covered years, both ends included.
  int? get yearSpan {
    final first = firstYear;
    final last = lastYear;
    if (first == null || last == null) return null;
    return last - first + 1;
  }

  /// Average messages per covered day in the busiest year, rounded down.
  int? get busiestDailyAverage {
    final busiest = busiestTotals;
    if (busiest == null || busiest.days == 0) return null;
    return busiest.messages ~/ busiest.days;
  }

  /// Average messages per dated day across the whole archive.
  int? get dailyAverage {
    if (totals.days == 0) return null;
    return totals.messages ~/ totals.days;
  }

  /// Share of records that carry a normalised timestamp, as a percentage.
  int get coveragePercent {
    if (totals.events == 0) return 0;
    return (datedEvents * 100 / totals.events).round();
  }
}

/// Composes the story screen from single-statement aggregates.
class StoryService {
  const StoryService(this.overview, this.search, this.attachments);

  final OverviewRepository overview;
  final EventSearchRepository search;
  final AttachmentRepository attachments;

  Future<StorySnapshot> load() async {
    final totals = await overview.archiveTotals();
    final yearRows = await overview.countsByYear();
    final peopleRows = await overview.topPeople(limit: 5);
    final terms = await search.topTerms(limit: 3);
    final conversations = await overview.topConversations(limit: 1);
    final monthRows = await overview.countsByMonth();
    final typeRows = await overview.countsByEventType();
    final period = await overview.activityPeriod();
    final images = await attachments.media(mediaType: 'image', limit: 60);

    final years = [
      for (final row in yearRows) StoryYear(year: row.year, count: row.count),
    ];

    int? busiestYear;
    ArchiveTotals? busiestTotals;
    if (years.isNotEmpty) {
      var busiest = years.first;
      for (final year in years.skip(1)) {
        if (year.count > busiest.count) busiest = year;
      }
      busiestYear = busiest.year;
      busiestTotals = await overview.archiveTotals(year: busiest.year);
    }

    int? busiestMonth;
    if (monthRows.isNotEmpty) {
      var busiest = monthRows.first;
      for (final row in monthRows.skip(1)) {
        if (row.count > busiest.count) busiest = row;
      }
      busiestMonth = busiest.month;
    }

    // Memories belong to the month of the newest archived image: the card is
    // about the archive's own calendar, not the device clock.
    DateTime? newestAt;
    for (final row in images) {
      if (row.at != null) {
        newestAt = row.at;
        break;
      }
    }
    final memoryMonth = newestAt?.month;
    final memories = <StoryMemory>[
      for (final row in images)
        if (row.at != null && row.at!.month == memoryMonth)
          StoryMemory(id: row.id, at: row.at!, mediaType: row.mediaType),
    ];

    final longest = conversations.isEmpty ? null : conversations.first;

    return StorySnapshot(
      totals: totals,
      years: List.unmodifiable(years),
      terms: List.unmodifiable([
        for (final term in terms)
          StoryTerm(term: term.term, occurrences: term.occurrences),
      ]),
      people: List.unmodifiable([
        for (final person in peopleRows)
          StoryPerson(id: person.id, name: person.name, count: person.count),
      ]),
      memories: List.unmodifiable(memories.take(2)),
      memoryMonth: memoryMonth,
      busiestYear: busiestYear,
      busiestTotals: busiestTotals,
      topPersonName: peopleRows.isEmpty ? null : peopleRows.first.name,
      topPersonCount: peopleRows.isEmpty ? null : peopleRows.first.count,
      longestConversationCount: longest?.count,
      busiestMonth: busiestMonth,
      recordTypes: typeRows.length,
      datedEvents: period.dated,
      undatedEvents: period.unknown,
    );
  }
}
