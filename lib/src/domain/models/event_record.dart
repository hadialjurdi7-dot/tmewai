/// What is known about the timezone of an event timestamp.
enum TimezoneStatus {
  /// The export carried no timezone information.
  unknown,

  /// The timestamp is unambiguously UTC.
  utc,

  /// The timestamp carried an explicit offset.
  explicitOffset,

  /// The timestamp is local time with no offset; it is not treated as UTC.
  localTime,

  /// A timestamp string was present but could not be normalized. It is kept
  /// distinct from [unknown], which means the export carried no timestamp at
  /// all, so a parse failure is never reported as missing source data.
  invalid,
}

/// One normalized record (message, post, reaction, …) from an import.
class EventRecord {
  const EventRecord({
    required this.importId,
    required this.sourceFileId,
    required this.sourceLocator,
    required this.platform,
    required this.eventType,
    required this.timezoneStatus,
    this.id,
    this.timestampRaw,
    this.timestampNormalized,
    this.actorId,
    this.conversationId,
    this.textContent,
    this.metadataJson,
  });

  /// Assigned by the database; null before the row is inserted.
  final int? id;

  /// The import this event belongs to.
  final int importId;

  /// The archive file this event was read from.
  final int sourceFileId;

  /// Pointer back into the source file (for example a JSON path or row index)
  /// so every stored claim can be traced to evidence.
  final String sourceLocator;

  final String platform;
  final String eventType;

  /// The timestamp exactly as exported, unparsed. No unit conversion happens
  /// in the domain model.
  final String? timestampRaw;

  /// Timestamp normalized to UTC, only when the export supported it.
  final DateTime? timestampNormalized;

  final TimezoneStatus timezoneStatus;

  final int? actorId;
  final int? conversationId;

  /// Message or post text, bounded by the importer.
  final String? textContent;

  /// Allowlisted metadata, serialized as JSON. Never the whole raw record.
  final String? metadataJson;
}
