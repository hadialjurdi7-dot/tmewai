import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/features/search/search_service.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late Directory directory;
  late AppDatabase database;
  late SearchService service;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pda-search-service-');
    database = AppDatabase(NativeDatabase.memory());
    service = SearchService(database);
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'messages/inbox/friends/message_1.json',
          jsonEncode({
            'title': 'Friends',
            'messages': [
              {
                'sender_name': 'Fixtures Person',
                'timestamp_ms': 1700000000000,
                'content': 'alpha synthetic message',
              },
              {
                'sender_name': 'Fixtures Person',
                'timestamp_ms': 1700000100000,
                'content': 'beta synthetic message',
              },
              {
                'sender_name': 'Other Person',
                'timestamp_ms': 1700000200000,
                'content': 'alpha only without the second word',
              },
            ],
          }),
        ),
      );
    final file = File('${directory.path}/search.zip');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    await ImportCoordinator(database: database).importArchive(file);
  });

  tearDown(() async {
    await database.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('returns only records containing every word', () async {
    final outcome = await service.search('alpha synthetic');

    expect(outcome.totalHits, 1);
    expect(outcome.rows.single.hit.textContent, 'alpha synthetic message');
    expect(outcome.rows.single.conversationTitle, 'Friends');
    expect(outcome.rows.single.personName, 'Fixtures Person');
  });

  test('reports the total beyond the returned page', () async {
    final outcome = await service.search('synthetic', limit: 1);

    expect(outcome.rows, hasLength(1));
    expect(outcome.totalHits, 2);
  });

  test('an empty query returns no hits without querying', () async {
    final outcome = await service.search('   ');

    expect(outcome.rows, isEmpty);
    expect(outcome.totalHits, 0);
  });
}
