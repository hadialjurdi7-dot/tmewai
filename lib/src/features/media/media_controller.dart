import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/workspace_provider.dart';
import '../../data/repositories/attachment_repository.dart';
import 'media_service.dart';

/// The attachment reads over the local archive.
final attachmentRepositoryProvider = FutureProvider<AttachmentRepository>((
  ref,
) async {
  final workspace = await ref.watch(workspaceProvider.future);
  return AttachmentRepository(workspace.database);
});

/// The selected year of the gallery; null is «كل السنين».
class MediaYearController extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? year) => state = year;
}

final mediaYearProvider = NotifierProvider<MediaYearController, int?>(
  MediaYearController.new,
);

/// The gallery snapshot for the active filter; overridden in tests.
final mediaSnapshotProvider = FutureProvider<MediaSnapshot>((ref) async {
  final year = ref.watch(mediaYearProvider);
  if (ref.watch(workspaceDeletedProvider)) {
    return MediaSnapshot(
      total: 0,
      years: const [],
      selectedYear: year,
      items: const [],
      people: const [],
      matched: 0,
      limit: MediaService.gridLimit,
    );
  }
  final repository = await ref.watch(attachmentRepositoryProvider.future);
  return MediaService(repository).load(year: year);
});
