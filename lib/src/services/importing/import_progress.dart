/// The phase an import is in, in the order it reaches them.
enum ImportPhase {
  /// Reading archive metadata and validating paths, before any parse.
  inspecting,

  /// Reading supported JSON files into normalized records.
  parsing,

  /// Writing rows inside the import transaction.
  writing,

  /// The import finished and its rows are committed.
  completed,

  /// The import was cancelled; nothing was written.
  cancelled,
}

/// One progress step of an import.
///
/// Paths are archive-relative only: a progress event never carries a host path
/// or file content, so it is safe to display or log.
class ImportProgress {
  const ImportProgress({
    required this.phase,
    this.filesDone = 0,
    this.filesTotal = 0,
    this.recordsWritten = 0,
    this.currentRelativePath,
  });

  final ImportPhase phase;

  /// Archive files handled so far, out of [filesTotal] when that is known.
  final int filesDone;
  final int filesTotal;

  /// Records persisted so far (0 while parsing, which writes nothing).
  final int recordsWritten;

  /// The archive-relative path currently being handled, never a host path.
  final String? currentRelativePath;

  @override
  String toString() =>
      'ImportProgress(${phase.name}, $filesDone/$filesTotal, '
      '$recordsWritten records)';
}

/// A caller-owned cancellation flag.
///
/// The importer checks it between files and between record batches. Cancelling
/// never throws into the database layer: the import transaction rolls back and
/// the coordinator returns a typed cancellation result.
class CancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}
