import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tm_motion.dart';
import '../../core/design/tokens.dart';
import 'messages_controller.dart';
import 'messages_service.dart';
import 'messages_strings.dart';

/// «الرسائل» — صندوق وارد ومحادثة للقراءة فقط، حسب مرجع المالك 04-messages.jpg.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({
    super.key,
    this.onOpenSection,
    this.importPageBuilder,
    this.onOpenPerson,
  });

  final ValueChanged<String>? onOpenSection;
  final WidgetBuilder? importPageBuilder;

  /// Opens the profile of a sender tapped inside the open thread; null keeps
  /// the participant names plain text (and every existing test unchanged).
  final ValueChanged<int>? onOpenPerson;

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final TextEditingController _search = TextEditingController();
  bool _sortByCount = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openImport(BuildContext context) {
    final builder = widget.importPageBuilder;
    if (builder != null) {
      Navigator.of(context)
          .push<void>(MaterialPageRoute<void>(builder: builder));
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(messagesSnapshotProvider);
    return snapshot.when(
      loading: () => const Center(
        key: Key('messages-loading'),
        child: TmLoader(),
      ),
      error: (_, _) => Center(
        key: const Key('messages-failed'),
        child: Padding(
          padding: const EdgeInsets.all(TmSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تعذّر تحميل المحادثات من الأرشيف المحلي.'),
              const SizedBox(height: TmSpace.m),
              OutlinedButton(
                onPressed: () => ref.invalidate(messagesSnapshotProvider),
                child: const Text('حاول مرة تانية'),
              ),
            ],
          ),
        ),
      ),
      data: (value) => Padding(
        padding: const EdgeInsets.all(TmSpace.m),
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: TmSize.messagesContentMaxWidth,
                minHeight: constraints.maxHeight,
              ),
              child: value.isEmpty
                  ? _MessagesEmpty(total: value.totalConversations)
                  : _MessagesBody(
                      snapshot: value,
                      search: _search,
                      sortByCount: _sortByCount,
                      onSort: () =>
                          setState(() => _sortByCount = !_sortByCount),
                      onSelect: (id) => ref
                          .read(messagesSelectionProvider.notifier)
                          .select(id),
                      onOpenSection: widget.onOpenSection,
                      onImport: () => _openImport(context),
                      onOpenPerson: widget.onOpenPerson,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessagesBody extends StatelessWidget {
  const _MessagesBody({
    required this.snapshot,
    required this.search,
    required this.sortByCount,
    required this.onSort,
    required this.onSelect,
    required this.onOpenSection,
    required this.onImport,
    this.onOpenPerson,
  });

  final MessagesSnapshot snapshot;
  final TextEditingController search;
  final bool sortByCount;
  final VoidCallback onSort;
  final ValueChanged<int> onSelect;
  final ValueChanged<String>? onOpenSection;
  final VoidCallback onImport;
  final ValueChanged<int>? onOpenPerson;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= TmSize.messagesThreeColumnMinWidth;
      final inbox = _ConversationListPanel(
        snapshot: snapshot,
        search: search,
        sortByCount: sortByCount,
        onSort: onSort,
        onSelect: onSelect,
      );
      final thread = _ThreadPanel(
        thread: snapshot.selected,
        onOpenSection: onOpenSection,
        onOpenPerson: onOpenPerson,
      );
      final shortcuts = _MessagesShortcuts(
        totalConversations: snapshot.totalConversations,
        onOpenSection: onOpenSection,
        onImport: onImport,
      );
      if (!wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: TmSize.messagesInboxFlex, child: inbox),
            const SizedBox(width: TmSpace.s),
            Expanded(flex: TmSize.messagesThreadFlex, child: thread),
          ],
        );
      }
      // Row follows Directionality: shortcuts at right, inbox in the middle,
      // and the open conversation at left.
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: TmSize.messagesSidebarFlex, child: shortcuts),
          const SizedBox(width: TmSpace.s),
          Expanded(flex: TmSize.messagesInboxFlex, child: inbox),
          const SizedBox(width: TmSpace.s),
          Expanded(flex: TmSize.messagesThreadFlex, child: thread),
        ],
      );
    },
  );
}

