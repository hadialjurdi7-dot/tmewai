import 'package:drift/drift.dart';

import 'search_text.dart';

/// Name of the FTS5 virtual table. It is not declared in `@DriftDatabase`
/// because drift's table DSL cannot express a virtual table.
const String eventSearchTable = 'event_search';

/// Raw SQL for the search index and for keeping it in step with `events`.
///
/// The index is a standalone FTS5 table written by triggers, so an inserted,
/// updated or deleted event is mirrored in the same transaction as the write
/// itself: no code path can change `events` without the index following.
///
/// The tokenizer is `unicode61 remove_diacritics 2`, which folds Latin
/// diacritics and case; Arabic diacritics are additionally stripped by
/// [searchTextSqlExpression] because unicode61 treats harakat as separators.
List<String> eventSearchSchemaStatements() => [
  '''
CREATE VIRTUAL TABLE IF NOT EXISTS $eventSearchTable USING fts5(
  event_id UNINDEXED,
  text_content,
  source_locator,
  tokenize = 'unicode61 remove_diacritics 2'
);
''',
  '''
CREATE TRIGGER IF NOT EXISTS events_search_after_insert
AFTER INSERT ON events BEGIN
  INSERT INTO $eventSearchTable (event_id, text_content, source_locator)
  VALUES (
    new.id,
    ${searchTextSqlExpression('new.text_content')},
    ${searchTextSqlExpression('new.source_locator')}
  );
END;
''',
  '''
CREATE TRIGGER IF NOT EXISTS events_search_after_update
AFTER UPDATE ON events BEGIN
  DELETE FROM $eventSearchTable WHERE event_id = old.id;
  INSERT INTO $eventSearchTable (event_id, text_content, source_locator)
  VALUES (
    new.id,
    ${searchTextSqlExpression('new.text_content')},
    ${searchTextSqlExpression('new.source_locator')}
  );
END;
''',
  '''
CREATE TRIGGER IF NOT EXISTS events_search_after_delete
AFTER DELETE ON events BEGIN
  DELETE FROM $eventSearchTable WHERE event_id = old.id;
END;
''',
];

/// Creates the search index and its triggers. Safe to run on every upgrade
/// step that predates the index.
Future<void> createEventSearchIndex(GeneratedDatabase database) async {
  for (final statement in eventSearchSchemaStatements()) {
    await database.customStatement(statement);
  }
}

/// Replaces the search triggers and rebuilds every FTS row from stored events.
///
/// Call when [searchTextSqlExpression] changes: existing rows contain the old
/// normalization. The transaction makes index contents and trigger semantics
/// switch together; stored event text is read only and never rewritten.
Future<void> rebuildEventSearchIndex(GeneratedDatabase database) async {
  await database.transaction(() async {
    await database.customStatement(
      'DROP TRIGGER IF EXISTS events_search_after_insert',
    );
    await database.customStatement(
      'DROP TRIGGER IF EXISTS events_search_after_update',
    );
    await database.customStatement(
      'DROP TRIGGER IF EXISTS events_search_after_delete',
    );
    await database.customStatement('DELETE FROM $eventSearchTable');
    await createEventSearchIndex(database);
    await database.customStatement('''
INSERT INTO $eventSearchTable (event_id, text_content, source_locator)
SELECT e.id, ${searchTextSqlExpression('e.text_content')},
  ${searchTextSqlExpression('e.source_locator')}
FROM events AS e
''');
  });
}

/// Copies events that were stored before the index existed into it.
///
/// The triggers only see writes that happen after they are created, so a
/// database upgraded from v1 would otherwise keep every imported event
/// unsearchable until the row was rewritten. The `NOT EXISTS` guard makes this
/// idempotent: rows already indexed are skipped, so running the migration again
/// cannot duplicate them.
Future<void> backfillEventSearchIndex(GeneratedDatabase database) async {
  await database.customStatement('''
INSERT INTO $eventSearchTable (event_id, text_content, source_locator)
SELECT
  e.id,
  ${searchTextSqlExpression('e.text_content')},
  ${searchTextSqlExpression('e.source_locator')}
FROM events AS e
WHERE NOT EXISTS (
  SELECT 1 FROM $eventSearchTable AS s WHERE s.event_id = e.id
);
''');
}
