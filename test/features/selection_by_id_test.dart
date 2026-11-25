import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/attachment_repository.dart';
import 'package:personal_data_agent/src/data/repositories/conversation_repository.dart';
import 'package:personal_data_agent/src/data/repositories/event_search_repository.dart';
import 'package:personal_data_agent/src/data/repositories/overview_repository.dart';
import 'package:personal_data_agent/src/data/repositories/person_repository.dart';
import 'package:personal_data_agent/src/domain/models/event_record.dart';
import 'package:personal_data_agent/src/domain/models/import_record.dart';
import 'package:personal_data_agent/src/domain/models/source_file.dart';
import 'package:personal_data_agent/src/features/analytics/analytics_service.dart';
import 'package:personal_data_agent/src/features/messages/messages_service.dart';
import 'package:personal_data_agent/src/features/people/person_service.dart';

/// Regression tests for the selection defects the review found: a requested id
/// must be read by id, never replaced by whichever row happens to be first.
void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase database;
  late int importId;
  late int sourceFileId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    importId = await database.into(database.imports).insert(
      ImportsCompanion.insert(
        platform: 'facebook',
        format: 'json',
        sourceFingerprint: 'fingerprint-1',
        startedAt: DateTime.utc(2026, 1, 1),
        importerVersion: 'test',
        status: ImportStatus.completed,
      ),
    );
    sourceFileId = await database.into(database.sourceFiles).insert(
      SourceFilesCompanion.insert(
        importId: importId,
        relativePath: 'messages/inbox/thread/message_1.json',
        parseStatus: ParseStatus.parsed,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> person(String name) => database
      .into(database.people)
      .insert(
        PeopleCompanion.insert(platform: 'facebook', displayName: name),
      );

  Future<int> conversation(String title) => database
      .into(database.conversations)
      .insert(ConversationsCompanion.insert(importId: importId, title: Value(title)));

  var locator = 0;

  Future<void> event({
    required DateTime? at,
    required String type,
    int? actorId,
    int? conversationId,
    String text = 'text',
  }) => database
      .into(database.events)
      .insert(
        EventsCompanion.insert(
          importId: importId,
          sourceFileId: sourceFileId,
          sourceLocator: 'locator-${locator++}',
          platform: 'facebook',
          eventType: type,
          timestampNormalized: Value(at),
          timezoneStatus: TimezoneStatus.utc,
          actorId: Value(actorId),
          conversationId: Value(conversationId),
          textContent: Value(text),
        ),
      );

  test('a year that holds only posts is still offered as a filter', () async {
    final who = await person('سامر');
    await event(at: DateTime.utc(2019, 5, 1), type: 'message', actorId: who);
    // 2021 carries a post and no message: the old chips hid it.
    await event(at: DateTime.utc(2021, 7, 1), type: 'post', actorId: who);

    final snapshot = await AnalyticsService(
      OverviewRepository(database),
      EventSearchRepository(database),
    ).load();

    expect(snapshot.years, containsAll(<int>[2019, 2021]));
  });

  test('a requested conversation outside the capped list opens itself', () async {
    // 120 conversations: the requested one is the oldest, past the 100 cap.
    final oldest = await conversation('القديمة');
    await event(
      at: DateTime.utc(2011, 1, 1),
      type: 'message',
      conversationId: oldest,
      text: 'القديمة',
    );
    for (var i = 0; i < 120; i++) {
      final id = await conversation('محادثة $i');
      await event(
        at: DateTime.utc(2020, 1, 1).add(Duration(days: i)),
        type: 'message',
        conversationId: id,
        text: 'محادثة $i',
      );
    }

    final snapshot = await MessagesService(
      ConversationRepository(database),
    ).load(selectedId: oldest);

    expect(snapshot.selected?.id, oldest);
    expect(snapshot.selected?.title, 'القديمة');
  });

  test('a requested person outside the ranked list is shown, not replaced', () async {
    // Nine people so the requested one falls outside the eight-row ranking.
    final ids = <int>[];
    for (var i = 0; i < 9; i++) {
      final id = await person('شخص $i');
      ids.add(id);
      for (var m = 0; m <= i; m++) {
        await event(
          at: DateTime.utc(2020, 1, 1).add(Duration(days: m)),
          type: 'message',
          actorId: id,
          text: 'رسالة $m',
        );
      }
    }
    final requested = ids.last; // fewest messages: outside the top eight

    final snapshot = await PersonService(
      PersonRepository(database),
      OverviewRepository(database),
      AttachmentRepository(database),
    ).load(personId: requested);

    expect(snapshot.selected?.id, requested);
    expect(snapshot.selected?.name, 'شخص 8');
  });
}
