import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/workspace/workspace_service.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

/// A real export carries shapes that break a naive write: a group-thread folder
/// name past the conversation-id ceiling, a display name past the people
/// ceiling, and a record whose body is past the events ceiling. Each must cost
/// its own row, never the whole import.
void main() {
  late Directory root;
  late WorkspaceService workspace;
  late ImportCoordinator coordinator;

  setUpAll(() {
    // Each test opens its own workspace database on purpose.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('write-limits-');
    workspace = WorkspaceService(
      rootDirectory: Directory('${root.path}/workspace'),
    );
    await workspace.open();
    coordinator = ImportCoordinator(database: workspace.database);
  });

  tearDown(() async {
    await coordinator.dispose();
    await workspace.close();
    await root.delete(recursive: true);
  });

  Future<Directory> export(Map<String, String> files) async {
    final dir = Directory('${root.path}/export');
    files.forEach((name, text) {
      final file = File('${dir.path}/$name');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(text);
    });
    return dir;
  }

  test('a thread folder past the conversation ceiling still imports', () async {
    // 100 chars of name plus the folder prefix lands past the 128-char
    // conversation-id ceiling while staying a legal file name.
    final longName = '${'a' * 100}_100012345678901';
    final dir = await export({
      'your_activity/messages/inbox/$longName/message_1.json': jsonEncode({
        'participants': [
          {'name': 'Group'},
        ],
        'messages': [
          {
            'sender_name': 'Group',
            'timestamp_ms': 1600000000000,
            'content': 'hi',
          },
        ],
        'title': 'Group',
      }),
      'your_activity/messages/inbox/short/message_1.json': jsonEncode({
        'participants': [
          {'name': 'Sara'},
        ],
        'messages': [
          {
            'sender_name': 'Sara',
            'timestamp_ms': 1600000001000,
            'content': 'yo',
          },
        ],
        'title': 'Sara',
      }),
    });

    final result = await coordinator.importSource(dir.path);

    // Both threads land: the key is clipped to the column, not rejected.
    expect(result, isA<ImportOutcome>());
    final outcome = result as ImportOutcome;
    expect(outcome.events, 2);
    expect(outcome.conversations, 2);
    expect(outcome.skippedRecords, 0);
  });

  test(
    'a display name past the people ceiling does not abort the import',
    () async {
      final dir = await export({
        'your_activity/messages/inbox/a/message_1.json': jsonEncode({
          'participants': [
            {'name': 'A'},
          ],
          'messages': [
            {
              'sender_name': 'ن' * 900,
              'timestamp_ms': 1600000000000,
              'content': 'hello',
            },
          ],
          'title': 'A',
        }),
      });

      final result = await coordinator.importSource(dir.path);

      expect(result, isA<ImportOutcome>());
      expect((result as ImportOutcome).events, 1);
    },
  );

  test(
    'a body past the events ceiling is skipped, the rest is written',
    () async {
      final dir = await export({
        'your_activity/posts/your_posts_1.json': jsonEncode([
          {
            'timestamp': 1600000000,
            'data': [
              {'post': 'x' * 120000},
            ],
          },
          for (var i = 0; i < 20; i++)
            {
              'timestamp': 1600000000 + i,
              'data': [
                {'post': 'post $i'},
              ],
            },
        ]),
      });

      final result = await coordinator.importSource(dir.path);

      expect(result, isA<ImportOutcome>());
      expect((result as ImportOutcome).events, 20);
    },
  );

  test(
    'an empty sender is skipped as a person and the message still lands',
    () async {
      final dir = await export({
        'your_activity/messages/inbox/empty/message_1.json': jsonEncode({
          'participants': <Object>[],
          'messages': [
            {
              'sender_name': '',
              'timestamp_ms': 1600000000000,
              'content': 'hello',
            },
          ],
          'title': 'Empty',
        }),
      });

      final outcome = await coordinator.importSource(dir.path) as ImportOutcome;

      expect(outcome.events, 1);
      expect(outcome.people, 0);
      expect(outcome.skippedRecords, 1);
      expect(outcome.warnings, hasLength(1));
      expect(outcome.warnings.single, contains('field=people.display_name'));
      expect(outcome.warnings.single, contains('bound=minimum'));

      final people = await workspace.database
          .select(workspace.database.people)
          .get();
      expect(people, isEmpty);
      final events = await workspace.database
          .select(workspace.database.events)
          .get();
      expect(events.single.actorId, isNull);
      expect(events.single.textContent, 'hello');
    },
  );

  test(
    'senders that differ only in surrounding whitespace stay distinct',
    () async {
      final dir = await export({
        'your_activity/messages/inbox/alex/message_1.json': jsonEncode({
          'participants': [
            {'name': 'Alex'},
            {'name': ' Alex '},
          ],
          'messages': [
            {
              'sender_name': 'Alex',
              'timestamp_ms': 1600000000000,
              'content': 'from Alex',
            },
            {
              'sender_name': ' Alex ',
              'timestamp_ms': 1600000001000,
              'content': 'from spaced Alex',
            },
          ],
          'title': 'Alex',
        }),
      });

      final outcome = await coordinator.importSource(dir.path) as ImportOutcome;

      expect(outcome.events, 2);
      expect(outcome.people, 2);
      final people = await workspace.database
          .select(workspace.database.people)
          .get();
      expect(
        people.map((person) => person.displayName).toSet(),
        {'Alex', ' Alex '},
      );
      final events = await workspace.database
          .select(workspace.database.events)
          .get();
      expect(events.map((event) => event.actorId).toSet(), hasLength(2));
    },
  );

  test('a person already stored verbatim is reused, not duplicated', () async {
    // An earlier import may have stored the exported spelling with its
    // surrounding whitespace. The lookup must use that exact key.
    final existingId = await workspace.database
        .into(workspace.database.people)
        .insert(
          PeopleCompanion.insert(platform: 'facebook', displayName: ' Sara '),
        );
    final dir = await export({
      'your_activity/messages/inbox/sara/message_1.json': jsonEncode({
        'participants': [
          {'name': ' Sara '},
        ],
        'messages': [
          {
            'sender_name': ' Sara ',
            'timestamp_ms': 1600000000000,
            'content': 'hello',
          },
        ],
        'title': 'Sara',
      }),
    });

    final outcome = await coordinator.importSource(dir.path) as ImportOutcome;

    expect(outcome.people, 1);
    final people = await workspace.database
        .select(workspace.database.people)
        .get();
    expect(people, hasLength(1));
    expect(people.single.id, existingId);
    expect(people.single.displayName, ' Sara ');
    final event = await workspace.database
        .select(workspace.database.events)
        .getSingle();
    expect(event.actorId, existingId);
  });

  test(
    'a blank name is skipped and an over-long name is clipped, not fatal',
    () async {
      final longName = 'n' * 4000;
      final dir = await export({
        'your_activity/messages/inbox/names/message_1.json': jsonEncode({
          'participants': <Object>[],
          'messages': [
            {
              'sender_name': '   ',
              'timestamp_ms': 1600000000000,
              'content': 'blank sender',
            },
            {
              'sender_name': longName,
              'timestamp_ms': 1600000001000,
              'content': 'long sender',
            },
          ],
          'title': '   ',
        }),
      });

      final outcome = await coordinator.importSource(dir.path) as ImportOutcome;

      expect(outcome.events, 2);
      expect(outcome.people, 1);
      expect(outcome.conversations, 1);
      expect(outcome.skippedRecords, 1);
      expect(outcome.warnings, hasLength(1));
      expect(outcome.warnings.single, contains('field=people.display_name'));
      expect(outcome.warnings.single, contains('bound=minimum'));

      final people = await workspace.database
          .select(workspace.database.people)
          .get();
      expect(people.single.displayName, hasLength(512));
      expect(people.single.displayName.trim(), isNotEmpty);

      final conversations = await workspace.database
          .select(workspace.database.conversations)
          .get();
      expect(conversations.single.title, isNull);

      final events = await workspace.database
          .select(workspace.database.events)
          .get();
      expect(events, hasLength(2));
      expect(events.where((event) => event.actorId == null), hasLength(1));
    },
  );

  test('an empty conversation title becomes null', () async {
    final dir = await export({
      'your_activity/messages/inbox/title/message_1.json': jsonEncode({
        'participants': [
          {'name': 'Sara'},
        ],
        'messages': [
          {
            'sender_name': 'Sara',
            'timestamp_ms': 1600000000000,
            'content': 'hi',
          },
        ],
        'title': '',
      }),
    });

    final outcome = await coordinator.importSource(dir.path) as ImportOutcome;

    expect(outcome.events, 1);
    expect(outcome.skippedRecords, 0);
    final conversations = await workspace.database
        .select(workspace.database.conversations)
        .get();
    expect(conversations.single.title, isNull);
  });

  test(
    'one oversized body among 500 skips one row and names field and bound',
    () async {
      const path = 'your_activity/messages/inbox/bulk/message_1.json';
      const leakedBody = 'LEAK-LEAK-LEAK';
      final dir = await export({
        path: jsonEncode({
          'participants': [
            {'name': 'Bulk'},
          ],
          'messages': [
            for (var i = 0; i < 500; i++)
              {
                'sender_name': 'Bulk',
                'timestamp_ms': 1600000000000 + i,
                'content': i == 250 ? leakedBody * 10000 : 'message $i',
              },
          ],
          'title': 'Bulk',
        }),
      });

      final outcome = await coordinator.importSource(dir.path) as ImportOutcome;

      expect(outcome.events, 499);
      expect(outcome.skippedRecords, 1);
      expect(outcome.warnings, hasLength(1));
      final warning = outcome.warnings.single;
      expect(warning, contains('file=$path'));
      expect(warning, contains('field=events.text_content'));
      expect(warning, contains('bound=maximum'));
      expect(warning, isNot(contains('LEAK')));

      final importRow = await workspace.database
          .select(workspace.database.imports)
          .getSingle();
      expect(importRow.status.name, 'completed');
      final events = await workspace.database
          .select(workspace.database.events)
          .get();
      expect(events, hasLength(499));
      expect(
        events.every((event) => event.textContent!.length <= 100000),
        isTrue,
      );
    },
  );

  test(
    'an export with empty and oversized values imports completely',
    () async {
      // Moved from test/manual/empty_sender_proof_test.dart: the original
      // failure rolled back every record. Values that previously threw now
      // cost at most their own row, and every stored value stays in bounds.
      final dir = await Directory.systemTemp.createTemp('empty-sender-proof-');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final long = 'ن' * 4000;
      final messages = {
        'messages': [
          {'sender_name': '', 'timestamp_ms': 1000, 'content': 'first'},
          {'sender_name': '   ', 'timestamp_ms': 2000, 'content': 'whitespace'},
          {'sender_name': long, 'timestamp_ms': 3000, 'content': 'long name'},
          {'sender_name': 'ليلى', 'timestamp_ms': 4000, 'content': 'ok'},
          {'sender_name': 'ليلى', 'timestamp_ms': 5000, 'content': long},
        ],
        'participants': [
          {'name': 'ليلى'},
        ],
        'title': '',
      };
      final archive = Archive()
        ..addFile(
          ArchiveFile(
            'messages/inbox/leila_100/message_1.json',
            utf8.encode(jsonEncode(messages)).length,
            utf8.encode(jsonEncode(messages)),
          ),
        );
      final zip = File('${dir.path}/export.zip');
      await zip.writeAsBytes(ZipEncoder().encode(archive));

      final outcome =
          await coordinator.importArchive(zip) as ImportOutcome;

      expect(outcome.events, 5, reason: 'the archive must import, not roll back');
      expect(outcome.people, 2, reason: 'two blank names are skipped');
      expect(outcome.skippedRecords, 2);
      // Both blank senders produce the same content-free warning, so the
      // outcome carries one detail line while the skipped counter stays 2.
      expect(outcome.warnings, hasLength(1));
      expect(outcome.warnings.single, contains('field=people.display_name'));
      expect(outcome.warnings.single, contains('bound=minimum'));

      final events = await workspace.database
          .select(workspace.database.events)
          .get();
      final people = await workspace.database
          .select(workspace.database.people)
          .get();
      expect(events, hasLength(5));
      expect(people, hasLength(2));
      for (final person in people) {
        expect(person.displayName.trim(), isNotEmpty);
        expect(person.displayName.length, lessThanOrEqualTo(512));
      }
      for (final event in events) {
        expect(event.sourceLocator.length, lessThanOrEqualTo(2048));
      }
    },
  );

  test('a per-row unique conflict is skipped, not fatal', () async {
    // A real archive can violate a database constraint for one row; that row
    // must cost itself, not the transaction. A unique body stands in for such
    // a conflict without weakening any app check.
    await workspace.database.customStatement(
      'CREATE UNIQUE INDEX test_unique_body ON events (text_content)',
    );
    final dir = await export({
      'your_activity/messages/inbox/dup/message_1.json': jsonEncode({
        'participants': [
          {'name': 'Dup'},
        ],
        'messages': [
          {
            'sender_name': 'Dup',
            'timestamp_ms': 1600000000000,
            'content': 'same body',
          },
          {
            'sender_name': 'Dup',
            'timestamp_ms': 1600000001000,
            'content': 'same body',
          },
        ],
        'title': 'Dup',
      }),
    });

    final outcome = await coordinator.importSource(dir.path) as ImportOutcome;

    expect(outcome.events, 1);
    expect(outcome.skippedRecords, 1);
    expect(outcome.warnings, hasLength(1));
    expect(outcome.warnings.single, contains('field=events.text_content'));
    expect(outcome.warnings.single, contains('bound=write'));

    final events = await workspace.database
        .select(workspace.database.events)
        .get();
    expect(events, hasLength(1));
  });
}
