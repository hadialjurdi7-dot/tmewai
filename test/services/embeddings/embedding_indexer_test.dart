import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/domain/models/event_record.dart';
import 'package:personal_data_agent/src/domain/models/import_record.dart';
import 'package:personal_data_agent/src/domain/models/source_file.dart';
import 'package:personal_data_agent/src/services/embeddings/embedding_consent.dart';
import 'package:personal_data_agent/src/services/embeddings/embedding_indexer.dart';
import 'package:personal_data_agent/src/services/embeddings/embedding_model.dart';
import 'package:personal_data_agent/src/services/embeddings/embedding_vector.dart';

void main() {
  late AppDatabase database;
  late int importId;
  late int sourceFileId;
  late EmbeddingIndexer indexer;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    importId = await database
        .into(database.imports)
        .insert(
          ImportsCompanion.insert(
            platform: 'facebook',
            format: 'json',
            sourceFingerprint: 'sha256:semantic-fixture',
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
            relativePath: 'messages/inbox/message_1.json',
            parseStatus: ParseStatus.parsed,
          ),
        );
    indexer = EmbeddingIndexer(database, const HashMapEmbedder());
    // Phase 2 gate: no text is embedded before the user approved local
    // inference, so every indexing test starts from a stored consent row.
    await indexer.consent.grant(
      grantedAt: DateTime.utc(2026, 1, 1),
      eventCount: 0,
    );
  });

  tearDown(() async {
    await indexer.dispose();
    await database.close();
  });

  Future<int> insertEvent({required String locator, required String? text}) {
    return database
        .into(database.events)
        .insert(
          EventsCompanion.insert(
            importId: importId,
            sourceFileId: sourceFileId,
            sourceLocator: locator,
            platform: 'facebook',
            eventType: 'message',
            timezoneStatus: TimezoneStatus.explicitOffset,
            textContent: Value(text),
          ),
        );
  }

  Future<int> currentVectorCount() async {
    final rows = await database
        .customSelect(
          'SELECT COUNT(*) AS n FROM event_embeddings WHERE model_id = ?',
          variables: [Variable<String>(indexerModelId)],
        )
        .getSingle();
    return rows.read<int>('n');
  }

  test('embeds every non-empty event once and reports real progress', () async {
    await insertEvent(locator: 'messages/inbox/message_1.json#0', text: 'أحمد');
    await insertEvent(locator: 'messages/inbox/message_1.json#1', text: 'قهوة');
    await insertEvent(
      locator: 'messages/inbox/message_1.json#2',
      text: 'unrelated note',
    );
    await insertEvent(locator: 'messages/inbox/message_1.json#3', text: '   ');
    await insertEvent(locator: 'messages/inbox/message_1.json#4', text: null);

    final progress = <EmbeddingIndexProgress>[];
    final subscription = indexer.progress.listen(progress.add);
    addTearDown(subscription.cancel);

    expect((await indexer.status()).total, 3);
    expect(await indexer.indexPending(batch: 2), 3);
    await Future<void>.delayed(Duration.zero);

    expect(await currentVectorCount(), 3);
    expect(progress.first.done, 0);
    expect(progress.first.total, 3);
    expect(progress.last.done, 3);
    expect(progress.last.total, 3);
    expect(progress.last.isComplete, isTrue);

    // A second run has nothing new to embed.
    expect(await indexer.indexPending(batch: 2), 0);
    await Future<void>.delayed(Duration.zero);
    expect(await currentVectorCount(), 3);
  });

  test(
    'prunes vectors from another model without touching current rows',
    () async {
      final eventId = await insertEvent(
        locator: 'messages/inbox/message_1.json#0',
        text: 'current model text',
      );
      await insertEvent(
        locator: 'messages/inbox/message_1.json#1',
        text: 'another current text',
      );
      await indexer.indexPending();

      // Replace one row with an older model's vector, as an upgrade would leave
      // it before the new model has been built.
      await database
          .into(database.eventEmbeddings)
          .insertOnConflictUpdate(
            EventEmbeddingsCompanion.insert(
              eventId: Value(eventId),
              modelId: 'older-model',
              dim: 384,
              vector: encodeFloat32Vector(Float32List(384)),
            ),
          );

      expect(await indexer.pruneStale(), 1);
      expect(await currentVectorCount(), 1);
      final stale = await database
          .customSelect(
            "SELECT COUNT(*) AS n FROM event_embeddings "
            "WHERE model_id = 'older-model'",
          )
          .getSingle();
      expect(stale.read<int>('n'), 0);
    },
  );

  test('deleting an event cascades to its vector', () async {
    final eventId = await insertEvent(
      locator: 'messages/inbox/message_1.json#0',
      text: 'removable vector',
    );
    await indexer.indexPending();
    expect(await currentVectorCount(), 1);

    await (database.delete(
      database.events,
    )..where((row) => row.id.equals(eventId))).go();

    expect(await currentVectorCount(), 0);
  });

  test('refuses to index until local embedding is approved', () async {
    await insertEvent(
      locator: 'messages/inbox/message_1.json#9',
      text: 'قهوة بالصبح',
    );
    // Drop the setUp approval: this is the state of a fresh install.
    await database.delete(database.aiConsents).go();

    await expectLater(
      indexer.indexPending(),
      throwsA(isA<EmbeddingConsentRequired>()),
    );
    expect(await currentVectorCount(), 0);

    // The gate is not a dead end: giving approval unblocks the same run.
    await indexer.consent.ensureGranted(grantedAt: DateTime.utc(2026, 1, 2));
    expect(await indexer.indexPending(), 1);
    expect(await currentVectorCount(), 1);
  });
}

const String indexerModelId = HashMapEmbedder.fakeModelId;
