import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/conversation_repository.dart';
import 'package:personal_data_agent/src/domain/models/event_record.dart';
import 'package:personal_data_agent/src/features/messages/messages_service.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

Map<String, Object?> _message(
  String sender,
  DateTime at,
  String? content, {
  List<Map<String, Object?>>? photos,
}) => {
  'sender_name': sender,
  'timestamp_ms': at.millisecondsSinceEpoch,
  'content': ?content,
  'photos': ?photos,
};

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late Directory tempDirectory;
  late AppDatabase database;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('pda-messages-');
    database = AppDatabase(NativeDatabase.memory());
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'messages/inbox/leila/message_1.json',
          jsonEncode({
            'title': 'ليلى خالد',
            'messages': [
              _message('ليلى خالد', DateTime.utc(2019, 3, 12, 10, 14), 'صباح الخير'),
              _message('سامر', DateTime.utc(2019, 3, 12, 10, 18), 'صباح الورد'),
              _message('ليلى خالد', DateTime.utc(2019, 3, 12, 10, 22), null, photos: [
                {'uri': 'messages/inbox/leila/photos/1.jpg'},
              ]),
              _message('ليلى خالد', DateTime.utc(2021, 8, 24, 9, 5), 'ذكرى السنة'),
            ],
          }),
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'messages/inbox/omar/message_1.json',
          jsonEncode({
            'title': 'عمر بيطار',
            'messages': [
              _message('عمر بيطار', DateTime.utc(2020, 1, 2, 8), 'كل سنة'),
              _message('عمر بيطار', DateTime.utc(2020, 1, 2, 9), 'وأنت سالم'),
            ],
          }),
        ),
      )
      ..addFile(
        ArchiveFile('messages/inbox/leila/photos/1.jpg', 4, [1, 2, 3, 4]),
      );
    final file = File('${tempDirectory.path}/messages.zip');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    await ImportCoordinator(database: database).importArchive(file);
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('the list is ordered by newest activity and carries its last text', () async {
    final snapshot = await MessagesService(
      ConversationRepository(database),
    ).load();

    expect(snapshot.totalConversations, 2);
    expect(snapshot.conversations.length, 2);
    expect(snapshot.conversations.first.title, 'ليلى خالد');
    expect(snapshot.conversations.first.messageCount, 4);
    expect(snapshot.conversations.first.snippet, 'ذكرى السنة');
    expect(snapshot.conversations.first.lastAt, DateTime.utc(2021, 8, 24, 9, 5));
    expect(snapshot.conversations.last.title, 'عمر بيطار');
  });

  test('the thread groups by UTC day, newest first, and keeps media rows', () async {
    final snapshot = await MessagesService(
      ConversationRepository(database),
    ).load();

    final thread = snapshot.selected!;
    expect(thread.title, 'ليلى خالد');
    expect(thread.firstAt, DateTime.utc(2019, 3, 12, 10, 14));
    expect(thread.lastAt, DateTime.utc(2021, 8, 24, 9, 5));
    expect(thread.platform, 'facebook');
    expect(thread.loadedCount, 4);
    expect(thread.hasMore, isFalse);
    // The paged read is newest first: 2021 comes before 2019.
    expect(thread.days.length, 2);
    expect(thread.days.first.date, DateTime.utc(2021, 8, 24));
    expect(thread.days.first.bubbles.single.text, 'ذكرى السنة');
    expect(thread.days.last.date, DateTime.utc(2019, 3, 12));
    expect(thread.days.last.bubbles.length, 3);
    expect(thread.days.last.bubbles.first.attachmentCount, 1);
    expect(thread.days.last.bubbles.last.text, 'صباح الخير');

    final media = thread.days.last.bubbles.first;
    expect(media.attachmentMediaType, 'image');
    // ليلى wrote three of the four messages, so her side is the leading one.
    expect(media.fromPrimarySender, isTrue);
    expect(thread.days.last.bubbles[1].fromPrimarySender, isFalse);
    expect(thread.days.last.bubbles[1].senderName, 'سامر');
    expect(thread.senderCount, 2);
  });

  test('a long thread pages newest first without overlap, and SQL finds the far end', () async {
    final repository = ConversationRepository(database);
    final list = await repository.conversations();
    final leilaId = list.firstWhere((row) => row.title == 'ليلى خالد').id;
    final importRow = await (database.select(
      database.imports,
    )..limit(1)).getSingle();
    final sourceFile = await (database.select(
      database.sourceFiles,
    )..limit(1)).getSingle();
    final actor = await (database.select(
      database.people,
    )..where((person) => person.displayName.equals('ليلى خالد'))).getSingle();

    await database.batch((batch) {
      for (var index = 0; index < 2000; index++) {
        batch.insert(
          database.events,
          EventsCompanion.insert(
            importId: importRow.id,
            sourceFileId: sourceFile.id,
            sourceLocator: 'paged-thread/$index',
            platform: 'facebook',
            eventType: 'message',
            timezoneStatus: TimezoneStatus.utc,
            conversationId: Value(leilaId),
            actorId: Value(actor.id),
            timestampNormalized: Value(
              DateTime.utc(2022, 1, 1).add(Duration(minutes: index)),
            ),
            textContent: Value(
              index == 0 ? 'needle at far end' : 'paged-message-$index',
            ),
          ),
        );
      }
    });

    final service = MessagesService(repository);
    final thread = (await service.load(selectedId: leilaId)).selected!;

    expect(thread.messageCount, 2004);
    expect(thread.loadedCount, 50);
    expect(thread.hasMore, isTrue);
    expect(thread.days.first.bubbles.first.text, 'paged-message-1999');

    final firstIds = thread.days
        .expand((day) => day.bubbles)
        .map((bubble) => bubble.id)
        .toSet();
    final second = await service.loadPage(thread, offset: thread.loadedCount);
    final secondIds = second.bubbles.map((bubble) => bubble.id).toSet();

    expect(thread.loadedCount + second.bubbles.length, 100);
    expect(firstIds.intersection(secondIds), isEmpty);
    expect(second.hasMore, isTrue);

    // Walk the rest of the conversation: every row appears exactly once and
    // the final page reports that nothing is left.
    final allIds = {...firstIds, ...secondIds};
    var offset = 100;
    var hasMore = second.hasMore;
    while (hasMore) {
      final page = await service.loadPage(thread, offset: offset);
      expect(page.bubbles, isNotEmpty);
      final pageIds = page.bubbles.map((bubble) => bubble.id).toSet();
      expect(pageIds.length, page.bubbles.length);
      expect(allIds.intersection(pageIds), isEmpty);
      allIds.addAll(pageIds);
      offset += page.bubbles.length;
      hasMore = page.hasMore;
    }
    expect(allIds.length, 2004);

    final hits = await service.search(thread, 'needle');
    expect(hits.single.text, 'needle at far end');
    expect(firstIds.contains(hits.single.id), isFalse);
    expect(allIds.contains(hits.single.id), isTrue);
  });

  test('an explicit selection opens that conversation', () async {
    final repository = ConversationRepository(database);
    final list = await repository.conversations();
    final omar = list.firstWhere((row) => row.title == 'عمر بيطار');

    final snapshot = await MessagesService(repository).load(selectedId: omar.id);

    expect(snapshot.selected!.title, 'عمر بيطار');
    expect(snapshot.selected!.days.length, 1);
    expect(snapshot.selected!.senderCount, 1);
    expect(snapshot.selected!.days.single.bubbles.length, 2);
  });
}
