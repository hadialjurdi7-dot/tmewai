import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/workspace_provider.dart';
import '../../data/repositories/overview_repository.dart';

import '../overview/overview_controller.dart';
import '../timeline/timeline_service.dart';
import 'home_service.dart';

/// The home service, built from the shared aggregate repositories.
final homeServiceProvider = FutureProvider<HomeService>((ref) async {
  final overview = await ref.watch(overviewRepositoryProvider.future);
  final timelineRepository = await ref.watch(timelineRepositoryProvider.future);
  return HomeService(overview, timelineRepository);
});

/// The single snapshot the home screen renders. Overridden in tests with a
/// fake snapshot so the widget is exercised without a database.
final homeSnapshotProvider = FutureProvider<HomeSnapshot>((ref) async {
  if (ref.watch(workspaceDeletedProvider)) {
    return const HomeSnapshot(
      totals: ArchiveTotals(
        messages: 0,
        photos: 0,
        people: 0,
        days: 0,
        events: 0,
      ),
      topPeople: [],
      latest: [],
    );
  }
  final service = await ref.watch(homeServiceProvider.future);
  return service.load();
});
