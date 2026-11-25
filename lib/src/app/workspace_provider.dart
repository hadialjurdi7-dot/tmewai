import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/workspace/workspace_service.dart';

/// The workspace service the app uses.
///
/// UI is not wired to it yet: this only makes the local storage root available
/// to providers and screens that come next.
final workspaceServiceProvider = Provider<WorkspaceService>((ref) {
  final service = WorkspaceService();
  ref.onDispose(service.close);
  return service;
});

/// Opens the local workspace and exposes the open service.
///
/// Reading it creates `<application support>/workspace/` and opens its SQLite
/// database; disposing the provider closes it. Opening is local only: nothing
/// here reaches the network.
final workspaceProvider = FutureProvider<WorkspaceService>((ref) async {
  final service = ref.watch(workspaceServiceProvider);
  // Register teardown before awaiting: a provider disposed mid-open must
  // still close the handle the open may publish. WorkspaceService serializes
  // the two operations, so this cannot leak a database.
  ref.onDispose(service.close);
  await service.open();
  return service;
});

/// True after a successful local workspace deletion. Feature snapshots watch
/// this before opening repositories so mounted screens cannot read the closed
/// database or continue showing cached archive content.
class WorkspaceDeletedController extends Notifier<bool> {
  @override
  bool build() => false;

  void markDeleted() => state = true;
}

final workspaceDeletedProvider =
    NotifierProvider<WorkspaceDeletedController, bool>(
      WorkspaceDeletedController.new,
    );
