import 'package:drift/drift.dart';

import '../../domain/models/import_record.dart';
import '../../domain/models/source_file.dart';
import '../database/app_database.dart';

/// One stored import together with the source files recorded for it.
class StoredImport {
  const StoredImport({required this.importRecord, required this.sourceFiles});

  final ImportRecord importRecord;
  final List<SourceFileRecord> sourceFiles;
}

/// Reads and writes imports and their source files.
///
/// Rows are converted to domain models here, so no Drift type leaves this
/// layer. Writes happen in a single transaction: an import without its source
/// files is never visible.
class ImportRepository {
  const ImportRepository(this._database);

  final AppDatabase _database;

  /// Inserts [record] and [files] in one transaction and returns the new
  /// import id. Any `importId` set on the drafts is ignored: every file is
  /// linked to the import inserted by this call.
  Future<int> insertImport(
    ImportRecord record,
    List<SourceFileRecord> files,
  ) {
    return _database.transaction(() async {
      final importId = await _database.into(_database.imports).insert(
            ImportsCompanion.insert(
              platform: record.platform,
              format: record.format,
              sourceFingerprint: record.sourceFingerprint,
              // Timestamps are stored as UTC instants; drift stores them as
              // unix seconds, which carry no timezone of their own.
              startedAt: record.startedAt.toUtc(),
              importerVersion: record.importerVersion,
              status: record.status,
              completedAt: Value(record.completedAt?.toUtc()),
            ),
          );

      for (final file in files) {
        await _database.into(_database.sourceFiles).insert(
              SourceFilesCompanion.insert(
                importId: importId,
                relativePath: file.relativePath,
                parseStatus: file.parseStatus,
                mediaType: Value(file.mediaType),
                contentHash: Value(file.contentHash),
                errorCode: Value(file.errorCode),
              ),
            );
      }

      return importId;
    });
  }

  /// Reads one import and its source files, ordered by archive path.
  Future<StoredImport?> findImport(int id) async {
    final row = await (_database.select(_database.imports)
          ..where((table) => table.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;

    final fileRows = await (_database.select(_database.sourceFiles)
          ..where((table) => table.importId.equals(id))
          ..orderBy([(table) => OrderingTerm.asc(table.relativePath)]))
        .get();

    return StoredImport(
      importRecord: ImportRecord(
        id: row.id,
        platform: row.platform,
        format: row.format,
        sourceFingerprint: row.sourceFingerprint,
        startedAt: row.startedAt.toUtc(),
        completedAt: row.completedAt?.toUtc(),
        importerVersion: row.importerVersion,
        status: row.status,
      ),
      sourceFiles: [
        for (final file in fileRows)
          SourceFileRecord(
            id: file.id,
            importId: file.importId,
            relativePath: file.relativePath,
            mediaType: file.mediaType,
            contentHash: file.contentHash,
            parseStatus: file.parseStatus,
            errorCode: file.errorCode,
          ),
      ],
    );
  }
}
