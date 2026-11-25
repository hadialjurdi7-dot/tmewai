import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'event_type_filter.dart';

/// One conversation row for the messages list.
///
/// [lastText] is the newest message that carries text, so a thread whose last
/// message is media only still shows the last thing that was said.
class ConversationListRow {
  const ConversationListRow({
    required this.id,
    required this.title,
    required this.sourceConversationId,
    required this.messageCount,
    required this.lastText,
    required this.lastSender,
    required this.lastAt,
    required this.firstAt,
    required this.platform,
  });

  final int id;
  final String? title;
  final String? sourceConversationId;
  final int messageCount;
  final String? lastText;
  final String? lastSender;
  final DateTime? lastAt;
  final DateTime? firstAt;
  final String? platform;
}

/// One message read for a conversation thread.
class ConversationMessageRow {
  const ConversationMessageRow({
    required this.id,
    required this.at,
    required this.text,
    required this.actorId,
    required this.actorName,
    required this.attachmentCount,
    required this.attachmentMediaType,
  });

  final int id;

  /// UTC instant, or null when the export could not be normalized.
  final DateTime? at;
  final String? text;
  final int? actorId;
  final String? actorName;
  final int attachmentCount;
  final String? attachmentMediaType;
}

/// Reads the local chat archive for «الرسائل».
///
/// `ponytail:` P4 needs the conversation list with its newest message and the
/// thread rows behind each conversation, and nothing existing returns that:
/// the timeline repository is archive-wide and carries no conversation or
/// sender, and the overview aggregates only count rows. Both reads stay a
/// single statement per screen load, so a thread never costs one query per
/// message and no number is derived outside SQL beyond grouping rows by day.
class ConversationRepository {
  const ConversationRepository(this._database);

  final AppDatabase _database;

  /// Conversations that hold at least one message, newest activity first.
  ///
  /// Pass [id] to read one conversation by its own id, whatever its rank: a
  /// caller that was given a conversation id must never be handed a different
  /// conversation just because the requested one falls outside [limit].
  Future<List<ConversationListRow>> conversations({
    int limit = 100,
    int? id,
  }) async {
    final filter = id == null ? '' : 'WHERE c.id = ? ';
    final rows = await _database
        .customSelect(
          'SELECT c.id, c.title, c.source_conversation_id, '
          'COUNT(e.id) AS message_count, '
          'MIN(e.timestamp_normalized) AS first_at, '
          'MAX(e.timestamp_normalized) AS last_at, '
          '(SELECT e2.text_content FROM events e2 '
          'WHERE e2.conversation_id = c.id AND ${messageEventSql('e2.event_type')} '
          'AND e2.text_content IS NOT NULL '
          'ORDER BY e2.timestamp_normalized DESC, e2.id DESC LIMIT 1) '
          'AS last_text, '
          '(SELECT p.display_name FROM events e3 '
          'LEFT JOIN people p ON p.id = e3.actor_id '
          'WHERE e3.conversation_id = c.id AND ${messageEventSql('e3.event_type')} '
          'ORDER BY e3.timestamp_normalized DESC, e3.id DESC LIMIT 1) '
          'AS last_sender, '
          '(SELECT e4.platform FROM events e4 '
          'WHERE e4.conversation_id = c.id AND ${messageEventSql('e4.event_type')} '
          'ORDER BY e4.timestamp_normalized DESC, e4.id DESC LIMIT 1) '
          'AS platform '
          'FROM conversations c '
          'JOIN events e ON e.conversation_id = c.id '
          'AND ${messageEventSql('e.event_type')} '
          '$filter'
          'GROUP BY c.id '
          'ORDER BY last_at IS NULL ASC, last_at DESC, c.id ASC LIMIT ?',
          variables: [
            if (id != null) Variable<int>(id),
            Variable<int>(limit),
          ],
        )
        .get();

    return [
      for (final row in rows)
        ConversationListRow(
          id: row.read<int>('id'),
          title: row.read<String?>('title'),
          sourceConversationId: row.read<String?>('source_conversation_id'),
          messageCount: row.read<int>('message_count'),
          lastText: row.read<String?>('last_text'),
          lastSender: row.read<String?>('last_sender'),
          // Drift hands back a local DateTime for a stored instant; the whole
          // archive is bucketed in UTC, so normalize at the edge.
          lastAt: row.read<DateTime?>('last_at')?.toUtc(),
          firstAt: row.read<DateTime?>('first_at')?.toUtc(),
          platform: row.read<String?>('platform'),
        ),
    ];
  }

