import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/workspace_provider.dart';
import '../../data/repositories/conversation_repository.dart';
import 'messages_service.dart';

/// The conversation reads over the local archive.
final conversationRepositoryProvider = FutureProvider<ConversationRepository>((
  ref,
) async {
  final workspace = await ref.watch(workspaceProvider.future);
  return ConversationRepository(workspace.database);
});

/// The conversation the thread panel is open on; null means «الأحدث».
class MessagesSelectionController extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int conversationId) => state = conversationId;

  void reset() => state = null;
}

final messagesSelectionProvider =
    NotifierProvider<MessagesSelectionController, int?>(
      MessagesSelectionController.new,
    );

/// The screen snapshot for the active selection; overridden in tests.
final messagesSnapshotProvider = FutureProvider<MessagesSnapshot>((ref) async {
  final selected = ref.watch(messagesSelectionProvider);
  if (ref.watch(workspaceDeletedProvider)) {
    return const MessagesSnapshot(
      conversations: [],
      totalConversations: 0,
      selected: null,
    );
  }
  final repository = await ref.watch(conversationRepositoryProvider.future);
  return MessagesService(repository).load(selectedId: selected);
});
