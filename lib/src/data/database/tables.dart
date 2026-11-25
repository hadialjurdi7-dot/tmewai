import 'package:drift/drift.dart';

import '../../domain/models/event_record.dart';
import '../../domain/models/import_record.dart';
import '../../domain/models/source_file.dart';

/// Tables of the initial schema, from docs/IMPLEMENTATION_PLAN.md §6.
///
/// Enums are stored as their names so a stored value stays readable and stable
/// when enum order changes.

/// One import run of a user-owned export archive.
class Imports extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get platform => text().withLength(min: 1, max: 64)();
  TextColumn get format => text().withLength(min: 1, max: 64)();
  TextColumn get sourceFingerprint => text().withLength(min: 1, max: 128)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get importerVersion => text().withLength(min: 1, max: 64)();
  TextColumn get status => textEnum<ImportStatus>()();

  /// Coverage totals of this import as a JSON object of counts, so the import
  /// report survives without re-reading the archive.
  TextColumn get coverageJson => text().withLength(min: 2, max: 4096).nullable()();
}

/// One file inside an imported archive and how it was handled.
@TableIndex(name: 'source_files_import_id', columns: {#importId})
class SourceFiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get importId =>
      integer().references(Imports, #id, onDelete: KeyAction.cascade)();
  TextColumn get relativePath => text().withLength(min: 1, max: 1024)();
  TextColumn get mediaType => text().withLength(min: 1, max: 128).nullable()();
  TextColumn get contentHash => text().withLength(min: 1, max: 128).nullable()();
  TextColumn get parseStatus => textEnum<ParseStatus>()();
  TextColumn get errorCode => text().withLength(min: 1, max: 64).nullable()();

  /// The same path can appear in two imports, never twice in one.
  @override
  List<Set<Column>> get uniqueKeys => [
        {importId, relativePath},
      ];
}

/// A person as one platform exported them. No merging by name alone.
class People extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get platform => text().withLength(min: 1, max: 64)();
  TextColumn get platformPersonId =>
      text().withLength(min: 1, max: 128).nullable()();
  TextColumn get displayName => text().withLength(min: 1, max: 512)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {platform, platformPersonId},
      ];
}

/// A conversation or message thread found in an import.
@TableIndex(name: 'conversations_import_id', columns: {#importId})
class Conversations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get importId =>
      integer().references(Imports, #id, onDelete: KeyAction.cascade)();
  TextColumn get sourceConversationId =>
      text().withLength(min: 1, max: 128).nullable()();
  TextColumn get title => text().withLength(min: 1, max: 512).nullable()();
}

/// One normalized record read from a source file.
@TableIndex(name: 'events_import_id', columns: {#importId})
@TableIndex(
  name: 'events_timestamp_normalized',
  columns: {#timestampNormalized},
)
@TableIndex(name: 'events_event_type', columns: {#eventType})
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get importId =>
      integer().references(Imports, #id, onDelete: KeyAction.cascade)();
  IntColumn get sourceFileId =>
      integer().references(SourceFiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get sourceLocator => text().withLength(min: 1, max: 2048)();
  TextColumn get platform => text().withLength(min: 1, max: 64)();
  TextColumn get eventType => text().withLength(min: 1, max: 64)();
  TextColumn get timestampRaw =>
      text().withLength(min: 1, max: 64).nullable()();
  DateTimeColumn get timestampNormalized => dateTime().nullable()();
  TextColumn get timezoneStatus => textEnum<TimezoneStatus>()();
  IntColumn get actorId =>
      integer().nullable().references(People, #id, onDelete: KeyAction.setNull)();
  IntColumn get conversationId => integer()
      .nullable()
      .references(Conversations, #id, onDelete: KeyAction.setNull)();
  TextColumn get textContent =>
      text().withLength(min: 0, max: 100000).nullable()();
  TextColumn get metadataJson =>
      text().withLength(min: 0, max: 8192).nullable()();

  /// Events are unique within one import for a given source locator.
  @override
  List<Set<Column>> get uniqueKeys => [
        {importId, sourceLocator},
      ];
}

/// One embedding vector for one event, stored as little-endian float32 bytes.
///
/// The primary key is the event itself: a single row always holds the vector
/// for the model the app currently uses. Re-embedding an event replaces that
/// row instead of accumulating copies, so storage stays bounded by the archive.
///
/// The foreign key is what makes deletion safe here. `PRAGMA foreign_keys` is
/// enabled on every open, so deleting an event removes its vector in the same
/// statement, even if a future delete path forgets about this table.
@TableIndex(name: 'event_embeddings_model_id', columns: {#modelId})
class EventEmbeddings extends Table {
  IntColumn get eventId =>
      integer().references(Events, #id, onDelete: KeyAction.cascade)();

  /// Identifies the model the vector came from. It is internal app state, not
  /// archive text, so it has no import text bound; the embedding model contract
  /// owns its shape and the indexer only writes the id of the loaded model.
  TextColumn get modelId => text()();
  IntColumn get dim => integer()();
  BlobColumn get vector => blob()();

  @override
  Set<Column> get primaryKey => {eventId};
}

/// One explicit, recorded consent for sending selected evidence to an AI
/// provider.
///
/// It stores what was approved (provider, policy version, scope summary and
/// sizes) and when, never the excerpt text itself.
class AiConsents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get providerId => text().withLength(min: 1, max: 64)();
  TextColumn get policyVersion => text().withLength(min: 1, max: 64)();
  TextColumn get scopeSummary => text().withLength(min: 1, max: 1024)();
  DateTimeColumn get grantedAt => dateTime()();
  IntColumn get eventCount => integer()();
  IntColumn get byteCount => integer()();
}

/// A media reference belonging to an event and backed by a source file.
class Attachments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get eventId => integer()
      .nullable()
      .references(Events, #id, onDelete: KeyAction.cascade)();
  IntColumn get sourceFileId =>
      integer().references(SourceFiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get relativePath => text().withLength(min: 1, max: 1024).nullable()();
  TextColumn get mediaType => text().withLength(min: 1, max: 128)();
  IntColumn get sizeBytes => integer()();
  TextColumn get contentHash => text().withLength(min: 1, max: 128).nullable()();
}
