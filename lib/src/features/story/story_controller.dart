import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../media/media_controller.dart';
import '../overview/overview_controller.dart';
import '../search/search_controller.dart';
import 'story_service.dart';

/// The story service over the local archive.
final storyServiceProvider = FutureProvider<StoryService>((ref) async {
  final overview = await ref.watch(overviewRepositoryProvider.future);
  final search = await ref.watch(searchRepositoryProvider.future);
  final attachments = await ref.watch(attachmentRepositoryProvider.future);
  return StoryService(overview, search, attachments);
});

/// The snapshot the story screen renders; overridden in tests.
final storySnapshotProvider = FutureProvider<StorySnapshot>((ref) async {
  final service = await ref.watch(storyServiceProvider.future);
  return service.load();
});
