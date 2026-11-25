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

class _HybridEmbedder extends EmbeddingModel {
  const _HybridEmbedder();

  @override
  String get modelId => 'hybrid-test-model';

  @override
  int get dim => 3;

  @override
  Future<List<Float32List>> embed(List<String> texts) async => [
    for (final text in texts)
      Float32List.fromList(switch (text) {
        'alpha message' => const [0, 1, 0],
        'alpha second' => const [0, 0, 1],
        'beta note' => const [1, 0, 0],
        // Both the lexical word and the paraphrase map to the beta vector.
        'alpha' => const [1, 0, 0],
        'meaning' => const [1, 0, 0],
        _ => const [0, 0, 0],
      }),
  ];
}

void main() {
  late AppDatabase database;
  late SearchService service;
  late int alphaMessage;
  late int alphaSecond;
  late int betaNote;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    const model = _HybridEmbedder();
    service = SearchService(database, embeddingModel: model);
    final importId = await database
        .into(database.imports)
        .insert(
          ImportsCompanion.insert(
            platform: 'facebook',
            format: 'json',
            sourceFingerprint: 'sha256:hybrid-fixture',
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

    alphaMessage = await insert(
      'messages/inbox/message_1.json#0',
      'alpha message',
      DateTime.utc(2024, 1, 1),
    );
    alphaSecond = await insert(
      'messages/inbox/message_1.json#1',
      'alpha second',
      DateTime.utc(2023, 1, 1),
    );
    betaNote = await insert(
      'messages/inbox/message_1.json#2',
      'beta note',
      DateTime.utc(2026, 1, 1),
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

  test('hybrid mode adds a semantic-only match to the lexical page', () async {
    final outcome = await service.search('alpha');

    expect(outcome.mode, SearchMode.hybrid);
    expect(outcome.rows.map((row) => row.hit.eventId), contains(alphaMessage));
    expect(outcome.rows.map((row) => row.hit.eventId), contains(alphaSecond));
    // "beta note" has no lexical overlap with the query; only the vector list
    // puts it on the page.
    expect(outcome.rows.map((row) => row.hit.eventId), contains(betaNote));
    expect(outcome.totalHits, 3);
  });

  test(
    'a paraphrase query can return a row the FTS index never matched',
    () async {
      final outcome = await service.search('meaning');

      expect(outcome.mode, SearchMode.hybrid);
      expect(outcome.rows.first.hit.eventId, betaNote);
      expect(outcome.rows.first.hit.textContent, 'beta note');
    },
  );

  test(
    'falls back to the unchanged lexical page when no index exists',
    () async {
      await database.delete(database.eventEmbeddings).go();

      final outcome = await service.search('alpha', limit: 1);

      expect(outcome.mode, SearchMode.lexical);
      expect(outcome.rows, hasLength(1));
      expect(outcome.totalHits, 2);
      expect(outcome.rows.single.hit.eventId, alphaMessage);
    },
  );
}
