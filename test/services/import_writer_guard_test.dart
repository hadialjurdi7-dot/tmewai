import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/services/importing/archive_inspector.dart';
import 'package:personal_data_agent/src/services/importing/facebook_json_importer.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';
import 'package:personal_data_agent/src/services/importing/import_coverage_report.dart';
import 'package:personal_data_agent/src/services/importing/import_text_normalizer.dart';

/// Drives the real [ImportCoordinator] writers with values at and beyond every
/// declared text bound.
///
/// `import_text_normalizer_test.dart` proves the registry matches the schema;
/// this file proves the writers actually use it. A writer that stops calling
/// `normalizeImportText` either lets an empty value reach drift (which throws
/// and fails the import) or stores an over-long value that the final bounds
/// assertion catches. A controlled preview is used only where an archive
/// scanner would reject a value before it could reach a writer, such as an
/// empty or over-long `source_files.relative_path`.
void main() {
  late Directory root;
  late AppDatabase database;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('writer-guard-');
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<ImportOutcome> importPreview(FacebookImportPreview preview) async {
    final coordinator = ImportCoordinator(
      database: database,
      importer: _PresetImporter(preview),
    );
    addTearDown(coordinator.dispose);
    final folder = Directory('${root.path}/export')..createSync();
    return await coordinator.importSource(folder.path) as ImportOutcome;
  }

  test('an empty source path is skipped and an over-long one is clipped', () async {
    final outcome = await importPreview(
      _preview(
        files: [
          _file('valid.json'),
          _file(''),
          _file('p' * 1100),
        ],
        records: [_record(locator: 'valid.json#/messages/0')],
      ),
    );

    // The path column clips an over-long value, so that file still lands with
    // a bounded path. The empty path is required and costs only its own row.
    expect(outcome.sourceFiles, 2);
    expect(outcome.events, 1);
    expect(outcome.skippedRecords, 1);
    expect(outcome.warnings.single, contains('field=source_files.relative_path'));
    expect(outcome.warnings.single, contains('bound=minimum'));

    final files = await database.select(database.sourceFiles).get();
    expect(files.map((file) => file.relativePath), contains('valid.json'));
    expect(
      files.map((file) => file.relativePath.length),
      containsAll(<int>[10, 1024]),
    );
    await _expectStoredTextWithinBounds(database);
  });

  test('people are written verbatim or clipped, and a blank one is skipped', () async {
    final longName = 'n' * 900;
    final outcome = await importPreview(
      _preview(
        files: [_file('valid.json')],
        records: [
          _record(locator: 'valid.json#/messages/0', senderName: ''),
          _record(locator: 'valid.json#/messages/1', senderName: longName),
          _record(locator: 'valid.json#/messages/2', senderName: ' Ada '),
        ],
      ),
    );

    expect(outcome.events, 3);
    expect(outcome.people, 2);
    expect(outcome.skippedRecords, 1);
    expect(
      outcome.warnings.single,
      allOf(
        contains('field=people.display_name'),
        contains('bound=minimum'),
      ),
    );

    final people = await database.select(database.people).get();
    expect(people, hasLength(2));
    expect(
      people.map((person) => person.displayName),
      containsAll(<String>[' Ada ', longName.substring(0, 512)]),
    );
    await _expectStoredTextWithinBounds(database);
  });

  test('conversation ids clip and titles trim, null or clip within their column', () async {
    final outcome = await importPreview(
      _preview(
        files: [_file('valid.json')],
        records: [
          _record(
            locator: 'valid.json#/messages/0',
            conversationKey: 'k' * 300,
            conversationTitle: '  Thread  ',
          ),
          _record(
            locator: 'valid.json#/messages/1',
            conversationKey: 'k2',
            conversationTitle: '',
          ),
          _record(
            locator: 'valid.json#/messages/2',
            conversationKey: 'k3',
            conversationTitle: 't' * 600,
          ),
        ],
      ),
    );

    expect(outcome.conversations, 3);
    expect(outcome.events, 3);
    expect(outcome.skippedRecords, 0);

    final conversations = await (database.select(
      database.conversations,
    )..orderBy([(table) => OrderingTerm.asc(table.id)])).get();
    expect(conversations, hasLength(3));
    expect(conversations[0].sourceConversationId, 'k' * 128);
    expect(conversations[0].title, 'Thread');
    expect(conversations[1].title, isNull);
    expect(conversations[2].title, hasLength(512));
    await _expectStoredTextWithinBounds(database);
  });

  test('event text is stored, emptied or skipped at its declared bound', () async {
    final outcome = await importPreview(
      _preview(
        files: [_file('valid.json')],
        records: [
          _record(locator: 'valid.json#/messages/0', text: ''),
          _record(locator: 'valid.json#/messages/1', text: 'kept'),
          _record(locator: 'valid.json#/messages/2', text: 'x' * 100001),
        ],
      ),
    );

    expect(outcome.events, 2);
    expect(outcome.skippedRecords, 1);
    expect(
      outcome.warnings.single,
      allOf(
        contains('field=events.text_content'),
        contains('bound=maximum'),
      ),
    );

    final events = await (database.select(
      database.events,
    )..orderBy([(table) => OrderingTerm.asc(table.id)])).get();
    expect(events.map((event) => event.textContent), [null, 'kept']);
    await _expectStoredTextWithinBounds(database);
  });

  test('attachment metadata is clipped or skipped, and stays in bounds', () async {
    final outcome = await importPreview(
      _preview(
        files: [
          _file('valid.json'),
          _file('media.jpg', reason: ImportCoverageReason.unsupportedMedia),
        ],
        records: [_record(locator: 'valid.json#/messages/0')],
        attachments: [
          _attachment(mediaType: 'image'),
          _attachment(mediaType: ''),
          _attachment(mediaType: 'm' * 200),
          _attachment(mediaType: 'file', contentHash: 'h' * 200),
        ],
      ),
    );

    expect(outcome.attachments, 3);
    expect(outcome.skippedRecords, 1);
    expect(
      outcome.warnings.single,
      allOf(
        contains('field=attachments.media_type'),
        contains('bound=minimum'),
      ),
    );

    final attachments = await (database.select(
      database.attachments,
    )..orderBy([(table) => OrderingTerm.asc(table.id)])).get();
    expect(attachments, hasLength(3));
    expect(attachments.map((attachment) => attachment.mediaType), [
      'image',
      'm' * 128,
      'file',
    ]);
    expect(attachments.last.contentHash, hasLength(128));
    await _expectStoredTextWithinBounds(database);
  });
}

