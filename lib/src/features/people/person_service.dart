import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/overview_repository.dart';
import '../../data/repositories/person_repository.dart';
import '../media/media_service.dart';

/// One person of the side list.
class PersonSummary {
  const PersonSummary({
    required this.id,
    required this.name,
    required this.messageCount,
  });

  final int id;
  final String name;
  final int messageCount;
}

/// One of the newest messages this person wrote.
class PersonLine {
  const PersonLine({required this.id, required this.at, required this.text});

  final int id;
  final DateTime? at;
  final String? text;
}

/// One older page of their messages, newest first.
class PersonMessagePage {
  const PersonMessagePage({
    required this.lines,
    required this.loaded,
    required this.total,
    required this.hasMore,
  });

  final List<PersonLine> lines;

  /// Rows loaded over every page so far, the “loaded N of M” left number.
  final int loaded;
  final int total;
  final bool hasMore;
}

/// One year of their messages, gaps included as zero so the bars line up.
class PersonYear {
  const PersonYear({required this.year, required this.count});

  final int year;
  final int count;
}

/// Everything «ملف شخص» draws for one person.
class PersonProfile {
  const PersonProfile({
    required this.id,
    required this.name,
    required this.platform,
    this.platformPersonId,
    required this.messageCount,
    required this.messageTotal,
    required this.photoCount,
    required this.firstAt,
    required this.lastAt,
    required this.days,
    required this.conversationId,
    required this.years,
    required this.lines,
    required this.photos,
  });

  final int id;
  final String name;
  final String platform;

  /// The id the source platform exported for this person; null when absent.
  final String? platformPersonId;
  final int messageCount;

  /// Text messages in total; [lines] holds the newest page of them.
  ///
  /// The paged list states “loaded N of M” against this number and never
  /// against [messageCount], which also counts empty-bodied rows the page skips.
  final int messageTotal;
  final int photoCount;
  final DateTime? firstAt;
  final DateTime? lastAt;
  final int days;

  /// The conversation most of their messages live in; null when none.
  final int? conversationId;
  final List<PersonYear> years;
  final List<PersonLine> lines;

  /// At most four shared photos, metadata only.
  final List<MediaItem> photos;

  bool get isEmpty => messageCount == 0 && photoCount == 0;

  int? get firstYear => firstAt?.toUtc().year;
  int? get lastYear => lastAt?.toUtc().year;

  /// Span of years the conversation covers, both ends included.
  int? get yearSpan {
    final first = firstYear;
    final last = lastYear;
    if (first == null || last == null) return null;
    return last - first + 1;
  }

  int get yearMax =>
      years.fold<int>(0, (max, year) => year.count > max ? year.count : max);

  int? get busiestYear {
    if (yearMax == 0) return null;
    return years.firstWhere((year) => year.count == yearMax).year;
  }
}

/// Everything the people section draws: the list, the open profile and the
/// archive totals the shortcuts and the local-archive card state.
class PersonSnapshot {
  const PersonSnapshot({
    required this.people,
    required this.selected,
    this.messages = 0,
    this.photos = 0,
    this.events = 0,
    this.lastDatedAt,
  });

  final List<PersonSummary> people;

  /// Null exactly when the archive holds no person with a message.
  final PersonProfile? selected;

  /// Messages in the whole archive, not only this person's.
  final int messages;

  /// Image attachments in the whole archive.
  final int photos;

  /// Every stored event, the number the account chip states.
  final int events;

  /// Newest dated event in the archive; the archive card's last line.
  final DateTime? lastDatedAt;

  bool get isEmpty => people.isEmpty;
}

/// Builds the person profile from per-person reads only.
///
/// Every number comes from that person's own rows: message and photo counts,
/// the first and last message that carries a timestamp, the distinct days and
/// the yearly buckets. The list is the archive's message ranking, so the screen
/// never suggests a relationship it cannot count.
class PersonService {
  const PersonService(this.people, this.overview, this.attachments);

  final PersonRepository people;
  final OverviewRepository overview;
  final AttachmentRepository attachments;

  /// How many people the side list shows — the reference card holds four.
  static const int listLimit = 4;

