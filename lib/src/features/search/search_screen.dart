import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/l10n/app_strings.dart';
import '../../services/embeddings/model_installer.dart';
import 'search_controller.dart';
import 'search_service.dart';
import 'search_strings.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.onOpenPerson});

  /// Opens a result's person profile; null leaves the person name as plain
  /// metadata (the screen stays usable on its own, as in its tests).
  final ValueChanged<int>? onOpenPerson;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _queryController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final copy = SearchStrings.forLocale(strings.locale);
    final state = ref.watch(searchControllerProvider);
    final controller = ref.read(searchControllerProvider.notifier);
    final semanticStatus = ref.watch(semanticSearchStatusProvider).asData?.value;
    final setup = ref.watch(semanticSetupProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(36, 30, 36, 48),
      children: [
        Text(
          strings.searchTitle,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          strings.searchSubtitle,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: const Color(0xFF536273)),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('search-query-field'),
                  controller: _queryController,
                  decoration: InputDecoration(
                    labelText: strings.searchQueryLabel,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: controller.setQuery,
                ),
                const SizedBox(height: 6),
                Text(
                  copy.everyWord,
                  key: const Key('search-and-hint'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(
                      width: 190,
                      child: TextField(
                        key: const Key('search-from-field'),
                        controller: _fromController,
                        decoration: InputDecoration(
                          labelText: strings.searchFromLabel,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) =>
                            controller.setFrom(_parseDate(value)),
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: TextField(
                        key: const Key('search-to-field'),
                        controller: _toController,
                        decoration: InputDecoration(
                          labelText: strings.searchToLabel,
                          border: const OutlineInputBorder(),
                        ),
                        onChanged: (value) =>
                            controller.setTo(_parseDate(value)),
                      ),
                    ),
                    SizedBox(
                      width: 210,
                      // The subtree key stays stable for tests and taps; the
                      // inner key changes so clearing the type by its chip
                      // also resets the dropdown's visible value.
                      child: KeyedSubtree(
                        key: const Key('search-type-dropdown'),
                        child: DropdownButtonFormField<String?>(
                          key: ValueKey(
                            'search-type-${state.eventType ?? 'any'}',
                          ),
                          initialValue: state.eventType,
                          // Long translated labels must shrink, not overflow.
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: strings.searchTypeLabel,
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(strings.searchAnyType),
                            ),
                            for (final type in searchEventTypes)
                              DropdownMenuItem<String?>(
                                value: type,
                                child: Text(type),
                              ),
                          ],
                          onChanged: controller.setEventType,
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('search-clear-filters'),
                      style: OutlinedButton.styleFrom(
                        // Comfortable pointer target for a primary action.
                        minimumSize: const Size(44, 44),
                      ),
                      onPressed: () {
                        _fromController.clear();
                        _toController.clear();
                        controller.clearFilters();
                      },
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: Text(strings.searchClearFilters),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (semanticStatus != null &&
            semanticStatus.supported &&
            (!semanticStatus.modelInstalled ||
                semanticStatus.canIndex ||
                state.indexingSemantic)) ...[
          const SizedBox(height: TmSpace.m),
          _SemanticStatusLine(
            copy: copy,
            status: semanticStatus,
            setup: setup,
            indexing: state.indexingSemantic,
            onIndex: controller.indexSemantic,
            onDownload: ref
                .read(semanticSetupProvider.notifier)
                .downloadModel,
          ),
        ],
        if (state.hasFilters) ...[
          const SizedBox(height: 14),
          _ActiveFilters(
            copy: copy,
            state: state,
            onClearType: () => controller.setEventType(null),
            onClearFrom: () {
              _fromController.clear();
              controller.setFrom(null);
            },
            onClearTo: () {
              _toController.clear();
              controller.setTo(null);
            },
          ),
        ],
        const SizedBox(height: 20),
        if (state.loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Semantics(
                  label: strings.searchLoading,
                  child: const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(child: Text(strings.searchLoading)),
              ],
            ),
          )
        else if (state.failed)
          _Message(text: strings.searchFailed, icon: Icons.error_outline)
        else if (state.results.isEmpty)
          _EmptyState(
            appStrings: strings,
            copy: copy,
            state: state,
            onWiden: () {
              _fromController.clear();
              _toController.clear();
              controller.clearFilters();
            },
          )
        else ...[
          _ResultCount(copy: copy, state: state),
          if (state.mode == SearchMode.hybrid) ...[
            const SizedBox(height: 2),
            Text(
              copy.semanticMode,
              key: const Key('search-semantic-mode'),
              style: TmType.captionStyle,
            ),
          ],
          const SizedBox(height: 10),
          for (final row in state.results)
            _SearchResultTile(
              row: row,
              appStrings: strings,
              copy: copy,
              onOpenPerson: widget.onOpenPerson,
            ),
        ],
      ],
    );
  }

  static DateTime? _parseDate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed);
  }
}

