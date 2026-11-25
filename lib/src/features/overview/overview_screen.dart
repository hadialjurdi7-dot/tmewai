import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tm_motion.dart';
import '../../core/l10n/app_strings.dart';
import '../../domain/models/event_search_hit.dart';
import '../search/search_controller.dart';
import 'overview_controller.dart';
import 'overview_service.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final stats = ref.watch(overviewStatsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(36, 30, 36, 48),
      children: [
        Text(
          strings.overviewTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          strings.overviewSubtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF536273)),
        ),
        const SizedBox(height: 20),
        stats.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Semantics(
                label: strings.overviewTitle,
                child: const TmLoader(),
              ),
            ),
          ),
          error: (_, _) => Text(
            strings.overviewFailed,
            style: const TextStyle(color: Color(0xFFB42318)),
          ),
          data: (value) {
            if (value.totalEvents == 0) return Text(strings.overviewEmpty);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatCard(
                  key: const Key('overview-card-activity'),
                  strings: strings,
                  stat: OverviewStat(
                    label:
                        '${strings.overviewPeriod}: '
                        '${_formatPeriod(value, strings.overviewUnknownDate)}',
                    value: value.datedCount,
                    drillDown: value.activityCard.drillDown,
                  ),
                ),
                _StatCard(
                  key: const Key('overview-card-unknown'),
                  strings: strings,
                  stat: value.unknownCard,
                ),
                _Section(title: strings.overviewEventTypes),
                for (final stat in value.eventTypes)
                  _StatCard(
                    key: Key('overview-card-type-${stat.label}'),
                    strings: strings,
                    stat: stat,
                  ),
                _Section(title: strings.overviewDays),
                for (final day in value.dayBuckets.reversed.take(14))
                  _StatCard(
                    key: Key('overview-card-day-${day.key}'),
                    strings: strings,
                    stat: OverviewStat(
                      label: day.key,
                      value: day.count,
                      drillDown: day.drillDown,
                    ),
                  ),
                if (value.conversations.isNotEmpty) ...[
                  _Section(title: strings.overviewConversations),
                  for (final stat in value.conversations)
                    _StatCard(strings: strings, stat: stat),
                ],
                if (value.people.isNotEmpty) ...[
                  _Section(title: strings.overviewPeople),
                  for (final stat in value.people)
                    _StatCard(strings: strings, stat: stat),
                ],
                if (value.sourceFiles.isNotEmpty) ...[
                  _Section(title: strings.overviewFiles),
                  for (final stat in value.sourceFiles)
                    _StatCard(strings: strings, stat: stat),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  static String _formatPeriod(OverviewStats stats, String unknown) {
    String format(DateTime? value) {
      if (value == null) return unknown;
      final utc = value.toUtc();
      String two(int number) => number.toString().padLeft(2, '0');
      return '${utc.year}-${two(utc.month)}-${two(utc.day)}';
    }

    return '${format(stats.firstTimestamp)} → ${format(stats.lastTimestamp)}';
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// One auditable number: value, how it is computed, and the records it counts.
class _StatCard extends StatelessWidget {
  const _StatCard({super.key, required this.stat, required this.strings});

  final OverviewStat stat;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    // The chevron points towards the reading direction of the layout.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      button: true,
      label: '${stat.label}, ${stat.value}',
      hint: strings.overviewOpenRecords,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TmCardHover(
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DrillDownPage(drillDown: stat.drillDown),
                ),
              ),
              child: ConstrainedBox(
                // Every card is a primary action: at least 44 logical pixels tall.
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stat.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              stat.drillDown.definition,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          '${stat.value}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF355C7D),
                              ),
                        ),
                      ),
                      Icon(
                        isRtl ? Icons.chevron_left : Icons.chevron_right,
                        color: const Color(0xFF98A2B3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The exact records behind one card, read with the card's own predicate.
class DrillDownPage extends ConsumerWidget {
  const DrillDownPage({super.key, required this.drillDown});

  final OverviewDrillDown drillDown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final repository = ref.watch(searchRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(drillDown.title)),
      body: repository.when(
        loading: () => const Center(child: TmLoader()),
        error: (_, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(strings.overviewFailed),
        ),
        data: (search) => FutureBuilder<List<EventSearchHit>>(
          future: search.filterEvents(
            from: drillDown.from,
            to: drillDown.to,
            eventType: drillDown.eventType,
            conversationId: drillDown.conversationId,
            actorId: drillDown.actorId,
            sourceFileId: drillDown.sourceFileId,
            hasTimestamp: drillDown.hasTimestamp,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: TmLoader());
            }
            final hits = snapshot.data ?? const <EventSearchHit>[];
            if (hits.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(strings.overviewDrillEmpty),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: hits.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${drillDown.definition} · ${hits.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF667085),
                      ),
                    ),
                  );
                }
                final hit = hits[index - 1];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(hit.textContent ?? '(${hit.eventType})'),
                    subtitle: Text(
                      '${strings.overviewSource}: ${hit.sourceLocator}',
                      // Source locators are paths: read them left to right.
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