/// Every non-null text value stored in the workspace fits its declared bounds.
///
/// The names come from [ImportTextColumns], never from user input, so the
/// generated SQL has no untrusted identifiers.
Future<void> _expectStoredTextWithinBounds(AppDatabase database) async {
  for (final spec in ImportTextColumns.all) {
    final rows = await database
        .customSelect(
          'SELECT ${spec.column} AS stored_value FROM ${spec.table}',
        )
        .get();
    for (final row in rows) {
      final value = row.readNullable<String>('stored_value');
      if (value == null) {
        expect(
          spec.nullable,
          isTrue,
          reason: '${spec.field} stored null in a required column',
        );
        continue;
      }
      expect(
        value.length,
        greaterThanOrEqualTo(spec.min),
        reason: '${spec.field} stored a value below its declared minimum',
      );
      expect(
        value.length,
        lessThanOrEqualTo(spec.max),
        reason: '${spec.field} stored a value above its declared maximum',
      );
    }
  }
}

FacebookImportPreview _preview({
  required List<ImportCoverageEntry> files,
  required List<FacebookRecord> records,
  List<FacebookAttachmentMetadata> attachments = const [],
}) {
  final inspection = ArchiveInspection(
    entries: files.length,
    totalExpandedBytes: 0,
    jsonFiles: files.where((file) => file.sourceType == 'json').length,
    mediaFiles: files.where((file) => file.sourceType == 'media').length,
    ignoredFiles: 0,
    warnings: const [],
  );
  return FacebookImportPreview(
    archiveInspection: inspection,
    scan: ArchiveScan(
      inspection: inspection,
      jsonFiles: const [],
      entries: const [],
    ),
    records: records,
    files: [
      for (final file in files)
        if (file.relativePath != null)
          FacebookPreviewFile(
            path: file.relativePath!,
            status: file.supported
                ? FacebookPreviewFileStatus.parsed
                : FacebookPreviewFileStatus.unsupported,
          ),
    ],
    coverage: ImportCoverageReport(entries: files),
    supportedFiles: files.where((file) => file.supported).length,
    unsupportedJsonFiles: 0,
    knownNotImportedJsonFiles: 0,
    skippedRecords: 0,
    warnings: const [],
    attachments: attachments,
  );
}

ImportCoverageEntry _file(
  String path, {
  ImportCoverageReason reason = ImportCoverageReason.supported,
}) => ImportCoverageEntry(
  relativePath: path,
  sourceType: reason == ImportCoverageReason.unsupportedMedia
      ? 'media'
      : 'json',
  supported: reason == ImportCoverageReason.supported,
  reason: reason,
);

FacebookRecord _record({
  required String locator,
  String? senderName = 'Valid',
  String? text = 'hello',
  String? conversationKey,
  String? conversationTitle,
}) => FacebookRecord(
  eventType: 'message',
  sourcePath: 'valid.json',
  sourceLocator: locator,
  senderName: senderName,
  text: text,
  timestampRaw: '1600000000000',
  timestampUtc: DateTime.fromMillisecondsSinceEpoch(
    1600000000000,
    isUtc: true,
  ),
  conversationKey: conversationKey,
  conversationTitle: conversationTitle,
);

FacebookAttachmentMetadata _attachment({
  required String mediaType,
  String? contentHash,
  String relativePath = 'media.jpg',
  String sourceLocator = 'valid.json#/messages/0',
}) => FacebookAttachmentMetadata(
  sourceLocator: sourceLocator,
  relativePath: relativePath,
  mediaType: mediaType,
  sizeBytes: 3,
  contentHash: contentHash,
);

/// Returns one fixed preview through the coordinator's real write pipeline.
class _PresetImporter extends FacebookJsonImporter {
  _PresetImporter(this.previewData);

  final FacebookImportPreview previewData;

  @override
  Future<FacebookImportPreview> previewSource(String path) async =>
      previewData;
}
