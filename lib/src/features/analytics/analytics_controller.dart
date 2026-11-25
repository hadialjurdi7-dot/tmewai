import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/workspace_provider.dart';
import '../../data/repositories/overview_repository.dart';

import '../overview/overview_controller.dart';
import '../search/search_controller.dart';
import 'analytics_service.dart';

/// The selected year filter; null is «الكل».
class AnalyticsYearController extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? year) => state = year;
}

final analyticsYearProvider = NotifierProvider<AnalyticsYearController, int?>(
  AnalyticsYearController.new,
);

/// The analytics service over the local aggregate repository.
final analyticsServiceProvider = FutureProvider<AnalyticsService>((ref) async {
  final repository = await ref.watch(overviewRepositoryProvider.future);
  final search = await ref.watch(searchRepositoryProvider.future);
  return AnalyticsService(repository, search);
});

/// The snapshot for the active filter; overridden in tests.
final analyticsSnapshotProvider = FutureProvider<AnalyticsSnapshot>((
  ref,
) async {
  final year = ref.watch(analyticsYearProvider);
  if (ref.watch(workspaceDeletedProvider)) {
    return AnalyticsSnapshot(
      selectedYear: year,
      years: const [],
      totals: const ArchiveTotals(
        messages: 0,
        photos: 0,
        people: 0,
        days: 0,
        events: 0,
      ),
      months: [
        for (var month = 1; month <= 12; month++) (month: month, count: 0),
      ],
      hours: [for (var hour = 0; hour < 24; hour++) (hour: hour, count: 0)],
      types: const [],
      people: const [],
    );
  }
  final service = await ref.watch(analyticsServiceProvider.future);
  return service.load(year: year);
});