  /// How many conversations hold at least one message, whole archive.
  Future<int> conversationCount() async {
    final row = await _database
        .customSelect(
          'SELECT COUNT(DISTINCT conversation_id) AS conversation_count '
          'FROM events WHERE ${messageEventSql('event_type')} '
          'AND conversation_id IS NOT NULL',
        )
        .getSingle();
    return row.read<int?>('conversation_count') ?? 0;
  }

  /// One page of a conversation, newest first.
  ///
  /// [offset] walks backwards in time: the screen shows the newest page first
  /// and appends the next page as it approaches the oldest loaded row. The
  /// existing [messages] read is unchanged for callers that still ask for the
  /// newest N rows in one statement.
  Future<List<ConversationMessageRow>> messagesPage(
    int conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'must not be negative');
    }
    final rows = await _database
        .customSelect(
          'SELECT e.id, e.timestamp_normalized, e.text_content, e.actor_id, '
          'p.display_name AS actor_name, '
          '(SELECT COUNT(*) FROM attachments a WHERE a.event_id = e.id) '
          'AS attachment_count, '
          '(SELECT a.media_type FROM attachments a WHERE a.event_id = e.id '
          'ORDER BY a.id ASC LIMIT 1) AS media_type '
          'FROM events e LEFT JOIN people p ON p.id = e.actor_id '
          'WHERE e.conversation_id = ? AND ${messageEventSql('e.event_type')} '
          'ORDER BY e.timestamp_normalized IS NULL ASC, '
          'e.timestamp_normalized DESC, e.id DESC LIMIT ? OFFSET ?',
          variables: [
            Variable<int>(conversationId),
            Variable<int>(limit),
            Variable<int>(offset),
          ],
        )
        .get();

    return [
      for (final row in rows)
        ConversationMessageRow(
          id: row.read<int>('id'),
          at: row.read<DateTime?>('timestamp_normalized')?.toUtc(),
          text: row.read<String?>('text_content'),
          actorId: row.read<int?>('actor_id'),
          actorName: row.read<String?>('actor_name'),
          attachmentCount: row.read<int?>('attachment_count') ?? 0,
          attachmentMediaType: row.read<String?>('media_type'),
        ),
    ];
  }

  /// SQL text search inside one conversation, newest first.
  ///
  /// The query is bound and matched with `instr` over the lowered text, so a
  /// `%` or a quote in the user's input is a literal character, not a pattern
  /// or statement fragment. A blank query returns no rows without touching
  /// SQLite; the screen would otherwise list the whole thread as a match.
  Future<List<ConversationMessageRow>> searchMessages(
    int conversationId,
    String query, {
    int limit = 100,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }
    final needle = query.trim();
    if (needle.isEmpty) return const [];
    final rows = await _database
        .customSelect(
          'SELECT e.id, e.timestamp_normalized, e.text_content, e.actor_id, '
          'p.display_name AS actor_name, '
          '(SELECT COUNT(*) FROM attachments a WHERE a.event_id = e.id) '
          'AS attachment_count, '
          '(SELECT a.media_type FROM attachments a WHERE a.event_id = e.id '
          'ORDER BY a.id ASC LIMIT 1) AS media_type '
          'FROM events e LEFT JOIN people p ON p.id = e.actor_id '
          'WHERE e.conversation_id = ? AND ${messageEventSql('e.event_type')} '
          'AND e.text_content IS NOT NULL '
          'AND instr(lower(e.text_content), lower(?)) > 0 '
          'ORDER BY e.timestamp_normalized IS NULL ASC, '
          'e.timestamp_normalized DESC, e.id DESC LIMIT ?',
          variables: [
            Variable<int>(conversationId),
            Variable<String>(needle),
            Variable<int>(limit),
          ],
        )
        .get();

    return [
      for (final row in rows)
        ConversationMessageRow(
          id: row.read<int>('id'),
          at: row.read<DateTime?>('timestamp_normalized')?.toUtc(),
          text: row.read<String?>('text_content'),
          actorId: row.read<int?>('actor_id'),
          actorName: row.read<String?>('actor_name'),
          attachmentCount: row.read<int?>('attachment_count') ?? 0,
          attachmentMediaType: row.read<String?>('media_type'),
        ),
    ];
  }

  /// The sender who wrote most of this conversation.
  ///
  /// The archive records no "owner", so the leading side is a fact about
  /// message counts, not a claim about the person using the app. Ties resolve
  /// to the lower actor id, and an all-unknown actor set resolves to null.
  Future<int?> topSenderId(int conversationId) async {
    final row = await _database
        .customSelect(
          'SELECT actor_id FROM events '
          'WHERE conversation_id = ? AND ${messageEventSql('event_type')} '
          'GROUP BY actor_id '
          'ORDER BY COUNT(*) DESC, actor_id ASC LIMIT 1',
          variables: [Variable<int>(conversationId)],
        )
        .getSingleOrNull();
    return row?.read<int?>('actor_id');
  }

  /// Distinct senders in one conversation, including an unknown-actor bucket.
  Future<int> senderCount(int conversationId) async {
    final row = await _database
        .customSelect(
          'SELECT COUNT(DISTINCT actor_id) + '
          'CASE WHEN COUNT(*) > COUNT(actor_id) THEN 1 ELSE 0 END '
          'AS sender_count FROM events '
          'WHERE conversation_id = ? AND ${messageEventSql('event_type')}',
          variables: [Variable<int>(conversationId)],
        )
        .getSingle();
    return row.read<int?>('sender_count') ?? 0;
  }

  /// The newest [limit] messages of one conversation, newest first.
  ///
  /// The caller reverses the list, so a thread longer than [limit] still ends
  /// on the newest message instead of dropping it.
  Future<List<ConversationMessageRow>> messages(
    int conversationId, {
    int limit = 200,
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive');
    }
    final rows = await _database
        .customSelect(
          'SELECT e.id, e.timestamp_normalized, e.text_content, e.actor_id, '
          'p.display_name AS actor_name, '
          '(SELECT COUNT(*) FROM attachments a WHERE a.event_id = e.id) '
          'AS attachment_count, '
          '(SELECT a.media_type FROM attachments a WHERE a.event_id = e.id '
          'ORDER BY a.id ASC LIMIT 1) AS media_type '
          'FROM events e LEFT JOIN people p ON p.id = e.actor_id '
          'WHERE e.conversation_id = ? AND ${messageEventSql('e.event_type')} '
          'ORDER BY e.timestamp_normalized IS NULL ASC, '
          'e.timestamp_normalized DESC, e.id DESC LIMIT ?',
          variables: [
            Variable<int>(conversationId),
            Variable<int>(limit),
          ],
        )
        .get();

    return [
      for (final row in rows)
        ConversationMessageRow(
          id: row.read<int>('id'),
          at: row.read<DateTime?>('timestamp_normalized')?.toUtc(),
          text: row.read<String?>('text_content'),
          actorId: row.read<int?>('actor_id'),
          actorName: row.read<String?>('actor_name'),
          attachmentCount: row.read<int?>('attachment_count') ?? 0,
          attachmentMediaType: row.read<String?>('media_type'),
        ),
    ];
  }
}
