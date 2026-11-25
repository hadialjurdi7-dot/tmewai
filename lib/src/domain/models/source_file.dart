/// Result of trying to read one file of an imported archive.
enum ParseStatus {
  /// Recorded but not parsed yet.
  pending,

  /// Parsed; records may have been produced.
  parsed,

  /// Recognized but intentionally ignored (unsupported shape or size).
  skipped,

  /// Not a supported file type; it is only reported.
  unsupported,

  /// Parsing failed; [SourceFileRecord.errorCode] says why, safely.
  failed,
}

/// One file inside an imported archive, as recorded during the import.
class SourceFileRecord {
  const SourceFileRecord({
    required this.relativePath,
    required this.parseStatus,
    this.id,
    this.importId,
    this.mediaType,
    this.contentHash,
    this.errorCode,
  });

  /// Assigned by the database; null before the row is inserted.
  final int? id;

  /// The import this file belongs to. Null on an insert draft: the repository
  /// links the file to the import it is inserted with and ignores any value
  /// carried here.
  final int? importId;

  /// Path inside the archive, relative and normalized. Never a host path.
  final String relativePath;

  /// Detected media type, when it was determined.
  final String? mediaType;

  /// Hash of the file content, when it was computed.
  final String? contentHash;

  final ParseStatus parseStatus;

  /// Safe, non-leaking error code (never raw content or a host path).
  final String? errorCode;
}