class _ConversationListPanel extends StatefulWidget {
  const _ConversationListPanel({
    required this.snapshot,
    required this.search,
    required this.sortByCount,
    required this.onSort,
    required this.onSelect,
  });

  final MessagesSnapshot snapshot;
  final TextEditingController search;
  final bool sortByCount;
  final VoidCallback onSort;
  final ValueChanged<int> onSelect;

  @override
  State<_ConversationListPanel> createState() => _ConversationListPanelState();
}

class _ConversationListPanelState extends State<_ConversationListPanel> {
  @override
  void initState() {
    super.initState();
    widget.search.addListener(_onQueryChanged);
  }

  @override
  void didUpdateWidget(_ConversationListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search) {
      oldWidget.search.removeListener(_onQueryChanged);
      widget.search.addListener(_onQueryChanged);
    }
  }

  @override
  void dispose() {
    widget.search.removeListener(_onQueryChanged);
    super.dispose();
  }

  void _onQueryChanged() => setState(() {});

  List<ConversationSummary> get _visible {
    final query = widget.search.text.trim().toLowerCase();
    final rows = widget.snapshot.conversations
        .where(
          (row) =>
              query.isEmpty ||
              row.title.toLowerCase().contains(query) ||
              row.snippet.toLowerCase().contains(query),
        )
        .toList();
    if (widget.sortByCount) {
      rows.sort((a, b) => b.messageCount.compareTo(a.messageCount));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _visible;
    final selectedId = widget.snapshot.selected?.id;
    return _MessagesPanel(
      key: const Key('messages-list-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(TmSpace.m),
            child: Row(
              children: [
                Text('الرسائل', style: TmType.h1Style),
                const SizedBox(width: TmSpace.s),
                Text(
                  '${_formatNumber(widget.snapshot.totalConversations)} محادثة',
                  key: const Key('messages-count'),
                  style: TmType.captionStyle.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const Spacer(),
                IconButton(
                  key: const Key('messages-sort'),
                  tooltip: widget.sortByCount ? 'الأكثر رسائل' : 'الأحدث',
                  onPressed: widget.onSort,
                  constraints: const BoxConstraints(
                    minWidth: TmHit.min,
                    minHeight: TmHit.min,
                  ),
                  icon: const Icon(Icons.filter_list),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TmSpace.m),
            child: TextField(
              key: const Key('messages-search'),
              controller: widget.search,
              style: TmType.bodyStyle,
              decoration: InputDecoration(
                hintText: 'دوّر على شخص أو كلمة',
                hintStyle: TmType.bodyMuted,
                prefixIcon: const Icon(Icons.search, color: TmColors.text2),
                filled: true,
                fillColor: TmColors.bg,
                isDense: true,
                contentPadding: const EdgeInsets.all(TmSpace.m),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TmRadius.pill),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: TmSpace.s),
          Expanded(
            child: rows.isEmpty
                ? Padding(
                    key: const Key('messages-no-match'),
                    padding: const EdgeInsets.all(TmSpace.m),
                    child: Text(
                      'ما في محادثة تطابق البحث.',
                      style: TmType.bodyMuted,
                    ),
                  )
                : ListView.separated(
                    key: const Key('messages-conversations'),
                    padding: EdgeInsets.zero,
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: TmSize.hairline,
                      thickness: TmSize.hairline,
                      color: TmColors.border,
                    ),
                    itemBuilder: (context, index) => _ConversationRow(
                      key: ValueKey('messages-conversation-${rows[index].id}'),
                      summary: rows[index],
                      selected: rows[index].id == selectedId,
                      onTap: () => widget.onSelect(rows[index].id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    super.key,
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  final ConversationSummary summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? TmColors.primaryTint : TmColors.card,
    child: InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: TmHit.min),
        padding: const EdgeInsets.symmetric(
          horizontal: TmSpace.m,
          vertical: TmSpace.m,
        ),
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(
              color: selected ? TmColors.primary : TmColors.transparent,
              width: TmSize.messagesSelectedRailWidth,
            ),
          ),
        ),
        child: Row(
          children: [
            _MessagesAvatar(
              name: summary.title,
              size: TmSize.messagesInboxAvatar,
            ),
            const SizedBox(width: TmSpace.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    summary.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TmType.bodyStyle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: TmSpace.xs),
                  Text(
                    summary.snippet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TmType.bodyMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(width: TmSpace.s),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatWhen(summary.lastAt),
                  style: TmType.captionStyle.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (summary.messageCount > 0) ...[
                  const SizedBox(height: TmSpace.xs),
                  Tooltip(
                    message: 'عدد الرسائل المحفوظة في المحادثة',
                    child: Container(
                      key: ValueKey('messages-count-badge-${summary.id}'),
                      constraints: const BoxConstraints(
                        minWidth: TmSize.messagesUnreadBadge,
                        minHeight: TmSize.messagesUnreadBadge,
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(
                        horizontal: TmSpace.xs,
                      ),
                      decoration: const BoxDecoration(
                        color: TmColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        summary.messageCount > TmSize.messagesUnreadMaxCount
                            ? '${TmSize.messagesUnreadMaxCount}+'
                            : '${summary.messageCount}',
                        style: TmType.captionStyle.copyWith(
                          color: TmColors.card,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ThreadPanel extends ConsumerStatefulWidget {
  const _ThreadPanel({
    required this.thread,
    this.onOpenSection,
    this.onOpenPerson,
  });

  final ConversationThread? thread;
  final ValueChanged<String>? onOpenSection;
  final ValueChanged<int>? onOpenPerson;

  @override
  ConsumerState<_ThreadPanel> createState() => _ThreadPanelState();
}

class _ThreadPanelState extends ConsumerState<_ThreadPanel> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  List<MessageBubble> _bubbles = const [];
  List<MessageBubble>? _searchResults;
  bool _loadingOlder = false;
  bool _loadingSearch = false;
  bool _searchFailed = false;
  bool _pageFailed = false;
  bool _hasMore = false;
  String _query = '';
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _applyThread(widget.thread);
  }

  @override
  void didUpdateWidget(_ThreadPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thread?.id != widget.thread?.id) {
      _applyThread(widget.thread);
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _applyThread(ConversationThread? thread) {
    _bubbles = thread == null
        ? const []
        : [for (final day in thread.days) ...day.bubbles];
    _hasMore = thread?.hasMore ?? false;
    _query = '';
    _search.clear();
    _searchGeneration++;
    _searchResults = null;
    _loadingOlder = false;
    _loadingSearch = false;
    _searchFailed = false;
    _pageFailed = false;
    // A reverse thread starts at the newest message. A different conversation
    // must not inherit the previous one's scroll offset.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients || _query.isNotEmpty) return;
    // In a reverse list the top of the conversation is `extentAfter`.
    if (_scroll.position.extentAfter < 320) _loadOlder();
  }

  Future<void> _loadOlder() async {
    final thread = widget.thread;
    if (thread == null || _loadingOlder || !_hasMore) return;
    setState(() => _loadingOlder = true);
    try {
      final repository = await ref.read(conversationRepositoryProvider.future);
      final page = await MessagesService(
        repository,
      ).loadPage(thread, offset: _bubbles.length);
      if (!mounted) return;
      setState(() {
        _bubbles = [..._bubbles, ...page.bubbles];
        _hasMore = page.hasMore;
        _loadingOlder = false;
        _pageFailed = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loadingOlder = false;
        _pageFailed = true;
      });
    }
  }

  void _onSearchChanged(String value) {
    final query = value.trim();
    final generation = ++_searchGeneration;
    _query = query;
    if (query.isEmpty) {
      setState(() {
        _searchResults = null;
        _loadingSearch = false;
        _searchFailed = false;
      });
      return;
    }
    setState(() {
      _loadingSearch = true;
      _searchFailed = false;
      _searchResults = null;
    });
    _runSearch(query, generation);
  }

  Future<void> _runSearch(String query, int generation) async {
    final thread = widget.thread;
    if (thread == null) return;
    try {
      final repository = await ref.read(conversationRepositoryProvider.future);
      final results = await MessagesService(repository).search(thread, query);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searchResults = results;
        _loadingSearch = false;
      });
    } on Object {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _loadingSearch = false;
        _searchFailed = true;
      });
    }
  }

  void _clearSearch() {
    _search.clear();
    _onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.thread;
    if (value == null) {
      return _MessagesPanel(
        key: const Key('messages-thread-panel'),
        child: Center(
          key: const Key('messages-thread-empty'),
          child: Text(
            'اختَر محادثة من القائمة لتقرأها.',
            style: TmType.bodyMuted,
          ),
        ),
      );
    }

    final copy = MessagesStrings.forLocale(Localizations.localeOf(context));
    final visible = _query.isEmpty ? _bubbles : (_searchResults ?? const []);
    return _MessagesPanel(
      key: const Key('messages-thread-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ThreadHeader(
            thread: value,
            onOpenSection: widget.onOpenSection,
            copy: copy,
            loadedCount: _bubbles.length,
            searchController: _search,
            onSearchChanged: _onSearchChanged,
            onClearSearch: _clearSearch,
            hasQuery: _query.isNotEmpty,
          ),
          const Divider(
            height: TmSize.hairline,
            thickness: TmSize.hairline,
          ),
          if (_query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TmSpace.m,
                TmSpace.s,
                TmSpace.m,
                0,
              ),
              child: Text(
                _loadingSearch
                    ? copy.searching
                    : _searchFailed
                    ? copy.searchFailed
                    : copy.searchResults(visible.length),
                key: const Key('messages-thread-search-status'),
                style: TmType.captionStyle.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          Expanded(child: _buildThreadBody(value, visible, copy)),
          const _ReadOnlyComposer(),
        ],
      ),
    );
  }

  Widget _buildThreadBody(
    ConversationThread thread,
    List<MessageBubble> visible,
    MessagesStrings copy,
  ) {
    if (_loadingSearch) {
      return const Center(
        key: Key('messages-thread-search-loading'),
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_searchFailed) {
      return Center(
        key: const Key('messages-thread-search-failed'),
        child: Text(copy.searchFailed, style: TmType.bodyMuted),
      );
    }
    if (_query.isNotEmpty && visible.isEmpty) {
      return Center(
        key: const Key('messages-thread-search-empty'),
        child: Text(copy.noSearchResults, style: TmType.bodyMuted),
      );
    }
    if (visible.isEmpty) {
      return Center(
        child: Text(
          'ما في رسائل محفوظة بهذه المحادثة.',
          style: TmType.bodyMuted,
        ),
      );
    }

    final entries = _entries(visible);
    final showLoader = _query.isEmpty && _loadingOlder;
    final showRetry = _query.isEmpty && _pageFailed;
    final extra = showLoader || showRetry ? 1 : 0;
    return ListView.builder(
      key: const Key('messages-thread'),
      controller: _scroll,
      // Newest at the bottom, like the reference. Older pages append to the
      // model and appear above the current top as the user approaches it.
      reverse: true,
      padding: const EdgeInsets.all(TmSpace.l),
      itemCount: entries.length + extra,
      itemBuilder: (context, index) {
        if (index == entries.length) {
          if (showRetry) {
            return TextButton(
              key: const Key('messages-thread-page-retry'),
              onPressed: _loadOlder,
              child: Text(copy.pageFailed),
            );
          }
          return const Padding(
            padding: EdgeInsets.all(TmSpace.m),
            child: Center(
              child: SizedBox(
                width: TmSize.messagesUnreadBadge,
                height: TmSize.messagesUnreadBadge,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final entry = entries[index];
        if (entry is _DayMarker) {
          return _DaySeparator(date: entry.date);
        }
        final bubble = entry as MessageBubble;
        return Padding(
          padding: const EdgeInsets.only(bottom: TmSpace.s),
          child: MessageBubbleTile(
            key: ValueKey('messages-bubble-${bubble.id}'),
            bubble: bubble,
            showSender: thread.senderCount > 1,
            onOpenPerson: widget.onOpenPerson,
          ),
        );
      },
    );
  }

  /// Flattens newest-first pages into bubble and day-marker entries.
  ///
  /// With `reverse: true`, index 0 sits at the bottom, so a day marker is
  /// emitted after that day's oldest bubble and lands above it on screen.
  List<Object> _entries(List<MessageBubble> bubbles) {
    DateTime? dayOf(MessageBubble bubble) {
      final at = bubble.at;
      if (at == null) return null;
      final utc = at.toUtc();
      return DateTime.utc(utc.year, utc.month, utc.day);
    }

    final entries = <Object>[];
    for (var index = 0; index < bubbles.length; index++) {
      final bubble = bubbles[index];
      final day = dayOf(bubble);
      entries.add(bubble);
      final nextDay = index + 1 < bubbles.length
          ? dayOf(bubbles[index + 1])
          : _noDaySentinel;
      if (day != nextDay) entries.add(_DayMarker(day));
    }
    return entries;
  }
}

class _DayMarker {
  const _DayMarker(this.date);

  final DateTime? date;
}

/// Sentinel that no real day can equal, so the last bubble always gets a
/// separator above it.
final DateTime _noDaySentinel = DateTime.utc(9999);

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.thread,
    this.onOpenSection,
    required this.copy,
    required this.loadedCount,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.hasQuery,
  });

  final ConversationThread thread;
  final ValueChanged<String>? onOpenSection;
  final MessagesStrings copy;
  final int loadedCount;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (thread.firstAt != null) 'من ${thread.firstAt!.toUtc().year}',
      '${_formatNumber(thread.messageCount)} رسالة',
      if (thread.platform != null) _platformLabel(thread.platform!),
    ];
    return Padding(
      padding: const EdgeInsets.all(TmSpace.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _MessagesAvatar(
                name: thread.title,
                size: TmSize.messagesThreadAvatar,
              ),
              const SizedBox(width: TmSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      thread.title,
                      key: const Key('messages-thread-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TmType.h2Style,
                    ),
                    Text(
                      details.join(' · '),
                      style: TmType.captionStyle.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TmSpace.m),
          // 04-messages.jpg puts two shortcut chips under the name: the thread's
          // photos and its numbers. Both move the shell, they don't filter here.
          SizedBox(
            height: TmHit.min,
            child: Row(
              children: [
                _ThreadChip(
                  key: const Key('messages-thread-photos'),
                  icon: Icons.photo_library_outlined,
                  label: 'كل الصور',
                  onTap: onOpenSection == null
                      ? null
                      : () => onOpenSection!('media'),
                ),
                const SizedBox(width: TmSpace.s),
                _ThreadChip(
                  key: const Key('messages-thread-numbers'),
                  icon: Icons.bar_chart_rounded,
                  label: 'الأرقام والإحصائيات',
                  onTap: onOpenSection == null
                      ? null
                      : () => onOpenSection!('analytics'),
                ),
                const Spacer(),
              ],
            ),
          ),
          const SizedBox(height: TmSpace.s),
          TextField(
            key: const Key('messages-thread-search'),
            controller: searchController,
            onChanged: onSearchChanged,
            style: TmType.bodyStyle,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: copy.searchHint,
              hintStyle: TmType.bodyMuted,
              prefixIcon: const Icon(Icons.search, color: TmColors.text2),
              suffixIcon: hasQuery
                  ? IconButton(
                      key: const Key('messages-thread-search-clear'),
                      tooltip: 'مسح البحث',
                      onPressed: onClearSearch,
                      icon: const Icon(Icons.close, color: TmColors.text2),
                    )
                  : null,
              filled: true,
              fillColor: TmColors.bg,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: TmSpace.m,
                vertical: TmSpace.m,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(TmRadius.pill),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: TmSpace.s),
          Text(
            copy.loadedOf(loadedCount, thread.messageCount),
            key: const Key('messages-thread-loaded'),
            style: TmType.captionStyle.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }
}

class _ThreadChip extends StatelessWidget {
  const _ThreadChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: TmColors.card,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(TmRadius.pill),
      side: const BorderSide(color: TmColors.border),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TmRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: TmSpace.m),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: TmSize.messagesIcon, color: TmColors.text2),
            const SizedBox(width: TmSpace.xs),
            Text(
              label,
              style: TmType.captionStyle.copyWith(color: TmColors.text),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final value = date;
    final label = value == null
        ? 'بلا تاريخ'
        : '${value.day} ${_monthNames[value.month - 1]} ${value.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: TmSpace.m),
      child: Center(
        child: Container(
          key: ValueKey(
            value == null
                ? 'messages-day-undated'
                : 'messages-day-${value.year}-${value.month}-${value.day}',
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: TmSpace.m,
            vertical: TmSpace.xs,
          ),
          decoration: BoxDecoration(
            color: TmColors.card,
            borderRadius: BorderRadius.circular(TmRadius.pill),
            border: Border.all(color: TmColors.border),
          ),
          child: Text(label, style: TmType.captionStyle),
        ),
      ),
    );
  }
}

/// One message bubble. Public so the paging test can count the widgets the
/// lazy thread actually built.
class MessageBubbleTile extends StatelessWidget {
  const MessageBubbleTile({
    super.key,
    required this.bubble,
    required this.showSender,
    this.onOpenPerson,
  });

  final MessageBubble bubble;
  final bool showSender;
  final ValueChanged<int>? onOpenPerson;

  @override
  Widget build(BuildContext context) {
    final text = bubble.text?.trim();
    final actorId = bubble.actorId;
    final openPerson = onOpenPerson;
    return Align(
      alignment: bubble.fromPrimarySender
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: TmSize.messagesBubbleMaxWidth,
        ),
        // The bubble hugs its text, as in 04-messages.jpg: a `stretch` column
        // would push every one-line message to the full 520px cap.
        child: Container(
          padding: const EdgeInsets.all(TmSpace.m),
          decoration: BoxDecoration(
            color: bubble.fromPrimarySender
                ? TmColors.card
                : TmColors.primaryTint,
            borderRadius: BorderRadius.circular(TmRadius.card),
            border: Border.all(
              color: bubble.fromPrimarySender
                  ? TmColors.border
                  : TmColors.primaryTint,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showSender) ...[
                if (actorId != null && openPerson != null)
                  Tooltip(
                    message: MessagesStrings.forLocale(
                      Localizations.localeOf(context),
                    ).openParticipantProfile,
                    child: InkWell(
                      key: ValueKey('messages-sender-${bubble.id}'),
                      onTap: () => openPerson(actorId),
                      borderRadius: BorderRadius.circular(TmRadius.chip),
                      child: Text(
                        bubble.senderName,
                        style: TmType.captionStyle.copyWith(
                          color: TmColors.primary,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    bubble.senderName,
                    style: TmType.captionStyle.copyWith(
                      color: TmColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: TmSpace.xs),
              ],
              if (bubble.attachmentCount > 0) ...[
                _AttachmentPlaceholder(bubble: bubble),
                const SizedBox(height: TmSpace.s),
              ],
              if (text != null && text.isNotEmpty)
                Text(text, style: TmType.bodyStyle)
              else if (bubble.attachmentCount == 0)
                Text('رسالة بدون نص', style: TmType.bodyMuted),
              const SizedBox(height: TmSpace.xs),
              // `widthFactor: 1` keeps the time at the bubble's edge without
              // stretching the bubble itself to the 520px cap.
              Align(
                alignment: AlignmentDirectional.centerEnd,
                widthFactor: 1,
                child: Text(
                  _clock(bubble.at),
                  textDirection: TextDirection.ltr,
                  style: TmType.captionStyle.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The archive keeps attachment metadata only; do not imply the bytes are
/// present or show a generated/guessed image.
class _AttachmentPlaceholder extends StatelessWidget {
  const _AttachmentPlaceholder({required this.bubble});

  final MessageBubble bubble;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('messages-attachment-placeholder'),
    width: TmSize.messagesAttachmentPreviewWidth,
    height: TmSize.messagesAttachmentPreviewHeight,
    decoration: BoxDecoration(
      color: TmColors.bg,
      borderRadius: BorderRadius.circular(TmRadius.chip),
      border: Border.all(color: TmColors.border),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(_mediaIcon(bubble.attachmentMediaType), color: TmColors.text2),
        const SizedBox(height: TmSpace.s),
        Text(
          bubble.attachmentCount == 1
              ? '${_mediaLabel(bubble.attachmentMediaType)} من الأرشيف'
              : '${_formatNumber(bubble.attachmentCount)} مرفقات من الأرشيف',
          style: TmType.captionStyle,
        ),
        Text(
          'معلومات المرفق محفوظة محلياً',
          style: TmType.captionStyle.copyWith(fontWeight: FontWeight.w400),
        ),
      ],
    ),
  );
}

class _ReadOnlyComposer extends StatelessWidget {
  const _ReadOnlyComposer();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(TmSpace.m),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            key: const Key('messages-composer'),
            enabled: false,
            style: TmType.bodyStyle,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText:
                  'هاي محادثة من ماضيك — للقراءة بس، لا يتم إرسال أي رسائل',
              hintStyle: TmType.captionStyle.copyWith(
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: TmColors.text2,
                size: TmSize.messagesIcon,
              ),
              filled: true,
              fillColor: TmColors.bg,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: TmSpace.m,
                vertical: TmSpace.m,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(TmRadius.pill),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: TmSpace.s),
        // The reference keeps a greyed circular send affordance to show that
        // this archive is read-only; it is disabled, not decorative.
        IconButton.filledTonal(
          key: const Key('messages-send-disabled'),
          onPressed: null,
          tooltip: 'الإرسال غير مفعّل لهذه المحادثة',
          constraints: const BoxConstraints(
            minWidth: TmHit.min,
            minHeight: TmHit.min,
          ),
          icon: const Icon(Icons.arrow_upward, size: TmSize.messagesIcon),
        ),
      ],
    ),
  );
}

class _MessagesShortcuts extends StatelessWidget {
  const _MessagesShortcuts({
    required this.totalConversations,
    required this.onOpenSection,
    required this.onImport,
  });

  final int totalConversations;
  final ValueChanged<String>? onOpenSection;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _MessagesPanel(
        key: const Key('messages-shortcuts'),
        child: Padding(
          padding: const EdgeInsets.all(TmSpace.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('الاختصارات', style: TmType.h2Style)),
                  Text(
                    _formatNumber(totalConversations),
                    style: TmType.captionStyle,
                  ),
                ],
              ),
              const Divider(height: TmSize.hairline),
              for (final entry in const [
                (label: 'ملفي', icon: Icons.person_outline, section: 'people'),
                (label: 'الرئيسية', icon: Icons.home_outlined, section: 'home'),
                (
                  label: 'قصتك بالأرقام',
                  icon: Icons.bolt_outlined,
                  section: 'story',
                ),
                (
                  label: 'التحليلات',
                  icon: Icons.bar_chart,
                  section: 'analytics',
                ),
                (
                  label: 'الرسائل',
                  icon: Icons.chat_bubble_outline,
                  section: 'messages',
                ),
                (label: 'الصور', icon: Icons.image_outlined, section: 'media'),
                (
                  label: 'الأشخاص',
                  icon: Icons.people_outline,
                  section: 'people',
                ),
                (
                  label: 'الإعدادات',
                  icon: Icons.settings_outlined,
                  section: 'settings',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: TmSpace.xs),
                  child: _ShortcutRow(
                    key: ValueKey('messages-shortcut-${entry.label}'),
                    label: entry.label,
                    icon: entry.icon,
                    selected: entry.section == 'messages',
                    onTap: onOpenSection == null
                        ? null
                        : () => onOpenSection!(entry.section),
                  ),
                ),
              const Divider(height: TmSize.hairline),
              SizedBox(
                height: TmHit.min,
                child: FilledButton.icon(
                  key: const Key('messages-import'),
                  onPressed: onImport,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: Text(
                    'استيراد بيانات جديدة',
                    style: TmType.bodyStyle.copyWith(color: TmColors.card),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const Spacer(),
      _MessagesPanel(
        key: const Key('messages-privacy'),
        child: Padding(
          padding: const EdgeInsets.all(TmSpace.m),
          child: Column(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: TmColors.success,
                size: TmType.h2,
              ),
              const SizedBox(height: TmSpace.s),
              Text('الخصوصية والأمان', style: TmType.h2Style),
              Text(
                'ملفاتك محلية على جهازك، ولا تُرسل إلى الإنترنت.',
                textAlign: TextAlign.center,
                style: TmType.captionStyle.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: TmColors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: TmHit.min),
        padding: const EdgeInsets.symmetric(horizontal: TmSpace.s),
        decoration: BoxDecoration(
          color: selected ? TmColors.primaryTint : TmColors.transparent,
          borderRadius: BorderRadius.circular(TmRadius.chip),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? TmColors.primary : TmColors.text2,
              size: TmType.h2,
            ),
            const SizedBox(width: TmSpace.s),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TmType.bodyStyle.copyWith(
                  color: selected ? TmColors.primary : TmColors.text,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MessagesAvatar extends StatelessWidget {
  const _MessagesAvatar({
    required this.name,
    this.size = TmSize.messagesAvatar,
  });

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final index = _avatarIndex(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: TmColors.avatarTints[index],
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials(name),
        style: TmType.captionStyle.copyWith(
          color: TmColors.avatarForegrounds[index],
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MessagesPanel extends StatelessWidget {
  const _MessagesPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: TmColors.card,
      borderRadius: BorderRadius.circular(TmRadius.card),
      border: Border.all(color: TmColors.border),
    ),
    child: child,
  );
}

class _MessagesEmpty extends StatelessWidget {
  const _MessagesEmpty({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) => _MessagesPanel(
    key: const Key('messages-empty'),
    child: Padding(
      padding: const EdgeInsets.all(TmSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ما في محادثات بعد', style: TmType.h1Style),
          const SizedBox(height: TmSpace.s),
          Text(
            total == 0
                ? 'استورد نسخة بياناتك لتقرأ محادثاتك محلياً، بدون أي رفع.'
                : 'ما في محادثة تحمل رسائل داخل الأرشيف المستورد.',
            style: TmType.bodyMuted,
          ),
        ],
      ),
    ),
  );
}

String _formatNumber(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}

String _initials(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? '؟' : trimmed.characters.first;
}

int _avatarIndex(String name) => name.runes.fold<int>(
  0,
  (hash, rune) => (hash * 31 + rune) % TmColors.avatarTints.length,
);

const List<String> _monthNames = [
  'كانون الثاني',
  'شباط',
  'آذار',
  'نيسان',
  'أيار',
  'حزيران',
  'تموز',
  'آب',
  'أيلول',
  'تشرين الأول',
  'تشرين الثاني',
  'كانون الأول',
];

String _formatWhen(DateTime? value) {
  if (value == null) return 'بلا تاريخ';
  final utc = value.toUtc();
  final now = DateTime.now().toUtc();
  final day = DateTime.utc(utc.year, utc.month, utc.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  if (day == today) return 'اليوم ${_clock(utc)}';
  if (day == today.subtract(const Duration(days: 1))) return 'أمس';
  return '${utc.day} ${_monthNames[utc.month - 1]}';
}

String _clock(DateTime? value) {
  if (value == null) return '—';
  final utc = value.toUtc();
  return '${utc.hour.toString().padLeft(2, '0')}:'
      '${utc.minute.toString().padLeft(2, '0')}';
}

String _platformLabel(String platform) => switch (platform) {
  'facebook' => 'فيسبوك',
  'instagram' => 'إنستغرام',
  'whatsapp' => 'واتساب',
  _ => platform,
};

IconData _mediaIcon(String? mediaType) => switch (mediaType) {
  'image' => Icons.image_outlined,
  'video' => Icons.videocam_outlined,
  'audio' => Icons.audiotrack_outlined,
  _ => Icons.attach_file,
};

String _mediaLabel(String? mediaType) => switch (mediaType) {
  'image' => 'صورة',
  'video' => 'فيديو',
  'audio' => 'تسجيل صوتي',
  _ => 'مرفق',
};
