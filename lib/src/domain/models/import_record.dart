/// Lifecycle of one import run.
enum ImportStatus {
  /// Accepted, not started yet.
  pending,

  /// Currently reading and normalizing the export.
  running,

  /// Finished; every supported file was processed or reported.
  completed,

  /// Stopped by an error; partial results may exist.
  failed,

  /// Cancelled by the user.
  cancelled,
}

/// One import of a user-owned export archive.
///
/// Plain Dart: the domain layer never exposes database row types.
class ImportRecord {
  const ImportRecord({
    required this.platform,
    required this.format,
    required this.sourceFingerprint,
    required this.startedAt,
    required this.importerVersion,
    required this.status,
    this.id,
    this.completedAt,
  });

  /// Assigned by the database; null before the row is inserted.
  final int? id;

  /// Source platform, e.g. `facebook`.
  final String platform;

  /// Export format, e.g. `json` or `html`.
  final String format;

  /// Fingerprint of the selected archive, used to detect re-imports of the
  /// same export without keeping the archive itself.
  final String sourceFingerprint;

  final DateTime startedAt;
  final DateTime? completedAt;

  /// Version of the importer that produced this import, so results stay
  /// explainable when importer logic changes.
  final String importerVersion;

  final ImportStatus status;
}
