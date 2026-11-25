import '../../data/repositories/overview_repository.dart';

/// The exact predicate behind one overview number.
///
/// A card and the list it opens use this same predicate, so the records shown
/// are exactly the records counted.
class OverviewDrillDown {
  const OverviewDrillDown({
    required this.title,
    required this.definition,
    this.from,
    this.to,
    this.eventType,
    this.conversationId,
    this.actorId,
    this.sourceFileId,
    this.hasTimestamp,
  });

  final String title;

  /// How the number is computed, shown on the card.
  final String definition;

  final DateTime? from;
  final DateTime? to;
  final String? eventType;
  final int? conversationId;
  final int? actorId;
  final int? sourceFileId;
  final bool? hasTimestamp;
}

class OverviewStat {
  const OverviewStat({
    required this.label,
    required this.value,
    required this.drillDown,
  });

  final String label;
  final int value;
  final OverviewDrillDown drillDown;
}

class OverviewDayBucket {
  const OverviewDayBucket({
    required this.key,
    required this.count,
    required this.drillDown,
  });

  final String key;
  final int count;
  final OverviewDrillDown drillDown;
}

class OverviewStats {
  const OverviewStats({
    required this.totalEvents,
    required this.datedCount,
    required this.unknownCount,
    required this.firstTimestamp,
    required this.lastTimestamp,
    required this.dayBuckets,
    required this.eventTypes,
    required this.conversations,
    required this.people,
    required this.sourceFiles,
    required this.activityCard,
    required this.unknownCard,
  });

  final int totalEvents;
  final int datedCount;
  final int unknownCount;
  final DateTime? firstTimestamp;
  final DateTime? lastTimestamp;

  final List<OverviewDayBucket> dayBuckets;
  final List<OverviewStat> eventTypes;
  final List<OverviewStat> conversations;
  final List<OverviewStat> people;
  final List<OverviewStat> sourceFiles;
  final OverviewStat activityCard;
  final OverviewStat unknownCard;
}

/// Builds the dashboard values from aggregate repository reads.
///
/// No SQL here: every number comes from [OverviewRepository], and each number
/// carries the predicate that reproduces its records.
class OverviewService {
  const OverviewService(this.repository);

  final OverviewRepository repository;

  Future<OverviewStats> load({int topLimit = 5, int maxDays = 30}) async {
    final period = await repository.activityPeriod();
    final days = await repository.countsByDay();
    final types = await repository.countsByEventType();
    final conversations = await repository.topConversations(limit: topLimit);
    final people = await repository.topPeople(limit: topLimit);
    final files = await repository.countsBySourceFile(limit: topLimit);

    final dayBuckets = [
      for (final day in days)
        OverviewDayBucket(
          key: day.key,
          count: day.count,
          drillDown: OverviewDrillDown(
            title: day.key,
            definition:
                'Events whose normalized timestamp falls on ${day.key} (UTC).',
            from: DateTime.parse('${day.key}T00:00:00Z'),
            to: DateTime.parse('${day.key}T23:59:59Z'),
            hasTimestamp: true,
          ),
        ),
    ];
    final visibleDays = dayBuckets.length <= maxDays
        ? dayBuckets
        : dayBuckets.sublist(dayBuckets.length - maxDays);

    final activityCard = OverviewStat(
      label: 'Events with a parsed timestamp',
      value: period.dated,
      drillDown: OverviewDrillDown(
        title: 'Events with a parsed timestamp',
        definition:
            'Events where the export timestamp could be normalized to UTC.',
        hasTimestamp: true,
      ),
    );

    final unknownCard = OverviewStat(
      label: 'Events with an unknown date',
      value: period.unknown,
      drillDown: const OverviewDrillDown(
        title: 'Events with an unknown date',
        definition:
            'Events without a parsed timestamp. They are never placed on a '
            'date axis.',
        hasTimestamp: false,
      ),
    );

    return OverviewStats(
      totalEvents: period.dated + period.unknown,
      datedCount: period.dated,
      unknownCount: period.unknown,
      firstTimestamp: period.first?.toUtc(),
      lastTimestamp: period.last?.toUtc(),
      dayBuckets: List.unmodifiable(visibleDays),
      eventTypes: List.unmodifiable([
        for (final type in types)
          OverviewStat(
            label: type.eventType,
            value: type.count,
            drillDown: OverviewDrillDown(
              title: type.eventType,
              definition:
                  'Events with event_type = ${type.eventType}.',
              eventType: type.eventType,
            ),
          ),
      ]),
      conversations: List.unmodifiable([
        for (final conversation in conversations)
          OverviewStat(
            label:
                conversation.title ??
                conversation.sourceId ??
                'conversation #${conversation.id}',
            value: conversation.count,
            drillDown: OverviewDrillDown(
              title:
                  conversation.title ??
                  conversation.sourceId ??
                  'conversation #${conversation.id}',
              definition: 'Message events in this conversation.',
              conversationId: conversation.id,
              // 'message' means every message kind in the search filters, so
              // the drill-down reproduces this card's count exactly.
              eventType: 'message',
            ),
          ),
      ]),
      people: List.unmodifiable([
        for (final person in people)
          OverviewStat(
            label: person.name,
            value: person.count,
            drillDown: OverviewDrillDown(
              title: person.name,
              definition: 'Message events where this person is the actor.',
              actorId: person.id,
              eventType: 'message',
            ),
          ),
      ]),
      sourceFiles: List.unmodifiable([
        for (final file in files)
          OverviewStat(
            label: file.path,
            value: file.count,
            drillDown: OverviewDrillDown(
              title: file.path,
              definition: 'Events stored from this archive file.',
              sourceFileId: file.id,
            ),
          ),
      ]),
      activityCard: activityCard,
      unknownCard: unknownCard,
    );
  }
}
