import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/domain/models/event_record.dart';
import 'package:personal_data_agent/src/domain/models/import_record.dart';
import 'package:personal_data_agent/src/domain/models/source_file.dart';
import 'package:personal_data_agent/src/features/search/search_service.dart';
import 'package:personal_data_agent/src/services/embeddings/embedding_indexer.dart';
import 'package:personal_data_agent/src/services/embeddings/embedding_model.dart';

/// Fixed-vector double: the point of this file is ranking, not the model.
///
/// A green suite proves the plumbing runs; it does not prove that the right row
/// comes back. These vectors are hand-placed so that the intended answer is the
/// nearest neighbour for each query while sharing no token with it, which is
/// exactly the case a lexical index cannot serve.
///
///   0 -> travel, 1 -> food, 2 -> money
class _RelevanceEmbedder extends EmbeddingModel {
  const _RelevanceEmbedder();

  @override
  String get modelId => 'relevance-fixture-v1';

  @override
  int get dim => 3;

  @override
  Future<List<Float32List>> embed(List<String> texts) async => [
    for (final text in texts)
      Float32List.fromList(switch (text) {
        // Rows.
        'بدي احجز تذكرة للشام' => const [1, 0, 0],
        'شو الطبخة اليوم؟' => const [0, 1, 0],
        'البنك رفض التحويل' => const [0, 0, 1],
        // Arabic queries that never appear in the rows above.
        'سفر' => const [1, 0, 0],
        'أكل' => const [0, 1, 0],
        // English query, same expectation.
        'flight' => const [1, 0, 0],
        _ => const [0, 0, 0],
      }),
  ];
}

void main() {
  late AppDatabase database;
  late SearchService service;
  late int travelId;
  late int foodId;
  late int moneyId;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    const model = _RelevanceEmbedder();
    service = SearchService(database, embeddingModel: model);

    final importId = await database
        .into(database.imports)
        .insert(
          ImportsCompanion.insert(
            platform: 'facebook',
            format: 'json',
            sourceFingerprint: 'sha256:relevance-fixture',
            startedAt: DateTime.utc(2026, 1, 1),
            importerVersion: '0.1.0',
            status: ImportStatus.completed,
          ),
        );
    final sourceFileId = await database
        .into(database.sourceFiles)
        .insert(
          SourceFilesCompanion.insert(
            importId: importId,
            relativePath: 'messages/inbox/message_1.json',
            parseStatus: ParseStatus.parsed,
          ),
        );

    Future<int> insert(String locator, String text, DateTime timestamp) {
      return database
          .into(database.events)
          .insert(
            EventsCompanion.insert(
              importId: importId,
              sourceFileId: sourceFileId,
              sourceLocator: locator,
              platform: 'facebook',
              eventType: 'message',
              timestampNormalized: Value(timestamp.toUtc()),
              timezoneStatus: TimezoneStatus.explicitOffset,
              textContent: Value(text),
            ),
          );
    }

    travelId = await insert(
      'messages/inbox/message_1.json#0',
      'بدي احجز تذكرة للشام',
      DateTime.utc(2026, 1, 1),
    );
    foodId = await insert(
      'messages/inbox/message_1.json#1',
      'شو الطبخة اليوم؟',
      DateTime.utc(2025, 1, 1),
    );
    moneyId = await insert(
      'messages/inbox/message_1.json#2',
      'البنك رفض التحويل',
      DateTime.utc(2024, 1, 1),
    );

    final indexer = EmbeddingIndexer(database, model);
    addTearDown(indexer.dispose);
    await indexer.consent.grant(
      grantedAt: DateTime.utc(2026, 1, 1),
      eventCount: 3,
    );
    expect(await indexer.indexPending(), 3);
  });

  tearDown(() async {
    await database.close();
  });

  test('Arabic query with no lexical match returns the intended row first', () async {
    final outcome = await service.search('سفر');

    expect(outcome.mode, SearchMode.hybrid);
    expect(outcome.rows.first.hit.eventId, travelId);
    expect(outcome.rows.first.hit.textContent, 'بدي احجز تذكرة للشام');
  });

  test('a second Arabic query picks its own neighbour', () async {
    final outcome = await service.search('أكل');

    expect(outcome.rows.first.hit.eventId, foodId);
  });

  test('English query picks the same neighbour as its Arabic twin', () async {
    final outcome = await service.search('flight');

    expect(outcome.rows.first.hit.eventId, travelId);
    expect(outcome.rows.first.hit.eventId, isNot(moneyId));
  });
}
