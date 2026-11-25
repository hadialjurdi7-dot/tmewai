import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/domain/models/event_record.dart';
import 'package:personal_data_agent/src/domain/models/import_record.dart';
import 'package:personal_data_agent/src/domain/models/source_file.dart';
import 'package:personal_data_agent/src/services/embeddings/embedding_model.dart';
import 'package:personal_data_agent/src/services/embeddings/embedding_vector.dart';
import 'package:personal_data_agent/src/services/embeddings/vector_search_service.dart';

class _FixedEmbedder extends EmbeddingModel {
  const _FixedEmbedder(this.vectors);

  final Map<String, List<double>> vectors;

  @override
  String get modelId => 'fixed-test-model';

  @override
  int get dim => 3;

  @override
  Future<List<Float32List>> embed(List<String> texts) async => [
    for (final text in texts)
      Float32List.fromList(vectors[text] ?? const <double>[0, 0, 0]),
  ];
}

void main() {
  late AppDatabase database;
  late int importId;
  late int sourceFileId;
  late _FixedEmbedder model;
  late VectorSearchService service;
  late int coffeeStrong;
  late int coffeeWeak;
  late int weather;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    model = const _FixedEmbedder({
      'coffee query': [1, 0, 0],
      'قهوة': [1, 0, 0],
      'نسكافيه': [0.8, 0.6, 0],
      'الجو': [0, 1, 0],
    });
    service = VectorSearchService(database, model);
    importId = await database
        .into(database.imports)
        .insert(
          ImportsCompanion.insert(
            platform: 'facebook',
            format: 'json',
            sourceFingerprint: 'sha256:vector-fixture',
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

    coffeeStrong = await _insertEvent(
      database: database,
      importId: importId,
      sourceFileId: sourceFileId,
      locator: 'messages/inbox/message_1.json#0',
      text: 'قهوة',
      eventType: 'message',
      timestamp: DateTime.utc(2026, 1, 3),
      model: model,
      vector: const [1, 0, 0],
    );
    coffeeWeak = await _insertEvent(
      database: database,
      importId: importId,
      sourceFileId: sourceFileId,
      locator: 'messages/inbox/message_1.json#1',
      text: 'نسكافيه',
      eventType: 'comment',
      timestamp: DateTime.utc(2024, 1, 1),
      model: model,
      vector: const [0.8, 0.6, 0],
    );
    weather = await _insertEvent(
      database: database,
      importId: importId,
      sourceFileId: sourceFileId,
      locator: 'posts/your_posts.json#0',
      text: 'الجو',
      eventType: 'post',
      timestamp: DateTime.utc(2026, 1, 1),
      model: model,
      vector: const [0, 1, 0],
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('ranks related messages above unrelated ones', () async {
    final hits = await service.search('coffee query');

    expect(hits.map((hit) => hit.eventId), [coffeeStrong, coffeeWeak, weather]);
    expect(hits.first.score, closeTo(1.0, 1e-6));
    expect(hits[1].score, closeTo(0.8, 1e-6));
    expect(hits.last.score, closeTo(0.0, 1e-6));
  });

  test('applies the date and event-type filters before scoring', () async {
    final recent = await service.search(
      'coffee query',
      from: DateTime.utc(2025, 1, 1),
    );
    expect(recent.map((hit) => hit.eventId), [coffeeStrong, weather]);

    final posts = await service.search('coffee query', eventType: 'post');
    expect(posts.map((hit) => hit.eventId), [weather]);

    final oldComments = await service.search(
      'coffee query',
      to: DateTime.utc(2025, 1, 1),
      eventType: 'comment',
    );
    expect(oldComments.map((hit) => hit.eventId), [coffeeWeak]);
  });

  test('honours the limit and skips a malformed blob', () async {
    final corrupted = await _insertEvent(
      database: database,
      importId: importId,
      sourceFileId: sourceFileId,
      locator: 'messages/inbox/message_1.json#2',
      text: 'damaged',
      eventType: 'message',
      timestamp: DateTime.utc(2026, 2, 1),
      model: model,
      vector: const [1],
    );

    final hits = await service.search('coffee query', limit: 2);

    expect(hits, hasLength(2));
    expect(hits.map((hit) => hit.eventId), [coffeeStrong, coffeeWeak]);
    expect(hits.map((hit) => hit.eventId), isNot(contains(corrupted)));
  });

  test('an empty query or an empty index returns no vectors', () async {
    expect(await service.search('   '), isEmpty);
    await database.delete(database.eventEmbeddings).go();
    expect(await service.hasIndex(), isFalse);
    expect(await service.search('coffee query'), isEmpty);
  });
}

Future<int> _insertEvent({
  required AppDatabase database,
  required int importId,
  required int sourceFileId,
  required String locator,
  required String text,
  required String eventType,
  required DateTime timestamp,
  required EmbeddingModel model,
  required List<double> vector,
}) async {
  final eventId = await database
      .into(database.events)
      .insert(
        EventsCompanion.insert(
          importId: importId,
          sourceFileId: sourceFileId,
          sourceLocator: locator,
          platform: 'facebook',
          eventType: eventType,
          timestampNormalized: Value(timestamp.toUtc()),
          timezoneStatus: TimezoneStatus.explicitOffset,
          textContent: Value(text),
        ),
      );
  await database
      .into(database.eventEmbeddings)
      .insert(
        EventEmbeddingsCompanion.insert(
          eventId: Value(eventId),
          modelId: model.modelId,
          dim: model.dim,
          vector: encodeFloat32Vector(Float32List.fromList(vector)),
        ),
      );
  return eventId;
}
