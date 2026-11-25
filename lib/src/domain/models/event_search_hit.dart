/// One event matched by a full-text search.
///
/// Carries the source locator so a result can always be traced back to the
/// archive file it came from.
class EventSearchHit {
  const EventSearchHit({
    required this.eventId,
    required this.sourceLocator,
    required this.platform,
    required this.eventType,
    required this.relevance,
    this.timestampNormalized,
    this.textContent,
  });

  final int eventId;

  /// Pointer back into the source file, as recorded at import time.
  final String sourceLocator;

  final String platform;
  final String eventType;

  /// FTS5 `bm25` score: more negative is a better match. Only meaningful for
  /// ordering, never shown to the user as a confidence number.
  final double relevance;

  /// Timestamp normalized to UTC, when the export supported it.
  final DateTime? timestampNormalized;

  /// The matched text, as stored. Null when the event had no text.
  final String? textContent;
}
