/// A media reference attached to an event, pointing at a source file.
///
/// Attachments describe where media lives; they do not copy or decode it here.
class AttachmentRecord {
  const AttachmentRecord({
    required this.sourceFileId,
    required this.mediaType,
    required this.sizeBytes,
    this.id,
    this.eventId,
    this.relativePath,
    this.contentHash,
  });

  /// Assigned by the database; null before the row is inserted.
  final int? id;

  /// The event this attachment belongs to, when one was identified.
  final int? eventId;

  /// The archive file the media bytes came from.
  final int sourceFileId;

  /// Path inside the archive, when the export provides one.
  final String? relativePath;

  final String mediaType;
  final int sizeBytes;

  /// Hash of the media content, when it was computed.
  final String? contentHash;
}
