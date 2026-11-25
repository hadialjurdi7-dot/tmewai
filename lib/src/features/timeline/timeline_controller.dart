import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'timeline_service.dart';

/// Whether the shell is showing the timeline screen.
class _TimelineOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final timelineOpenProvider = NotifierProvider<_TimelineOpenNotifier, bool>(
  _TimelineOpenNotifier.new,
);

class TimelineState {
  const TimelineState({
    this.grouping = TimelineGrouping.day,
    this.from,
    this.to,
    this.eventType,
    this.timeline,
    this.loading = false,
    this.failed = false,
  });

  final TimelineGrouping grouping;
  final DateTime? from;
  final DateTime? to;
  final String? eventType;
  final Timeline? timeline;
  final bool loading;

  /// True when the last load threw; the message shown is a fixed string.
  final bool failed;

  bool get hasFilters => from != null || to != null || eventType != null;

  TimelineState copyWith({
    TimelineGrouping? grouping,
    DateTime? from,
    DateTime? to,
    String? eventType,
    Timeline? timeline,
    bool? loading,
    bool? failed,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearEventType = false,
  }) => TimelineState(
    grouping: grouping ?? this.grouping,
    from: clearFrom ? null : (from ?? this.from),
    to: clearTo ? null : (to ?? this.to),
    eventType: clearEventType ? null : (eventType ?? this.eventType),
    timeline: timeline ?? this.timeline,
    loading: loading ?? this.loading,
    failed: failed ?? this.failed,
  );
}

class TimelineController extends Notifier<TimelineState> {
  int _generation = 0;

  @override
  TimelineState build() => const TimelineState();

  void setGrouping(TimelineGrouping grouping) {
    if (grouping == state.grouping) return;
    state = state.copyWith(grouping: grouping);
    run();
  }

  void setFrom(DateTime? from) {
    state = from == null
        ? state.copyWith(clearFrom: true)
        : state.copyWith(from: from);
    run();
  }

  void setTo(DateTime? to) {
    state = to == null ? state.copyWith(clearTo: true) : state.copyWith(to: to);
    run();
  }

  void setEventType(String? eventType) {
    state = eventType == null
        ? state.copyWith(clearEventType: true)
        : state.copyWith(eventType: eventType);
    run();
  }

  void clearFilters() {
    state = state.copyWith(clearFrom: true, clearTo: true, clearEventType: true);
    run();
  }

  Future<void> run() async {
    final generation = ++_generation;
    final request = state;
    state = state.copyWith(loading: true, failed: false);
    try {
      final repository = await ref.read(timelineRepositoryProvider.future);
      final timeline = await TimelineService(repository).load(
        grouping: request.grouping,
        from: request.from,
        to: request.to?.add(const Duration(days: 1)),
        eventType: request.eventType,
      );
      if (generation != _generation) return;
      state = state.copyWith(loading: false, timeline: timeline);
    } on Object {
      if (generation != _generation) return;
      state = state.copyWith(loading: false, failed: true);
    }
  }
}

final timelineControllerProvider =
    NotifierProvider<TimelineController, TimelineState>(
      TimelineController.new,
    );
