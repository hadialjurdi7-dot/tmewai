import 'package:drift/drift.dart';

import '../../domain/models/attachment.dart';
import '../database/app_database.dart';

/// One attachment row read for the gallery.
///
/// [relativePath] is archive-relative metadata; the file it names is never
/// opened, so a row with a path and a row without one draw the same
/// placeholder.
class MediaAttachmentRow {
  const MediaAttachmentRow({
    required this.id,
    required this.relativePath,
    required this.mediaType,
    required this.sizeBytes,
    required this.at,
    required this.personId,
    required this.personName,
  });

  final int id;
  final String? relativePath;
  final String mediaType;
  final int sizeBytes;

  /// UTC timestamp of the event that carries the attachment, when dated.
  final DateTime? at;
  final int? personId;
  final String? personName;
}

/// Writes attachment metadata and reads the gallery back.
///
/// Only metadata lives here: the archive-relative path, media type, byte
/// length and optional content hash. Media bytes never reach this layer.
class AttachmentRepository {
  const AttachmentRepository(this._database);

  final AppDatabase _database;

  /// Inserts [records] and returns the new row ids, in order.
  Future<List<int>> insertAll(Iterable<AttachmentRecord> records) async {
    final ids = <int>[];
    for (final record in records) {
      ids.add(
        await _database
            .into(_database.attachments)
            .insert(
              AttachmentsCompanion.insert(
                eventId: Value(record.eventId),
                sourceFileId: record.sourceFileId,
                relativePath: Value(record.relativePath),
                mediaType: record.mediaType,
                sizeBytes: record.sizeBytes,
                contentHash: Value(record.contentHash),
              ),
            ),
      );
    }
    return ids;
  }

  /// Every attachment row in the archive, media bytes untouched.
  ///
  /// `ponytail:` P5 needs the gallery and P6 needs the photos shared with one
  /// person; until now this repository only wrote metadata, so the reads had
  /// no home. Each read stays one statement, filtered by the event's UTC year
  /// or its actor instead of loading the whole table and filtering in Dart.
  ///
  /// [mediaType] restricts the count to one media kind. The gallery is an image
  /// screen, so its header must not count the videos and audio files the export
  /// also carries.
  Future<int> count({String? mediaType}) async {
    final filter = mediaType == null ? '' : ' WHERE media_type = ?';
    final row = await _database
        .customSelect(
          'SELECT COUNT(*) AS row_count FROM attachments$filter',
          variables: [if (mediaType != null) Variable<String>(mediaType)],
        )
        .getSingle();
    return row.read<int>('row_count');
  }

  /// Attachment counts per UTC year of the carrying event, newest first.
  ///
  /// [mediaType] restricts the buckets to one media kind, so a year chip can
  /// never promise rows the image-only grid will not show. Undated rows have no
  /// year to bucket into and are excluded.
  Future<List<({int year, int count})>> countsByYear({
    String? mediaType,
  }) async {
    final filter = mediaType == null ? '' : 'AND a.media_type = ? ';
    final rows = await _database
        .customSelect(
          "SELECT CAST(strftime('%Y', e.timestamp_normalized, 'unixepoch') "
          'AS INTEGER) AS bucket_year, COUNT(*) AS row_count '
          'FROM attachments a JOIN events e ON e.id = a.event_id '
          'WHERE e.timestamp_normalized IS NOT NULL '
          '$filter'
          'GROUP BY bucket_year ORDER BY bucket_year DESC',
          variables: [if (mediaType != null) Variable<String>(mediaType)],
        )
        .get();
    return [
      for (final row in rows)
        (
          year: row.read<int>('bucket_year'),
          count: row.read<int>('row_count'),
        ),
    ];
  }

  /// The newest [limit] attachments, newest first, undated last.
  ///
  /// [year] restricts to the UTC year of the carrying event; [personId]
  /// restricts to the event's actor; [mediaType] restricts to one media kind.
  Future<List<MediaAttachmentRow>> media({
    int? year,
    int? personId,
    String? mediaType,
    int limit = 60,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }
    final conditions = <String>[];
    final variables = <Variable<Object>>[];
    if (year != null) {
      conditions.add(
        "strftime('%Y', e.timestamp_normalized, 'unixepoch') = ?",
      );
      variables.add(Variable<String>(year.toString()));
    }
    if (personId != null) {
      conditions.add('e.actor_id = ?');
      variables.add(Variable<int>(personId));
    }
    if (mediaType != null) {
      conditions.add('a.media_type = ?');
      variables.add(Variable<String>(mediaType));
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')} ';

    final rows = await _database
        .customSelect(
          'SELECT a.id, a.relative_path, a.media_type, a.size_bytes, '
          'e.timestamp_normalized, e.actor_id, p.display_name '
          'FROM attachments a '
          'LEFT JOIN events e ON e.id = a.event_id '
          'LEFT JOIN people p ON p.id = e.actor_id '
          '$where'
          'ORDER BY e.timestamp_normalized IS NULL ASC, '
          'e.timestamp_normalized DESC, a.id DESC LIMIT ?',
          variables: [...variables, Variable<int>(limit)],
        )
        .get();

    return [
      for (final row in rows)
        MediaAttachmentRow(
          id: row.read<int>('id'),
          relativePath: row.read<String?>('relative_path'),
          mediaType: row.read<String>('media_type'),
          sizeBytes: row.read<int>('size_bytes'),
          // Drift reads a stored instant as a local DateTime; the archive is
          // bucketed in UTC, so normalize at the edge.
          at: row.read<DateTime?>('timestamp_normalized')?.toUtc(),
          personId: row.read<int?>('actor_id'),
          personName: row.read<String?>('display_name'),
        ),
    ];
  }

  /// People with the most image attachments, highest first.
  Future<List<({int id, String name, int count})>> topPeople({
    int limit = 5,
  }) async {
    final rows = await _database
        .customSelect(
          'SELECT p.id, p.display_name, COUNT(*) AS row_count '
          'FROM attachments a JOIN events e ON e.id = a.event_id '
          'JOIN people p ON p.id = e.actor_id '
          "WHERE a.media_type = 'image' "
          'GROUP BY p.id ORDER BY row_count DESC, p.id ASC LIMIT ?',
          variables: [Variable<int>(limit)],
        )
        .get();
    return [
      for (final row in rows)
        (
          id: row.read<int>('id'),
          name: row.read<String>('display_name'),
          count: row.read<int>('row_count'),
        ),
    ];
  }
}
