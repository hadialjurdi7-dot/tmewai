import '../../data/repositories/conversation_repository.dart';

/// One conversation row of the messages list, ready to draw.
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.snippet,
    required this.messageCount,
    required this.firstAt,
    required this.lastAt,
    required this.platform,
  });

  final int id;
  final String title;

  /// Last text in the thread, or an honest line when there is none.
  final String snippet;
  final int messageCount;
  final DateTime? firstAt;
  final DateTime? lastAt;
  final String? platform;
}

/// One bubble inside a thread.
class MessageBubble {
  const MessageBubble({
    required this.id,
    required this.text,
    required this.at,
    required this.senderName,
    required this.fromPrimarySender,
    required this.attachmentCount,
    required this.attachmentMediaType,
    this.actorId,
  });

  final int id;
  final String? text;
  final DateTime? at;
  final String senderName;

  /// The stored person row of the sender; null when the export named no actor.
  /// The thread uses it to open that participant's profile.
  final int? actorId;

  /// True for the sender who wrote most of this thread. The archive records no
  /// "owner", so bubbles are grouped by sender, never labelled as «أنت».
  final bool fromPrimarySender;
  final int attachmentCount;
  final String? attachmentMediaType;
}

/// One day separator and the bubbles under it.
class MessageDay {
  const MessageDay({required this.date, required this.bubbles});

  /// UTC day; null is the undated bucket, drawn last.
  final DateTime? date;

  /// Newest bubble first, matching the paged read.
  final List<MessageBubble> bubbles;
}

/// The open conversation: header numbers plus the first page of bubbles.
class ConversationThread {
  const ConversationThread({
    required this.id,
    required this.title,
    required this.messageCount,
    required this.firstAt,
    required this.lastAt,
    required this.platform,
    required this.days,
    required this.senderCount,
    required this.loadedCount,
    required this.primarySenderId,
  });

  final int id;
  final String title;

  /// Every message in the conversation, from SQL.
  final int messageCount;
  final DateTime? firstAt;
  final DateTime? lastAt;
  final String? platform;

  /// Days of the loaded page, newest first; each day's bubbles are newest
  /// first too, so the screen can lay them out in a reverse lazy list.
  final List<MessageDay> days;

  /// Distinct senders in the whole thread, not only the loaded page.
  final int senderCount;

  /// Rows in [days]; the honest “loaded N of M” line and the next offset.
  final int loadedCount;

  /// The sender who wrote most of the whole thread; stable across pages.
  final int? primarySenderId;

  bool get hasMore => loadedCount < messageCount;
}

/// One page of older bubbles, newest first.
class MessagePage {
  const MessagePage({required this.bubbles, required this.hasMore});

  final List<MessageBubble> bubbles;
  final bool hasMore;
}

/// Everything «الرسائل» draws for one selection.
class MessagesSnapshot {
  const MessagesSnapshot({
    required this.conversations,
    required this.totalConversations,
    required this.selected,
  });

  final List<ConversationSummary> conversations;

  /// Conversations with messages in the whole archive.
  final int totalConversations;

  /// Null exactly when the archive has no conversation with a message.
  final ConversationThread? selected;

  bool get isEmpty => conversations.isEmpty;
}

/// Builds the messages screen from the local conversation reads.
///
/// The first page is the newest [pageSize] messages, read in one SQL page.
/// Older pages use the same newest-first read with an increasing offset and are
/// appended by the screen, so a 40,000-message thread never materialises at
/// once. In-thread search runs in SQL and can reach rows outside every loaded
/// page. A bubble side is decided by the sender with the most messages in the
/// whole thread, and each bubble of a multi-sender thread carries the exported
/// name. Days come from the stored UTC timestamps; undated messages stay in a
/// final «بلا تاريخ» day rather than being dropped.
class MessagesService {
  const MessagesService(this.repository);

  final ConversationRepository repository;

  /// Rows per page.
  static const int pageSize = 50;

