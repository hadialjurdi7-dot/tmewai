import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/attachment_repository.dart';
import 'package:personal_data_agent/src/data/repositories/conversation_repository.dart';
import 'package:personal_data_agent/src/data/repositories/event_search_repository.dart';
import 'package:personal_data_agent/src/data/repositories/person_repository.dart';
import 'package:personal_data_agent/src/data/repositories/timeline_repository.dart';

/// Every paged read rejects a non-positive limit before touching SQLite.
///
/// These guards are the reason a filter control that computes `limit: 0` (an
/// empty page, a zero-row year) fails loudly here instead of silently returning
/// the whole table. The empty archive is the second half: every read must
/// answer with an empty result, never throw and never invent a row.
void main() {
  late AppDatabase database;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('empty archive', () {
    test('aggregate reads answer with zero, not a row', () async {
      final attachments = AttachmentRepository(database);

      expect(await attachments.count(), 0);
      expect(await attachments.countsByYear(), isEmpty);
      expect(await attachments.media(), isEmpty);
      expect(await attachments.topPeople(), isEmpty);

      expect(await ConversationRepository(database).conversationCount(), 0);
      expect(await ConversationRepository(database).conversations(), isEmpty);
      expect(await PersonRepository(database).profile(1), isNull);
      expect(
        await TimelineRepository(database).countsByBucket(
          strftimeFormat: '%Y-%m',
        ),
        isEmpty,
      );
      expect(await TimelineRepository(database).latestEvents(), isEmpty);
      expect(await EventSearchRepository(database).topTerms(), isEmpty);
    });

    test('searching an empty index returns no hits and no exception', () async {
      final search = EventSearchRepository(database);

      expect(await search.searchEvents('رسالة'), isEmpty);
      expect(await search.filterEvents(), isEmpty);
      // A blank query must short-circuit before the MATCH clause.
      expect(await search.searchEvents('   '), isEmpty);
      expect(await search.searchEvents(''), isEmpty);
    });
  });

  group('limit guards', () {
    test('attachment reads reject a non-positive limit', () async {
      final repository = AttachmentRepository(database);
      await expectLater(repository.media(limit: 0), throwsArgumentError);
      await expectLater(repository.media(limit: -3), throwsArgumentError);
    });

    test('conversation messages reject a non-positive limit', () async {
      final repository = ConversationRepository(database);
      await expectLater(repository.messages(1, limit: 0), throwsArgumentError);
      await expectLater(repository.messages(1, limit: -5), throwsArgumentError);
    });

    test('person and timeline reads reject a non-positive limit', () async {
      final people = PersonRepository(database);
      await expectLater(
        people.recentMessages(1, limit: 0),
        throwsArgumentError,
      );
      await expectLater(
        people.recentMessages(1, limit: -2),
        throwsArgumentError,
      );

      final timeline = TimelineRepository(database);
      await expectLater(timeline.latestEvents(limit: 0), throwsArgumentError);
      await expectLater(timeline.loadRows(limit: 0), throwsArgumentError);
      await expectLater(timeline.loadRows(limit: -1), throwsArgumentError);
    });

    test('search rejects a bad limit or offset', () async {
      final search = EventSearchRepository(database);
      await expectLater(
        search.searchEvents('anything', limit: 0),
        throwsArgumentError,
      );
      await expectLater(
        search.searchEvents('anything', offset: -1),
        throwsArgumentError,
      );
      await expectLater(
        search.filterEvents(limit: 0),
        throwsArgumentError,
      );
      await expectLater(search.topTerms(limit: 0), throwsArgumentError);
    });
  });
}