/// One honest line about the optional semantic layer, plus the single action
/// that moves it forward.
///
/// The three states are derived from local facts, never inferred: the model is
/// missing (with its real download size), the model is installed but nothing is
/// indexed, or the index covers N of M messages. Nothing is downloaded or
/// embedded without the tap rendered here.
class _SemanticStatusLine extends StatelessWidget {
  const _SemanticStatusLine({
    required this.copy,
    required this.status,
    required this.setup,
    required this.indexing,
    required this.onIndex,
    required this.onDownload,
  });

  final SearchStrings copy;
  final SemanticSearchStatus status;
  final SemanticSetupState setup;
  final bool indexing;
  final Future<void> Function() onIndex;
  final Future<void> Function() onDownload;

  @override
  Widget build(BuildContext context) {
    final progress = status.progress;
    final downloading = setup.downloading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: TmSpace.m,
          runSpacing: TmSpace.s,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!status.modelInstalled && !downloading)
              Row(
                key: const Key('search-semantic-missing'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_download_outlined,
                    size: TmSize.homeHeaderIcon,
                    color: TmColors.text2,
                  ),
                  const SizedBox(width: TmSpace.s),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      copy.semanticModelMissing(
                        (semanticModelDownloadBytes / 1000000).ceil(),
                      ),
                      style: TmType.captionStyle,
                    ),
                  ),
                ],
              ),
            if (status.modelInstalled && status.isPartial && !indexing)
              Row(
                key: const Key('search-semantic-status'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    size: TmSize.homeHeaderIcon,
                    color: TmColors.text2,
                  ),
                  const SizedBox(width: TmSpace.s),
                  Text(
                    copy.semanticPartial(status.indexed, status.total),
                    style: TmType.captionStyle,
                  ),
                ],
              ),
            if (status.modelInstalled &&
                !status.isPartial &&
                status.canIndex &&
                !indexing)
              Row(
                key: const Key('search-semantic-ready'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    size: TmSize.homeHeaderIcon,
                    color: TmColors.text2,
                  ),
                  const SizedBox(width: TmSpace.s),
                  Text(
                    copy.semanticReady(status.total),
                    style: TmType.captionStyle,
                  ),
                ],
              ),
            if (downloading)
              Row(
                key: const Key('search-semantic-downloading'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: setup.fraction,
                    ),
                  ),
                  const SizedBox(width: TmSpace.s),
                  Text(copy.semanticDownloading, style: TmType.captionStyle),
                ],
              ),
            if (indexing)
              Row(
                key: const Key('search-semantic-indexing'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: TmSpace.s),
                  Text(copy.semanticIndexing, style: TmType.captionStyle),
                  if (progress != null && progress.total > 0) ...[
                    const SizedBox(width: TmSpace.s),
                    Text(
                      copy.semanticProgress(progress.done, progress.total),
                      key: const Key('search-semantic-progress'),
                      style: TmType.captionStyle,
                    ),
                  ],
                ],
              ),
          ],
        ),
        if (setup.failed) ...[
          const SizedBox(height: TmSpace.xs),
          Text(
            copy.semanticDownloadFailed,
            key: const Key('search-semantic-error'),
            style: TmType.captionStyle,
          ),
        ],
        if (!status.modelInstalled && !downloading) ...[
          const SizedBox(height: TmSpace.xs),
          Text(
            copy.semanticConsent,
            key: const Key('search-semantic-consent'),
            style: TmType.captionStyle,
          ),
          TextButton.icon(
            key: const Key('search-semantic-download'),
            style: TextButton.styleFrom(
              minimumSize: const Size(TmHit.min, TmHit.min),
            ),
            onPressed: onDownload,
            icon: const Icon(Icons.download_outlined),
            label: Text(copy.semanticDownload),
          ),
        ] else if (status.canIndex && !indexing && !downloading)
          TextButton.icon(
            key: const Key('search-semantic-index'),
            style: TextButton.styleFrom(
              minimumSize: const Size(TmHit.min, TmHit.min),
            ),
            onPressed: onIndex,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(copy.semanticIndexAction),
          ),
      ],
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.copy,
    required this.state,
    required this.onClearType,
    required this.onClearFrom,
    required this.onClearTo,
  });

  final SearchStrings copy;
  final SearchState state;
  final VoidCallback onClearType;
  final VoidCallback onClearFrom;
  final VoidCallback onClearTo;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('search-active-filters'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          copy.activeFilters,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (state.eventType case final type?)
              InputChip(
                key: const Key('search-filter-type'),
                label: Text(copy.typeFilter(type)),
                deleteIcon: const Icon(Icons.close, size: 16),
                deleteButtonTooltipMessage: copy.removeFilter,
                onDeleted: onClearType,
              ),
            if (state.from case final from?)
              InputChip(
                key: const Key('search-filter-from'),
                label: Text(copy.fromFilter(_formatDay(from))),
                deleteIcon: const Icon(Icons.close, size: 16),
                deleteButtonTooltipMessage: copy.removeFilter,
                onDeleted: onClearFrom,
              ),
            if (state.to case final to?)
              InputChip(
                key: const Key('search-filter-to'),
                label: Text(copy.toFilter(_formatDay(to))),
                deleteIcon: const Icon(Icons.close, size: 16),
                deleteButtonTooltipMessage: copy.removeFilter,
                onDeleted: onClearTo,
              ),
          ],
        ),
      ],
    );
  }
}

