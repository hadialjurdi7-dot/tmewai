import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/core/l10n/app_strings.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/features/search/search_controller.dart';
import 'package:personal_data_agent/src/features/search/search_screen.dart';
import 'package:personal_data_agent/src/features/search/search_service.dart';
import 'package:personal_data_agent/src/services/embeddings/embedding_indexer.dart';
import 'package:personal_data_agent/src/services/embeddings/embedding_model.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

/// Records that the screen invoked the action and flips the status to complete
/// without spawning the real indexing isolate inside the widget test harness.
class _RecordingIndexer extends EmbeddingIndexer {
  _RecordingIndexer(AppDatabase database)
    : super(database, const HashMapEmbedder());

  int calls = 0;
  int indexed = 1;

  @override
  Future<EmbeddingIndexStatus> status() async =>
      EmbeddingIndexStatus(indexed: indexed, total: 3);

  @override
  Future<int> indexPending({int batch = 64}) async {
    calls++;
    indexed = 3;
    return 2;
  }
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late Directory tempDirectory;
  late AppDatabase database;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('pda-search-ui-');
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
    final file = File('${tempDirectory.path}/search.zip');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    await ImportCoordinator(database: database).importArchive(file);
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<void> pumpSearch(
    WidgetTester tester, {
    AppStrings appStrings = const AppStringsEn(),
    ValueChanged<int>? onOpenPerson,
    // Riverpod 3 does not export its `Override` type publicly; the list is
    // only forwarded to ProviderScope, which type-checks each entry.
    List<dynamic> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(1600, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchServiceProvider.overrideWith(
            (ref) async => SearchService(database),
          ),
          appStringsProvider.overrideWithValue(appStrings),
          ...overrides,
        ],
        child: MaterialApp(
          home: Scaffold(body: SearchScreen(onOpenPerson: onOpenPerson)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('search-query-field')), text);
    await tester.pumpAndSettle();
  }

  Future<void> chooseType(WidgetTester tester, String type) async {
    await tester.tap(find.byKey(const Key('search-type-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(type).last);
    await tester.pumpAndSettle();
  }

  Future<int> eventIdFor(String text) async {
    final event = await (database.select(
      database.events,
    )..where((row) => row.textContent.equals(text))).getSingle();
    return event.id;
  }

  testWidgets('typing a query shows the matching result and total', (
    tester,
  ) async {
    await pumpSearch(tester);
    expect(
      find.text('Type a word to search your imported records.'),
      findsOneWidget,
    );

    await search(tester, 'synthetic');

    expect(find.text('alpha synthetic message'), findsOneWidget);
    expect(find.text('beta synthetic message'), findsOneWidget);
    expect(find.text('alpha only without the second word'), findsNothing);
    expect(find.text('2 results for “synthetic”'), findsOneWidget);
    expect(find.text('All words must match.'), findsOneWidget);
  });

  testWidgets('a two-word query returns only records containing both words', (
    tester,
  ) async {
    await pumpSearch(tester);

    await search(tester, 'alpha synthetic');

    expect(find.text('alpha synthetic message'), findsOneWidget);
    expect(find.text('beta synthetic message'), findsNothing);
    expect(find.text('alpha only without the second word'), findsNothing);
    expect(find.text('1 result for “alpha synthetic”'), findsOneWidget);
  });

  testWidgets('an empty result names the active filter and offers widening', (
    tester,
  ) async {
    await pumpSearch(tester);
    await search(tester, 'alpha');
    expect(find.text('2 results for “alpha”'), findsOneWidget);

    // The seeded events are messages, so filtering by comments matches none.
    await chooseType(tester, 'comment');

    expect(find.text('alpha synthetic message'), findsNothing);
    expect(find.text('No results'), findsOneWidget);
    expect(
      find.text(
        'No records contain “alpha”. These filters narrowed the search.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('search-empty-filter-type')))
          .data,
      'Type: comment',
    );
    expect(find.byKey(const Key('search-widen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-widen')));
    await tester.pumpAndSettle();

    expect(find.text('2 results for “alpha”'), findsOneWidget);
    expect(find.byKey(const Key('search-empty-state')), findsNothing);
  });

  testWidgets('each row names its conversation, person and date', (
    tester,
  ) async {
    final id = await eventIdFor('alpha synthetic message');
    await pumpSearch(tester);

    await search(tester, 'alpha synthetic');

    expect(
      tester
          .widget<Text>(find.byKey(ValueKey('search-hit-conversation-$id')))
          .data,
      'Conversation: Friends',
    );
    expect(
      tester.widget<Text>(find.byKey(ValueKey('search-hit-person-$id'))).data,
      'Person: Fixtures Person',
    );
    expect(
      tester.widget<Text>(find.byKey(ValueKey('search-hit-date-$id'))).data,
      'Date: 2023-11-14 22:13 UTC',
    );
    expect(
      tester.widget<Text>(find.byKey(ValueKey('search-hit-source-$id'))).data,
      'Source: messages/inbox/friends/message_1.json#/messages/0',
    );
  });

  testWidgets('a result\'s person line opens that person’s profile', (
    tester,
  ) async {
    final id = await eventIdFor('alpha synthetic message');
    final person = await (database.select(
      database.people,
    )..where((row) => row.displayName.equals('Fixtures Person'))).getSingle();
    final opened = <int>[];
    await pumpSearch(tester, onOpenPerson: opened.add);

    await search(tester, 'alpha synthetic');
    await tester.tap(find.byKey(const ValueKey('search-hit-person-link')).first);
    await tester.pumpAndSettle();

    // The row carries the stored actor id, so the shell can open its profile.
    expect(opened, [person.id]);
    expect(
      tester.widget<Text>(find.byKey(ValueKey('search-hit-person-$id'))).data,
      'Person: Fixtures Person',
    );
  });

  testWidgets('one active filter can be removed without clearing the rest', (
    tester,
  ) async {
    await pumpSearch(tester);
    await search(tester, 'alpha');
    await chooseType(tester, 'comment');
    expect(find.byKey(const Key('search-filter-type')), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('search-filter-type')),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-filter-type')), findsNothing);
    expect(find.text('2 results for “alpha”'), findsOneWidget);
  });

  testWidgets('a date filter can be cleared one at a time', (tester) async {
    await pumpSearch(tester);
    await search(tester, 'alpha');
    await tester.enterText(
      find.byKey(const Key('search-from-field')),
      '2027-01-01',
    );
    await tester.pumpAndSettle();

    expect(find.text('No results'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('search-empty-filter-from')))
          .data,
      'From: 2027-01-01',
    );

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('search-filter-from')),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 results for “alpha”'), findsOneWidget);
    expect(find.byKey(const Key('search-filter-from')), findsNothing);
  });

  testWidgets('shows a partial semantic status and indexes the rest', (
    tester,
  ) async {
    final indexer = _RecordingIndexer(database);
    addTearDown(indexer.dispose);

    await pumpSearch(
      tester,
      overrides: [
        semanticIndexerProvider.overrideWith((ref) async => indexer),
        semanticIndexStatusProvider.overrideWith(
          (ref) async =>
              (await ref.watch(semanticIndexerProvider.future))!.status(),
        ),
        // The screen reads the composed status, which also carries the
        // platform and consent flags. Installing + approving keeps the
        // partial-index branch reachable in the test harness.
        semanticSearchStatusProvider.overrideWith((ref) async {
          final status =
              await (await ref.watch(semanticIndexerProvider.future))!.status();
          return SemanticSearchStatus(
            supported: true,
            modelInstalled: true,
            consentGranted: true,
            indexed: status.indexed,
            total: status.total,
          );
        }),
      ],
    );

    expect(find.text('Semantic search on 1 of 3 messages'), findsOneWidget);
    expect(find.byKey(const Key('search-semantic-index')), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-semantic-index')));
    // The in-flight row carries an indeterminate spinner, so pumpAndSettle
    // would never return. The indexer and the consent row talk to drift, which
    // needs real async: runAsync lets those futures complete, then a pump
    // rebuilds the screen.
    await tester.pump();
    // Two cycles: the first completes the indexer, the second resolves the
    // invalidated status providers back into a value.
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    expect(indexer.calls, 1);
    expect(indexer.indexed, 3);
    expect(find.byKey(const Key('search-semantic-status')), findsNothing);
    expect(find.byKey(const Key('search-semantic-indexing')), findsNothing);
  });

  testWidgets('partial semantic status is translated into Arabic', (
    tester,
  ) async {
    final indexer = _RecordingIndexer(database);
    addTearDown(indexer.dispose);

    await pumpSearch(
      tester,
      appStrings: const AppStringsAr(),
      overrides: [
        semanticIndexerProvider.overrideWith((ref) async => indexer),
        semanticIndexStatusProvider.overrideWith(
          (ref) async =>
              (await ref.watch(semanticIndexerProvider.future))!.status(),
        ),
        // The screen reads the composed status, which also carries the
        // platform and consent flags. Installing + approving keeps the
        // partial-index branch reachable in the test harness.
        semanticSearchStatusProvider.overrideWith((ref) async {
          final status =
              await (await ref.watch(semanticIndexerProvider.future))!.status();
          return SemanticSearchStatus(
            supported: true,
            modelInstalled: true,
            consentGranted: true,
            indexed: status.indexed,
            total: status.total,
          );
        }),
      ],
    );

    expect(find.text('بحث ذكي على 1 من 3 رسالة'), findsOneWidget);
    expect(find.byKey(const Key('search-semantic-index')), findsOneWidget);
  });

  testWidgets('Arabic renders the count, provenance and empty explanation', (
    tester,
  ) async {
    await pumpSearch(tester, appStrings: const AppStringsAr());

    await search(tester, 'alpha synthetic');
    expect(find.text('1 نتيجة لـ«alpha synthetic»'), findsOneWidget);
    expect(find.text('لازم تطابق كل الكلمات.'), findsOneWidget);
    expect(find.text('المحادثة: Friends'), findsOneWidget);
    expect(find.text('الشخص: Fixtures Person'), findsOneWidget);

    await chooseType(tester, 'comment');
    expect(
      find.text(
        'لا توجد سجلات تحتوي «alpha synthetic». هذه المرشحات ضيّقت البحث.',
      ),
      findsOneWidget,
    );
    expect(find.text('وسّع البحث'), findsOneWidget);
  });
}
