import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/workspace_provider.dart';
import '../../data/repositories/overview_repository.dart';
import 'overview_service.dart';

final overviewRepositoryProvider = FutureProvider<OverviewRepository>((
  ref,
) async {
  final workspace = await ref.watch(workspaceProvider.future);
  return OverviewRepository(workspace.database);
});

final overviewStatsProvider = FutureProvider<OverviewStats>((ref) async {
  final repository = await ref.watch(overviewRepositoryProvider.future);
  return OverviewService(repository).load();
});

class _OverviewOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final overviewOpenProvider = NotifierProvider<_OverviewOpenNotifier, bool>(
  _OverviewOpenNotifier.new,
);