class _ResultCount extends StatelessWidget {
  const _ResultCount({required this.copy, required this.state});

  final SearchStrings copy;
  final SearchState state;

  @override
  Widget build(BuildContext context) {
    final term = state.query.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          copy.resultsFor(state.totalHits, term),
          key: const Key('search-hit-count'),
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (state.totalHits > state.results.length) ...[
          const SizedBox(height: 2),
          Text(
            copy.showingFirst(state.results.length, state.totalHits),
            key: const Key('search-hit-page'),
            style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
          ),
        ],
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.appStrings,
    required this.copy,
    required this.state,
    required this.onWiden,
  });

  final AppStrings appStrings;
  final SearchStrings copy;
  final SearchState state;
  final VoidCallback onWiden;

  @override
  Widget build(BuildContext context) {
    final query = state.query.trim();
    final explanation = query.isEmpty
        ? appStrings.searchEmptyNoQuery
        : state.hasFilters
        ? '${copy.noMatch} ${copy.quote(query)}. ${copy.narrowed}'
        : '${copy.noMatch} ${copy.quote(query)}. ${copy.noMatchTry}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        key: const Key('search-empty-state'),
        children: [
          const Icon(Icons.search_off, size: 32, color: Color(0xFF98A2B3)),
          const SizedBox(height: 10),
          Text(
            appStrings.searchEmptyTitle,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            explanation,
            key: const Key('search-empty-explanation'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF667085)),
          ),
          if (state.hasFilters) ...[
            const SizedBox(height: 10),
            if (state.eventType case final type?)
              Text(
                copy.typeFilter(type),
                key: const Key('search-empty-filter-type'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF536273)),
              ),
            if (state.from case final from?)
              Text(
                copy.fromFilter(_formatDay(from)),
                key: const Key('search-empty-filter-from'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF536273)),
              ),
            if (state.to case final to?)
              Text(
                copy.toFilter(_formatDay(to)),
                key: const Key('search-empty-filter-to'),
                style: const TextStyle(fontSize: 12, color: Color(0xFF536273)),
              ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const Key('search-widen'),
              style: FilledButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: onWiden,
              icon: const Icon(Icons.manage_search),
              label: Text(copy.widen),
            ),
            const SizedBox(height: 6),
            Text(
              copy.widenHint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF98A2B3)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.row,
    required this.appStrings,
    required this.copy,
    this.onOpenPerson,
  });

  final SearchResultRow row;
  final AppStrings appStrings;
  final SearchStrings copy;
  final ValueChanged<int>? onOpenPerson;

  @override
  Widget build(BuildContext context) {
    final hit = row.hit;
    final excerpt = hit.textContent?.trim();
    final date = hit.timestampNormalized == null
        ? appStrings.searchUnknownDate
        : _formatDate(hit.timestampNormalized!);
    return Card(
      key: ValueKey('search-hit-${hit.eventId}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              excerpt == null || excerpt.isEmpty
                  ? '(${hit.eventType})'
                  : excerpt,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _Meta(
                  textKey: ValueKey('search-hit-kind-${hit.eventId}'),
                  text: hit.eventType,
                ),
                _Meta(
                  textKey: ValueKey('search-hit-conversation-${hit.eventId}'),
                  text:
                      '${copy.conversation}: '
                      '${row.conversationTitle ?? copy.unknownConversation}',
                ),
                _Meta(
                  textKey: ValueKey('search-hit-person-${hit.eventId}'),
                  text:
                      '${copy.person}: '
                      '${row.personName ?? copy.unknownPerson}',
                  // A named, stored actor opens their profile; a result without
                  // one keeps the same line as plain metadata.
                  onTap: switch ((onOpenPerson, row.personId)) {
                    (final open?, final personId?) => () => open(personId),
                    _ => null,
                  },
                  tooltip: appStrings.personViewProfile,
                ),
                _Meta(
                  textKey: ValueKey('search-hit-date-${hit.eventId}'),
                  text: '${copy.date}: $date',
                ),
                // A source locator is a path-like id: keep it LTR even in an
                // RTL app so it can still be read and compared.
                _Meta(
                  textKey: ValueKey('search-hit-source-${hit.eventId}'),
                  text: '${appStrings.searchSource}: ${hit.sourceLocator}',
                  textDirection: TextDirection.ltr,
                  monospace: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.textKey,
    required this.text,
    this.textDirection,
    this.monospace = false,
    this.onTap,
    this.tooltip,
  });

  final Key textKey;
  final String text;
  final TextDirection? textDirection;
  final bool monospace;

  /// When set, the metadata line is a link to the record behind it.
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final onTap = this.onTap;
    final label = Text(
      key: textKey,
      text,
      textDirection: textDirection,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        fontFamily: monospace ? 'monospace' : null,
        color: onTap != null
            ? TmColors.primary
            : monospace
            ? const Color(0xFF98A2B3)
            : const Color(0xFF667085),
        decoration: onTap == null ? null : TextDecoration.underline,
      ),
    );
    if (onTap == null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: label,
      );
    }
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        key: ValueKey('search-hit-person-link'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, minHeight: 24),
          child: Center(widthFactor: 1, child: label),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFB42318)),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

String _formatDay(DateTime value) {
  final utc = value.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)}';
}

String _formatDate(DateTime value) {
  final utc = value.toUtc();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
      '${two(utc.hour)}:${two(utc.minute)} UTC';
}
