import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// The generated part references the enums stored by the columns, so they must
// be visible here, not only in tables.dart.
import '../../domain/models/event_record.dart';
import '../../domain/models/import_record.dart';
import '../../domain/models/source_file.dart';
import 'event_search_schema.dart';
import 'text_repair_migration.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

/// The local, on-device database. Nothing in this layer opens a network
/// connection: every value stays in the user's application-support folder.
@DriftDatabase(
  tables: [
    Imports,
    SourceFiles,
    People,
    Conversations,
    Events,
    Attachments,
    EventEmbeddings,
    AiConsents,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the database on the given executor, including in-memory executors
  /// used by tests.
  AppDatabase(super.executor);

  /// Opens the on-disk database at [databasePath], which the workspace owns.
  ///
  /// `drift_flutter` is kept for this path: it bundles sqlite3 for desktop
  /// builds and runs the connection in a background isolate.
  ///
  /// [tempDirectoryPath] is where sqlite3 keeps intermediate query files. The
  /// workspace passes its own folder so nothing spills into a shared temporary
  /// directory, and so opening never needs a platform channel.
  AppDatabase.atPath(String databasePath, {String? tempDirectoryPath})
    : super(
        driftDatabase(
          name: 'personal_data_agent',
          // The browser build has no file system: drift keeps the database in
          // IndexedDB/OPFS and needs the sqlite3 wasm module plus its worker,
          // both copied into web/ and served next to index.html.
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
          native: DriftNativeOptions(
            databasePath: () async => databasePath,
            tempDirectoryPath: switch (tempDirectoryPath) {
              final String path => () async => path,
              null => null,
            },
          ),
        ),
      );

  /// Current schema version. Bump together with a matching `onUpgrade` case.
  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // The FTS5 index and its triggers are raw SQL: the table DSL cannot
      // express a virtual table.
      await createEventSearchIndex(this);
    },
    onUpgrade: (m, from, to) async {
      // One step per released version, applied in order. A database more
      // than one version behind runs every step it is missing.
      if (from < 2) {
        // v2 adds the FTS5 search index and its mirroring triggers. Existing
        // events predate the triggers, so they are indexed explicitly.
        await createEventSearchIndex(this);
        await backfillEventSearchIndex(this);
      }
      if (from < 3) {
        // v3 adds the stored coverage totals of an import. SQLite has no
        // `ADD COLUMN IF NOT EXISTS`, so check the table first: a database
        // that already carries the column must not be altered twice.
        final columns = await customSelect('PRAGMA table_info(imports)').get();
        final hasCoverageColumn = columns.any(
          (row) => row.read<String>('name') == 'coverage_json',
        );
        if (!hasCoverageColumn) {
          await m.addColumn(imports, imports.coverageJson);
        }
      }
      if (from < 4) {
        // v4 adds the AI consent log. It holds no excerpt text, only what the
        // user approved and when.
        await m.createTable(aiConsents);
      }
      if (from < 5) {
        // v5 changes Arabic search folding. Rebuild old rows from source
        // events and replace the triggers in one transaction; event text stays
        // unchanged, and the version gate makes this run once.
        await rebuildEventSearchIndex(this);
      }
      if (from < 6) {
        // v6 adds the optional semantic vector store. It starts empty: vectors
        // are only written after the user explicitly builds the index, so
        // upgrading never embeds or reads message text on its own.
        await m.createTable(eventEmbeddings);
        // `createTable` creates the table's declared indexes on current drift
        // versions; the guard keeps this step safe on older migrators too.
        await customStatement(
          'CREATE INDEX IF NOT EXISTS event_embeddings_model_id '
          'ON event_embeddings (model_id)',
        );
      }
      if (from < 7) {
        // v7 repairs text an earlier import stored in a broken encoding
        // (mojibake or HTML entities). The rewrite goes through the FTS
        // update trigger, so search sees the repaired text too.
        await repairExportedTextInPlace(this);
      }
      if (from >= 7 && from < 8) {
        // v8 re-runs the same repair because its rules grew: JSON-escaped
        // slashes are unescaped, and entities and `\\u` escapes are repaired in
        // titles and names too. The pass is idempotent, and it is skipped on a
        // database upgraded from before v7 only because that step already runs
        // the current rule set.
        await repairExportedTextInPlace(this);
      }
    },
    beforeOpen: (details) async {
      // SQLite keeps foreign keys off by default; the schema relies on them.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
