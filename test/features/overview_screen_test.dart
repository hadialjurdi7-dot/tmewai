import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/event_search_repository.dart';
import 'package:personal_data_agent/src/data/repositories/overview_repository.dart';
import 'package:personal_data_agent/src/features/overview/overview_controller.dart';
import 'package:personal_data_agent/src/features/overview/overview_screen.dart';
import 'package:personal_data_agent/src/features/search/search_controller.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late Directory tempDirectory;
  late AppDatabase database;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('pda-overview-ui-');
    database = AppDatabase(NativeDatabase.memory());
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'messages/inbox/friends/message_1.json',
          jsonEncode({
            'title': 'Friends',
            'messages': [
              {
                'sender_name': 'Fixtures Person',
                'timestamp_ms': 1698796800000,
                'content': 'first message',
              },
              {
                'sender_name': 'Fixtures Person',
                'timestamp_ms': 1698883200000,
                'content': 'second message',
              },
            ],
          }),
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'posts/your_posts_1.json',
          jsonEncode({
            'posts': [
              {
                'timestamp': 1698883200,
                'data': [
                  {'post': 'a synthetic post'},
                ],
                'attachments': const [],
              },
            ],
          }),
        ),
      );
    final file = File('${tempDirectory.path}/overview.zip');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    await ImportCoordinator(database: database).importArchive(file);
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<void> pumpOverview(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          overviewRepositoryProvider.overrideWith(
            (ref) async => OverviewRepository(database),
          ),
          searchRepositoryProvider.overrideWith(
            (ref) async => EventSearchRepository(database),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: OverviewScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a card opens exactly the records it counts', (tester) async {
    await pumpOverview(tester);

    expect(find.byKey(const Key('overview-card-type-message')), findsOneWidget);
    expect(find.text('a synthetic post'), findsNothing);

    await tester.tap(find.byKey(const Key('overview-card-type-message')));
    await tester.pumpAndSettle();

    // Two message records, none of the post record.
    expect(find.text('first message'), findsOneWidget);
    expect(find.text('second message'), findsOneWidget);
    expect(find.text('a synthetic post'), findsNothing);
    expect(find.textContaining('event_type = message'), findsOneWidget);
    expect(find.textContaining('2'), findsWidgets);
  });

  testWidgets('the unknown-date card opens only undated records', (
    tester,
  ) async {
    await pumpOverview(tester);

    await tester.tap(find.byKey(const Key('overview-card-unknown')));
    await tester.pumpAndSettle();

    expect(find.text('Events with an unknown date'), findsOneWidget);
    expect(find.text('No records match this definition.'), findsOneWidget);
  });
}
