/// A conversation (or message thread) found in one import.
class ConversationRecord {
  const ConversationRecord({
    required this.importId,
    this.id,
    this.sourceConversationId,
    this.title,
  });

  /// Assigned by the database; null before the row is inserted.
  final int? id;

  final int importId;

  /// Conversation identifier as used inside the export, when present.
  final String? sourceConversationId;

  /// Title as exported, when present. Nullable rather than guessed.
  final String? title;
}
