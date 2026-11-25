import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/ai_consent_repository.dart';
import 'package:personal_data_agent/src/domain/models/event_record.dart';
import 'package:personal_data_agent/src/domain/models/import_record.dart';
import 'package:personal_data_agent/src/domain/models/source_file.dart';
import 'package:personal_data_agent/src/services/ai/ai_gateway.dart';
import 'package:personal_data_agent/src/services/ai/ai_provider.dart';

class _FakeProvider implements AiProvider {
  const _FakeProvider();

  @override
  String get id => 'fake_provider';

  @override
  String get displayName => 'Fake Provider';

  @override
  Uri get retentionPolicyUrl => Uri.parse('https://example.invalid/privacy');

  @override
  String get estimatedCostHint => 'free for tests';

  @override
  String get policyVersion => '2026-10-01';
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase database;
  late AiGateway gateway;
  late int importId;
  late int sourceFileId;

  const provider = _FakeProvider();

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    gateway = AiGateway(database: database, maxEvents: 3, maxTotalChars: 10);
    importId = await database
        .into(database.imports)
        .insert(
          ImportsCompanion.insert(
            platform: 'facebook',
            format: 'json',
            sourceFingerprint: 'sha256:fixture',
            startedAt: DateTime.utc(2026, 10, 26),
            importerVersion: '0.1.0',
            status: ImportStatus.completed,
          ),
        );
    sourceFileId = await database
        .into(database.sourceFiles)
        .insert(
          SourceFilesCompanion.insert(
            importId: importId,
            relativePath: 'posts/your_posts_1.json',
            parseStatus: ParseStatus.parsed,
          ),
        );
  });

  tearDown(() => database.close());

  Future<int> addEvent(String locator, String text) {
    return database
        .into(database.events)
        .insert(
          EventsCompanion.insert(
            importId: importId,
            sourceFileId: sourceFileId,
            sourceLocator: locator,
            platform: 'facebook',
            eventType: 'post',
            timezoneStatus: TimezoneStatus.utc,
            textContent: Value(text),
          ),
        );
  }

  Future<List<int>> seedEvents() async {
    return [
      await addEvent('posts/your_posts_1.json#/posts/0', 'aaaa'),
      await addEvent('posts/your_posts_1.json#/posts/1', 'bbbb'),
      await addEvent('posts/your_posts_1.json#/posts/2', 'cccc'),
      await addEvent('posts/your_posts_1.json#/posts/3', 'dddd'),
      await addEvent(
        '/Users/person/export/posts/your_posts_1.json#/posts/4',
        'absolute secret text',
      ),
    ];
  }

  test('prepareRequest respects count and character bounds', () async {
    final ids = await seedEvents();

    final request = await gateway.prepareRequest(
      provider: provider,
      model: 'tiny-model',
      eventIds: ids,
    );

    expect(request.eventIds.length, lessThanOrEqualTo(3));
    expect(request.excerpts.length, request.eventIds.length);
    expect(request.sourceLocators.length, request.eventIds.length);
    expect(
      request.charCount,
      lessThanOrEqualTo(10),
      reason: 'the character budget bounds the bundle',
    );
    expect(
      request.byteCount,
      request.excerpts.fold<int>(
        0,
        (sum, excerpt) => sum + utf8.encode(excerpt).length,
      ),
    );
    expect(request.providerId, 'fake_provider');
    expect(request.providerDisplayName, 'Fake Provider');
    expect(request.policyVersion, '2026-10-01');
    expect(request.model, 'tiny-model');

    for (final locator in request.sourceLocators) {
      expect(locator, isNot(startsWith('/')));
      expect(locator, isNot(contains('/Users/')));
      expect(locator, isNot(contains('..')));
    }
    expect(request.excerpts.join(), isNot(contains('absolute')));
    expect(request.scopeSummary, isNot(contains('aaaa')));
    expect(request.scopeSummary, contains('model:tiny-model'));
  });

  test('dispatch without consent throws ConsentRequired and stores nothing', () async {
    final request = await gateway.prepareRequest(
      provider: provider,
      model: 'tiny-model',
      eventIds: await seedEvents(),
    );

    await expectLater(
      gateway.dispatch(request: request),
      throwsA(isA<ConsentRequired>()),
    );
    expect(await database.select(database.aiConsents).get(), isEmpty);

    // A grant for a different provider or policy version is not consent.
    await expectLater(
      gateway.dispatch(
        request: request,
        consent: const AiConsentGrant(
          providerId: 'other_provider',
          policyVersion: '2026-10-01',
          scopeSummary: 'events:1',
        ),
      ),
      throwsA(isA<ConsentRequired>()),
    );
    await expectLater(
      gateway.dispatch(
        request: request,
        consent: const AiConsentGrant(
          providerId: 'fake_provider',
          policyVersion: '2020-01-01',
          scopeSummary: 'events:1',
        ),
      ),
      throwsA(isA<ConsentRequired>()),
    );
    expect(await database.select(database.aiConsents).get(), isEmpty);
  });

  test('dispatch with consent stores one metadata row and makes no request', () async {
    final request = await gateway.prepareRequest(
      provider: provider,
      model: 'tiny-model',
      eventIds: await seedEvents(),
    );
    var httpClientConstructed = false;

    await HttpOverrides.runZoned(() async {
      await expectLater(
        gateway.dispatch(
          request: request,
          consent: const AiConsentGrant(
            providerId: 'fake_provider',
            policyVersion: '2026-10-01',
            scopeSummary: 'events:1',
          ),
        ),
        throwsA(isA<UnimplementedError>()),
      );
    }, createHttpClient: (_) {
      httpClientConstructed = true;
      throw StateError('network access is not allowed in this layer');
    });

    expect(
      httpClientConstructed,
      isFalse,
      reason: 'the gateway never constructs an HTTP client',
    );

    final rows = await database.select(database.aiConsents).get();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.providerId, 'fake_provider');
    expect(row.policyVersion, '2026-10-01');
    expect(row.scopeSummary, request.scopeSummary);
    expect(row.eventCount, request.eventIds.length);
    expect(row.byteCount, request.byteCount);

    final stored = await AiConsentRepository(database).findAll();
    expect(stored, hasLength(1));
    expect(stored.single.grantedAt.isUtc, isTrue);
    expect(stored.single.providerId, 'fake_provider');

    // The stored consent never contains the excerpt text.
    final storedText = [
      row.providerId,
      row.policyVersion,
      row.scopeSummary,
    ].join('\n');
    for (final excerpt in request.excerpts) {
      expect(storedText, isNot(contains(excerpt)));
    }
  });

  test('the AI layer has no network code', () {
    const sources = [
      'lib/src/services/ai/ai_provider.dart',
      'lib/src/services/ai/ai_gateway.dart',
      'lib/src/data/repositories/ai_consent_repository.dart',
    ];
    for (final source in sources) {
      final text = File(source).readAsStringSync();
      expect(text, isNot(contains('HttpClient')), reason: source);
      expect(text, isNot(contains('package:http')), reason: source);
      expect(text, isNot(contains('dart:io')), reason: source);
      expect(text, isNot(contains('http://')), reason: source);
    }
  });
}
