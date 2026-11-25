import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/conversation_repository.dart';
import 'package:personal_data_agent/src/domain/models/event_record.dart';
import 'package:personal_data_agent/src/domain/models/import_record.dart';
import 'package:personal_data_agent/src/domain/models/source_file.dart';
import 'package:personal_data_agent/src/features/messages/messages_controller.dart';
import 'package:personal_data_agent/src/features/messages/messages_screen.dart';
import 'package:personal_data_agent/src/features/messages/messages_service.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase database;
  late ConversationRepository repository;
  late int importId;
  late int sourceFileId;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = ConversationRepository(database);
    importId = await database
        .into(database.imports)
        .insert(
          ImportsCompanion.insert(
            platform: 'facebook',
            format: 'json',
            sourceFingerprint: 'sha256:paging',
            startedAt: DateTime.utc(2026, 1, 1),
            importerVersion: '0.1.0',
            status: ImportStatus.completed,
          ),
        );
    sourceFileId = await database
        .into(database.sourceFiles)
        .insert(
          SourceFilesCompanion.insert(
            importId: importId,
            relativePath: 'messages/inbox/leila/message_1.json',
            parseStatus: ParseStatus.parsed,
          ),
        );
    final personId = await database
        .into(database.people)
        .insert(
          PeopleCompanion.insert(
            platform: 'facebook',
            displayName: 'ليلى خالد',
          ),
        );
    final conversationId = await database
        .into(database.conversations)
        .insert(
          ConversationsCompanion.insert(
            importId: importId,
            sourceConversationId: const Value('leila'),
            title: const Value('ليلى خالد'),
          ),
        );
    await database.batch((batch) {
      for (var index = 0; index < 2000; index++) {
        batch.insert(
          database.events,
          EventsCompanion.insert(
            importId: importId,
            sourceFileId: sourceFileId,
            sourceLocator: 'paged/$index',
            platform: 'facebook',
            eventType: 'message',
            timezoneStatus: TimezoneStatus.utc,
            timestampNormalized: Value(
              DateTime.utc(2020, 1, 1).add(Duration(minutes: index)),
            ),
            conversationId: Value(conversationId),
            actorId: Value(personId),
            textContent: Value(
              index == 0 ? 'needle at the far end' : 'paged-message-$index',
            ),
          ),
        );
      }
    });
  });

  tearDown(() => database.close());

  testWidgets('a 2,000-message thread opens on page one, appends, and searches SQL', (
    tester,
  ) async {
    final service = MessagesService(repository);
    final thread = (await service.load()).selected!;
    final firstPageIds = thread.days
        .expand((day) => day.bubbles)
        .map((bubble) => bubble.id)
        .toSet();
    final farEnd = (await service.search(thread, 'needle')).single;

    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationRepositoryProvider.overrideWith((ref) async => repository),
          messagesSnapshotProvider.overrideWith((ref) async {
            final selected = ref.watch(messagesSelectionProvider);
            return MessagesService(repository).load(selectedId: selected);
          }),
        ],
        child: const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: MessagesScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(thread.messageCount, 2000);
    expect(firstPageIds.length, 50);
    expect(find.text('Loaded 50 of 2,000'), findsOneWidget);

    final builtInitially = find.byType(MessageBubbleTile).evaluate().toList();
    expect(builtInitially, isNotEmpty);
    expect(builtInitially.length, lessThan(50));
    final builtIds = {
      for (final element in builtInitially)
        int.parse(
          ((element.widget.key! as ValueKey<String>).value).replaceFirst(
            'messages-bubble-',
            '',
          ),
        ),
    };
    expect(builtIds.difference(firstPageIds), isEmpty);
    expect(
      find.byKey(ValueKey('messages-bubble-${farEnd.id}')),
      findsNothing,
    );

    // In a reverse list, dragging down walks towards the oldest loaded row,
    // which is where the next page is requested.
    final list = find.byKey(const Key('messages-thread'));
    for (
      var attempt = 0;
      attempt < 6 && find.text('Loaded 50 of 2,000').evaluate().isNotEmpty;
      attempt++
    ) {
      await tester.drag(list, const Offset(0, 900));
      await tester.pumpAndSettle();
    }

    expect(find.text('Loaded 100 of 2,000'), findsOneWidget);
    final appendedKeys = find
        .byType(MessageBubbleTile)
        .evaluate()
        .map((element) => element.widget.key)
        .toList();
    expect(appendedKeys.toSet().length, appendedKeys.length);

    await tester.enterText(
      find.byKey(const Key('messages-thread-search')),
      'needle',
    );
    await tester.pumpAndSettle();

    expect(find.text('Search results: 1'), findsOneWidget);
    expect(
      find.byKey(ValueKey('messages-bubble-${farEnd.id}')),
      findsOneWidget,
    );
    expect(find.text(farEnd.text!), findsOneWidget);
    // Search is a read, not a reload: the loaded page is untouched.
    expect(find.text('Loaded 100 of 2,000'), findsOneWidget);
  });
}
