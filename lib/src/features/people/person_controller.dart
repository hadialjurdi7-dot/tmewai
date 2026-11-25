import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/workspace_provider.dart';
import '../../data/repositories/person_repository.dart';
import '../media/media_controller.dart';
import '../overview/overview_controller.dart';
import 'person_service.dart';

/// The per-person reads over the local archive.
final personRepositoryProvider = FutureProvider<PersonRepository>((ref) async {
  final workspace = await ref.watch(workspaceProvider.future);
  return PersonRepository(workspace.database);
});

/// The person whose profile is open; null means «الأول بالقائمة».
class PersonSelectionController extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int personId) => state = personId;

  void reset() => state = null;
}

final personSelectionProvider =
    NotifierProvider<PersonSelectionController, int?>(
      PersonSelectionController.new,
    );

/// One older page of a person's messages, keyed by person and loaded rows.
///
/// A family key keeps every person's paging independent: switching the open
/// profile cannot append one person's rows to another person's list.
final personMessagePageProvider =
    FutureProvider.family<PersonMessagePage, ({int personId, int offset})>((
      ref,
      request,
    ) async {
      final repository = await ref.watch(personRepositoryProvider.future);
      return PersonService.page(
        repository,
        request.personId,
        offset: request.offset,
      );
    });

/// The people list and the open profile; overridden in tests.
final personSnapshotProvider = FutureProvider<PersonSnapshot>((ref) async {
  final persons = await ref.watch(personRepositoryProvider.future);
  final overview = await ref.watch(overviewRepositoryProvider.future);
  final attachments = await ref.watch(attachmentRepositoryProvider.future);
  final selected = ref.watch(personSelectionProvider);
  return PersonService(persons, overview, attachments).load(personId: selected);
});