  /// Rows of the «آخر اللي حكيته» card's first page.
  static const int pageSize = 20;

  Future<PersonSnapshot> load({int? personId}) async {
    final ranking = await overview.topPeople(limit: listLimit);
    final totals = await overview.archiveTotals();
    final summaries = [
      for (final row in ranking)
        PersonSummary(id: row.id, name: row.name, messageCount: row.count),
    ];
    if (summaries.isEmpty) {
      return PersonSnapshot(
        people: const [],
        selected: null,
        messages: totals.messages,
        photos: totals.photos,
        events: totals.events,
        lastDatedAt: totals.last?.toUtc(),
      );
    }

    // A requested id outside the ranked list is read directly: opening a
    // different person because the requested one is not in the sidebar would
    // show someone else's numbers under the requested name.
    final summary = personId == null
        ? summaries.first
        : summaries.firstWhere(
            (person) => person.id == personId,
            orElse: () => PersonSummary(
              id: personId,
              name: '',
              messageCount: 0,
            ),
          );
    final profile = await people.profile(summary.id);
    if (profile == null) {
      return PersonSnapshot(
        people: List.unmodifiable(summaries),
        selected: null,
        messages: totals.messages,
        photos: totals.photos,
        events: totals.events,
        lastDatedAt: totals.last?.toUtc(),
      );
    }

    final yearRows = await people.messageYears(summary.id);
    final total = await people.textMessageCount(summary.id);
    final lines = await people.messagePage(
      summary.id,
      limit: pageSize,
    );
    final photos = await attachments.media(
      personId: summary.id,
      mediaType: 'image',
      limit: 4,
    );
    final imagePhotos = photos
        .where((photo) => photo.mediaType == 'image')
        .toList(growable: false);

    return PersonSnapshot(
      people: List.unmodifiable(summaries),
      messages: totals.messages,
      photos: totals.photos,
      events: totals.events,
      lastDatedAt: totals.last?.toUtc(),
      selected: PersonProfile(
        id: profile.id,
        name: profile.name,
        platform: profile.platform,
        platformPersonId: profile.platformPersonId,
        messageCount: profile.messageCount,
        messageTotal: total,
        photoCount: profile.photoCount,
        firstAt: profile.firstAt,
        lastAt: profile.lastAt,
        days: profile.days,
        conversationId: profile.conversationId,
        years: List.unmodifiable(_fillYears(yearRows)),
        lines: List.unmodifiable([
          for (final line in lines)
            PersonLine(id: line.id, at: line.at, text: line.text),
        ]),
        photos: List.unmodifiable([
          for (final photo in imagePhotos)
            MediaItem(
              id: photo.id,
              mediaType: photo.mediaType,
              sizeBytes: photo.sizeBytes,
              at: photo.at,
              hasPath: (photo.relativePath ?? '').isNotEmpty,
            ),
        ]),
      ),
    );
  }

  /// Reads the next page after [offset] loaded rows.
  ///
  /// Kept next to [load] so both pages use the same row filter and order; the
  /// screen only appends what this returns.
  static Future<PersonMessagePage> page(
    PersonRepository people,
    int personId, {
    required int offset,
    int limit = pageSize,
  }) async {
    final total = await people.textMessageCount(personId);
    final rows = await people.messagePage(
      personId,
      limit: limit,
      offset: offset,
    );
    return PersonMessagePage(
      lines: List.unmodifiable([
        for (final row in rows)
          PersonLine(id: row.id, at: row.at, text: row.text),
      ]),
      loaded: offset + rows.length,
      total: total,
      hasMore: offset + rows.length < total,
    );
  }

  /// Fills the years between the first and the last bucket with zeros, so the
  /// chart never implies continuity the archive cannot prove either.
  List<PersonYear> _fillYears(List<({int year, int count})> rows) {
    if (rows.isEmpty) return const [];
    final counts = {for (final row in rows) row.year: row.count};
    return [
      for (var year = rows.first.year; year <= rows.last.year; year++)
        PersonYear(year: year, count: counts[year] ?? 0),
    ];
  }
}