  Future<MessagesSnapshot> load({int? selectedId}) async {
    final rows = await repository.conversations(limit: 100);
    final total = await repository.conversationCount();

    final conversations = [
      for (final row in rows)
        ConversationSummary(
          id: row.id,
          title: _titleOf(row),
          snippet: _snippetOf(row),
          messageCount: row.messageCount,
          firstAt: row.firstAt,
          lastAt: row.lastAt,
          platform: row.platform,
        ),
    ];

    if (conversations.isEmpty) {
      return MessagesSnapshot(
        conversations: const [],
        totalConversations: total,
        selected: null,
      );
    }

    // A caller may hold a conversation id that sits outside the capped list.
    // Read that conversation by id instead of silently opening another one:
    // the archive has the row, so the screen can show it.
    ConversationSummary? requested;
    if (selectedId != null &&
        !conversations.any((conversation) => conversation.id == selectedId)) {
      final rows = await repository.conversations(limit: 1, id: selectedId);
      if (rows.isNotEmpty) {
        final row = rows.single;
        requested = ConversationSummary(
          id: row.id,
          title: _titleOf(row),
          snippet: _snippetOf(row),
          messageCount: row.messageCount,
          firstAt: row.firstAt,
          lastAt: row.lastAt,
          platform: row.platform,
        );
      }
    }

    final summary = requested ??
        conversations.firstWhere(
          (conversation) => conversation.id == selectedId,
          orElse: () => conversations.first,
        );
    final messages = await repository.messagesPage(
      summary.id,
      limit: pageSize,
    );
    final primarySenderId = await repository.topSenderId(summary.id);
    final senderCount = await repository.senderCount(summary.id);
    final bubbles = _bubbles(messages, primarySenderId: primarySenderId);

    return MessagesSnapshot(
      conversations: List.unmodifiable(conversations),
      totalConversations: total,
      selected: ConversationThread(
        id: summary.id,
        title: summary.title,
        messageCount: summary.messageCount,
        firstAt: summary.firstAt,
        lastAt: summary.lastAt,
        platform: summary.platform,
        days: List.unmodifiable(_days(bubbles)),
        senderCount: senderCount,
        loadedCount: bubbles.length,
        primarySenderId: primarySenderId,
      ),
    );
  }

  /// The next older page, appended at [offset] (the loaded row count).
  Future<MessagePage> loadPage(
    ConversationThread thread, {
    int offset = 0,
    int limit = pageSize,
  }) async {
    final messages = await repository.messagesPage(
      thread.id,
      limit: limit,
      offset: offset,
    );
    return MessagePage(
      bubbles: List.unmodifiable(
        _bubbles(messages, primarySenderId: thread.primarySenderId),
      ),
      hasMore: offset + messages.length < thread.messageCount,
    );
  }

  /// SQL search inside the thread, newest first, independent of loaded pages.
  Future<List<MessageBubble>> search(
    ConversationThread thread,
    String query, {
    int limit = 100,
  }) async {
    final messages = await repository.searchMessages(
      thread.id,
      query,
      limit: limit,
    );
    return List.unmodifiable(
      _bubbles(messages, primarySenderId: thread.primarySenderId),
    );
  }

  List<MessageBubble> _bubbles(
    List<ConversationMessageRow> messages, {
    required int? primarySenderId,
  }) => [
    for (final message in messages)
      MessageBubble(
        id: message.id,
        text: message.text,
        at: message.at,
        senderName: message.actorName ?? 'مرسل غير معروف',
        actorId: message.actorId,
        fromPrimarySender: message.actorId == primarySenderId,
        attachmentCount: message.attachmentCount,
        attachmentMediaType: message.attachmentMediaType,
      ),
  ];

  List<MessageDay> _days(List<MessageBubble> bubbles) {
    final days = <MessageDay>[];
    for (final bubble in bubbles) {
      final at = bubble.at;
      final date = at == null
          ? null
          : DateTime.utc(at.toUtc().year, at.toUtc().month, at.toUtc().day);
      if (days.isNotEmpty && days.last.date == date) {
        days.last.bubbles.add(bubble);
      } else {
        days.add(MessageDay(date: date, bubbles: [bubble]));
      }
    }
    return days;
  }

  String _titleOf(ConversationListRow row) {
    final title = row.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    final sourceId = row.sourceConversationId?.trim();
    if (sourceId != null && sourceId.isNotEmpty) return sourceId;
    return 'محادثة بدون عنوان';
  }

  String _snippetOf(ConversationListRow row) {
    final text = row.lastText?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text != null && text.isNotEmpty) return text;
    return 'رسالة بدون نص';
  }
}
