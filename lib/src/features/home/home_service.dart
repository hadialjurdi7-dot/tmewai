import '../../data/repositories/overview_repository.dart';
import '../../data/repositories/timeline_repository.dart';

/// One person row of the home sidebar, ready for a labelled bar.
class HomePerson {
  const HomePerson({required this.id, required this.name, required this.count});

  final int id;
  final String name;
  final int count;
}

/// Everything the home screen draws, computed once from the local database.
///
/// Every number comes from [OverviewRepository]; the four recent records come
/// from the timeline repository's explicit newest-first read, so the home screen
/// never invents a value that the archive cannot reproduce.
class HomeSnapshot {
  const HomeSnapshot({
    required this.totals,
    required this.topPeople,
    required this.latest,
  });

  final ArchiveTotals totals;
  final List<HomePerson> topPeople;

  /// Newest first, at most four.
  final List<TimelineRow> latest;

  bool get isEmpty => totals.events == 0 && totals.photos == 0;

  /// First and last UTC year of the dated records, or null when none is dated.
  int? get firstYear => totals.first?.toUtc().year;
  int? get lastYear => totals.last?.toUtc().year;

  /// Span of covered years, both ends included. Null when no record is dated.
  int? get yearSpan {
    final first = firstYear;
    final last = lastYear;
    if (first == null || last == null) return null;
    return last - first + 1;
  }
}

/// Reads the home dashboard from the existing aggregate repositories.
class HomeService {
  const HomeService(this.overview, this.timeline);

  final OverviewRepository overview;
  final TimelineRepository timeline;

  Future<HomeSnapshot> load() async {
    final totals = await overview.archiveTotals();
    final people = await overview.topPeople(limit: 5);
    final latest = await timeline.latestEvents(limit: 4);

    return HomeSnapshot(
      totals: totals,
      topPeople: List.unmodifiable([
        for (final person in people)
          HomePerson(id: person.id, name: person.name, count: person.count),
      ]),
      latest: List.unmodifiable(latest),
    );
  }
}
