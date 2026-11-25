import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/import_labels.dart';
import '../../data/repositories/timeline_repository.dart';
import 'timeline_controller.dart';
import 'timeline_service.dart';
import 'timeline_strings.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load once the first frame is built so filters and counts are visible.
    Future.microtask(() {
      if (mounted) ref.read(timelineControllerProvider.notifier).run();
    });
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final copy = TimelineStrings.forLocale(strings.locale);
    final state = ref.watch(timelineControllerProvider);
    final controller = ref.read(timelineControllerProvider.notifier);

    return CustomScrollView(
      key: const Key('timeline-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(36, 30, 36, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.timelineTitle,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.timelineSubtitle,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: const Color(0xFF536273)),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<TimelineGrouping>(
                      key: const Key('timeline-grouping-toggle'),
                      style: const ButtonStyle(
                        minimumSize: WidgetStatePropertyAll(Size(64, 44)),
                      ),
                      segments: [
                        ButtonSegment(
                          value: TimelineGrouping.day,
                          label: Text(strings.timelineDay),
                        ),
                        ButtonSegment(
                          value: TimelineGrouping.month,
                          label: Text(strings.timelineMonth),
                        ),
                      ],
                      selected: {state.grouping},
                      onSelectionChanged: (selection) =>
                          controller.setGrouping(selection.first),
                    ),
                    SizedBox(
                      width: 190,
                      child: TextField(
                        key: const Key('timeline-from-field'),
                        controller: _fromController,
                        decoration: InputDecoration(
                          labelText: strings.timelineFromLabel,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          final parsed = DateTime.tryParse(value.trim());
                          if (value.trim().isEmpty || parsed != null) {
                            controller.setFrom(parsed);
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: 190,
                      child: TextField(
                        key: const Key('timeline-to-field'),
                        controller: _toController,
                        decoration: InputDecoration(
                          labelText: strings.timelineToLabel,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          final parsed = DateTime.tryParse(value.trim());
                          if (value.trim().isEmpty || parsed != null) {
                            controller.setTo(parsed);
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String?>(
                        key: const Key('timeline-type-dropdown'),
                        initialValue: state.eventType,
                        // Long translated labels must shrink, not overflow.
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: strings.timelineTypeLabel,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(strings.timelineAnyType),
                          ),
                          for (final type in const [
                            'message',
                            'comment',
                            'reaction',
                            'post',
                          ])
                            DropdownMenuItem<String?>(
                              value: type,
                              child: Text(type),
                            ),
                        ],
                        onChanged: controller.setEventType,
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('timeline-clear-filters'),
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
                      label: Text(strings.timelineClearFilters),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (state.timeline != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      copy.summary(
                        state.timeline!.totalCount,
                        state.timeline!.buckets.length,
                      ),
                      key: const Key('timeline-summary'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (state.loading)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            sliver: SliverToBoxAdapter(child: Text(strings.timelineLoading)),
          )
        else if (state.failed)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            sliver: SliverToBoxAdapter(
              child: Text(
                strings.timelineFailed,
                style: const TextStyle(color: Color(0xFFB42318)),
              ),
            ),
          )
        else if (state.timeline == null || state.timeline!.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(strings.timelineEmpty),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(36, 0, 36, 48),
            // Only the groups in/near the viewport are built; each one fetches
            // its first page of rows when it is built.
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final bucket = state.timeline!.buckets[index];
                return _TimelineBucketCard(
                  key: ValueKey(
                    'timeline-bucket-${bucket.key ?? 'unknown'}-'
                    '${state.grouping.name}-${state.from}-${state.to}-'
                    '${state.eventType}',
                  ),
                  bucket: bucket,
                  grouping: state.grouping,
                  from: state.from,
                  to: state.to,
                  eventType: state.eventType,
                  strings: strings,
                  copy: copy,
                );
              }, childCount: state.timeline!.buckets.length),
            ),
          ),
      ],
    );
  }
}

class _TimelineBucketCard extends ConsumerStatefulWidget {
  const _TimelineBucketCard({
    super.key,
    required this.bucket,
    required this.grouping,
    required this.from,
    required this.to,
    required this.eventType,
    required this.strings,
    required this.copy,
  });

  final TimelineBucket bucket;
  final TimelineGrouping grouping;
  final DateTime? from;
  final DateTime? to;
  final String? eventType;
  final AppStrings strings;
  final TimelineStrings copy;

  @override
  ConsumerState<_TimelineBucketCard> createState() =>
      _TimelineBucketCardState();
}

class _TimelineBucketCardState extends ConsumerState<_TimelineBucketCard> {
  final List<TimelineRow> _rows = [];
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final repository = await ref.read(timelineRepositoryProvider.future);
      final rows = await TimelineService(repository).loadBucketPage(
        widget.bucket,
        from: widget.from,
        to: widget.to,
        eventType: widget.eventType,
        offset: _rows.length,
      );
      if (!mounted) return;
      setState(() {
        _rows.addAll(rows);
        _loading = false;
        _failed = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bucket = widget.bucket;
    final strings = widget.strings;
    final label = bucket.key ?? strings.timelineUnknownDate;
    final remaining = bucket.count - _rows.length;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${bucket.count} '
                  '${bucket.count == 1 ? strings.timelineEventSingular : strings.timelineEvents}',
                  key: ValueKey('timeline-count-${bucket.key ?? 'unknown'}'),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667085),
                  ),
                ),
                if (bucket.isUnknown)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      '?',
                      semanticsLabel: strings.timelineMissingTimestamp,
                    ),
                  ),
              ],
            ),
            if (bucket.isUnknown) ...[
              const SizedBox(height: 6),
              Text(
                strings.timelineUnknownHint,
                style: const TextStyle(fontSize: 12, color: Color(0xFF98A2B3)),
              ),
            ],
            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final event in _rows)
                TimelineEventRow(
                  key: ValueKey('timeline-row-${event.eventId}'),
                  event: event,
                ),
            ],
            if (_rows.length < bucket.count) ...[
              const SizedBox(height: 4),
              if (_failed)
                Text(
                  widget.copy.loadFailed,
                  key: ValueKey(
                    'timeline-load-failed-${bucket.key ?? 'unknown'}',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFB42318),
                  ),
                )
              else
                OutlinedButton(
                  key: ValueKey(
                    'timeline-load-more-${bucket.key ?? 'unknown'}',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  onPressed: _loading ? null : _load,
                  child: Text(widget.copy.loadMoreRemaining(remaining)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One event row. Public so a test can count how many rows the lazy list
/// actually built without reaching into a private widget.
class TimelineEventRow extends StatelessWidget {
  const TimelineEventRow({super.key, required this.event});

  final TimelineRow event;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            event.textContent?.trim().isNotEmpty == true
                ? event.textContent!.trim()
                : (importEventLabel(
                          event.eventType,
                          isRtl: Directionality.of(context) == TextDirection.rtl,
                        ) ??
                      '(${event.eventType})'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          // Path-like locators stay LTR inside an RTL layout.
          child: Text(
            event.sourceLocator,
            textDirection: TextDirection.ltr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Color(0xFF98A2B3),
            ),
          ),
        ),
      ],
    ),
  );
}
