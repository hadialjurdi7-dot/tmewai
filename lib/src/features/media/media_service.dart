import '../../data/repositories/attachment_repository.dart';

/// One tile of the gallery: metadata only, no file content.
class MediaItem {
  const MediaItem({
    required this.id,
    required this.mediaType,
    required this.sizeBytes,
    required this.at,
    required this.hasPath,
  });

  final int id;
  final String mediaType;
  final int sizeBytes;
  final DateTime? at;

  /// False when the export named no archive path for this row.
  final bool hasPath;
}

/// One person of the «أكتر الناس بالصور» card.
class MediaPerson {
  const MediaPerson({
    required this.id,
    required this.name,
    required this.count,
  });

  final int id;
  final String name;
  final int count;
}

/// Everything «الصور» draws for one year filter.
class MediaSnapshot {
  const MediaSnapshot({
    required this.total,
    required this.years,
    required this.selectedYear,
    required this.items,
    required this.people,
    required this.matched,
    required this.limit,
  });

  /// Image attachments in the whole archive, dated or not.
  final int total;

  /// Years that carry images, newest first.
  final List<({int year, int count})> years;

  /// Null means «كل السنين».
  final int? selectedYear;

  /// At most [limit] newest image tiles of the filter.
  final List<MediaItem> items;
  final List<MediaPerson> people;

  /// Image rows matching the filter, which can exceed [items].
  final int matched;
  final int limit;

  bool get isEmpty => total == 0;

  /// True when the grid is cut short by [limit].
  bool get isTruncated => items.length < matched;

  int get selectedCount => selectedYear == null
      ? total
      : years
            .where((row) => row.year == selectedYear)
            .fold<int>(0, (sum, row) => sum + row.count);

  /// Oldest year with attachments — the year the memories card opens.
  int? get oldestYear => years.isEmpty ? null : years.last.year;
}

/// Builds the gallery from attachment metadata.
///
/// Nothing here opens a media file: the grid is a listing of what the archive
/// says exists (type, size, date, whether a path was stored), which is exactly
/// what the import wrote.
class MediaService {
  const MediaService(this.repository);

  final AttachmentRepository repository;

  /// Newest [limit] tiles of the selected year.
  static const int gridLimit = 60;

  Future<MediaSnapshot> load({int? year}) async {
    // Every number the screen shows is an image number. The export also stores
    // videos, audio and files; counting those here made the header, the year
    // chips and «تظهر أحدث N من M» disagree with the image-only grid.
    final years = await repository.countsByYear(mediaType: 'image');
    final total = await repository.count(mediaType: 'image');
    if (total == 0) {
      return MediaSnapshot(
        total: 0,
        years: const [],
        selectedYear: year,
        items: const [],
        people: const [],
        matched: 0,
        limit: gridLimit,
      );
    }

    final rows = await repository.media(
      year: year,
      mediaType: 'image',
      limit: gridLimit,
    );
    final people = await repository.topPeople();
    // A year filter can only match dated images, so its total is the sum of the
    // year buckets; «كل السنين» also holds images the export left undated.
    final matched = year == null
        ? total
        : years
              .where((row) => row.year == year)
              .fold<int>(0, (sum, row) => sum + row.count);

    return MediaSnapshot(
      total: total,
      years: List.unmodifiable(years),
      selectedYear: year,
      items: List.unmodifiable([
        for (final row in rows)
          MediaItem(
            id: row.id,
            mediaType: row.mediaType,
            sizeBytes: row.sizeBytes,
            at: row.at,
            hasPath: (row.relativePath ?? '').isNotEmpty,
          ),
      ]),
      people: List.unmodifiable([
        for (final person in people)
          MediaPerson(
            id: person.id,
            name: person.name,
            count: person.count,
          ),
      ]),
      matched: matched,
      limit: gridLimit,
    );
  }
}
