import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import '../../core/errors/import_report.dart';
import '../../core/logging/redacted_log.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../domain/models/attachment.dart';
import '../../domain/models/event_record.dart';
import '../../domain/models/import_record.dart';
import '../../domain/models/source_file.dart';
import 'archive_inspector.dart';
import 'facebook_json_importer.dart';
import 'import_coverage_report.dart';
import 'import_progress.dart';
import 'import_text_normalizer.dart';
import 'telegram_json_importer.dart';
import 'whatsapp_import_adapter.dart';

/// What one [ImportCoordinator.importArchive] call produced.
sealed class ImportResult {
  const ImportResult();
}

/// What one completed [ImportCoordinator.importArchive] call persisted.
class ImportOutcome implements ImportResult {
  const ImportOutcome({
    required this.importId,
    required this.reusedExistingImport,
    required this.sourceFiles,
    required this.events,
    required this.people,
    required this.conversations,
    required this.attachments,
    required this.skippedRecords,
    required this.warnings,
  });

  final int importId;

  /// True when the archive fingerprint was already imported, so the existing
  /// import was returned and nothing was written.
  final bool reusedExistingImport;

  final int sourceFiles;
  final int events;
  final int people;
  final int conversations;

  /// Media references stored as attachment metadata; no media bytes.
  final int attachments;

  /// Records the importer refused, counted instead of guessed.
  final int skippedRecords;

  final List<String> warnings;
}

/// The typed result of an import the caller cancelled.
///
/// The transaction was rolled back and any staging was deleted, so no row of
/// this archive exists. It is a result rather than an exception: cancelling is
/// a normal outcome, and it leaks no internal error or path.
class ImportCancelled implements ImportResult {
  const ImportCancelled({
    required this.phase,
    this.filesDone = 0,
    this.filesTotal = 0,
    this.recordsWritten = 0,
  });

  /// The phase the import was in when the token was seen as cancelled.
  final ImportPhase phase;

  final int filesDone;
  final int filesTotal;
  final int recordsWritten;

  /// Always 0: a cancelled import commits nothing.
  int get rowsWritten => 0;
}

/// A failure that happened while persisting an import. Validation failures
/// keep their own types ([ArchiveInspectionException],
/// [FacebookImportException]) so callers can tell them apart.
class ImportException implements CodedException {
  const ImportException(this.code, this.message, [this.cause]);

  @override
  final String code;
  final String message;
  final Object? cause;

  @override
  String toString() => 'ImportException($code): $message';
}

/// A record the writer could not store, named so the import screen can say why.
const String _unattributableRecordWarning = 'record_without_source_file';

/// Turns an archive on disk into persisted rows: scan, parse, then write.
///
/// Every row of one import is written in a single transaction, so a failure or
/// a cancellation leaves the database exactly as it was. Nothing is extracted
/// to disk: the archive is read in memory, so staging holds no archive bytes;
/// a staging directory handed in is deleted when an import does not complete.
class ImportCoordinator {
  ImportCoordinator({
    required this.database,
    ExportInspector inspector = const ExportInspector(),
    FacebookJsonImporter? importer,
    this.importerVersion = '0.1.0',
    this.stagingDirectory,
    this.log = const RedactedLog(),
    this.platform = 'facebook',
    this.format = 'json',
  }) : inspector = inspector,
       importer = importer ?? FacebookJsonImporter(sourceInspector: inspector);

  final AppDatabase database;

  /// Records one content-free event per import outcome, so an operator can
  /// follow the pipeline. Pass a sink to capture events in a test.
  final RedactedLog log;
  final ExportInspector inspector;
  final FacebookJsonImporter importer;

  /// Optional scratch directory owned by this coordinator. It never holds
  /// archive content, and it is deleted when an import is cancelled or fails.
  final Directory? stagingDirectory;

  final StreamController<ImportProgress> _progressController =
      StreamController<ImportProgress>.broadcast();

  /// Progress of the import currently running, and of any later one.
  ///
  /// Events are archive-relative and content-free. A broadcast stream is used
  /// so several listeners (a screen and a log) can observe the same import.
  Stream<ImportProgress> get progress => _progressController.stream;

  /// Releases the progress stream. The coordinator is unusable afterwards.
  Future<void> dispose() => _progressController.close();

  /// Attachment metadata is written through this repository, inside the import
  /// transaction.
  late final AttachmentRepository attachmentRepository = AttachmentRepository(
    database,
  );

  /// Recorded on every import so results stay explainable.
  final String importerVersion;

  ImportCoverageReport? _lastCoverageReport;

  /// Coverage of the most recent [importArchive] call: per-file classification
  /// and totals. It is also produced for an archive that was rejected, so a
  /// blocked import still reports why. No file content and no host path is
  /// ever part of it.
  ImportCoverageReport? get lastCoverageReport => _lastCoverageReport;

  static const String telegramPlatform = 'telegram';

  /// Source platform recorded on imported rows. Facebook by default;
  /// Instagram DM imports use the same schema and writer with `instagram`.
  final String platform;
  final String format;

  /// Telegram's export names this single file; it may sit at the archive root
  /// or inside the export folder, so the pattern matches on the file name.
  static const String _telegramFilePattern = r'(^|/)result\.json$';

  /// How many events are written between cancellation checks.
  static const int _writeBatchSize = 50;

  /// Imports [archive] and returns what was written.
  ///
  /// Re-importing the same archive (same SHA-256 fingerprint) returns the
  /// existing import instead of creating a second one. When [cancelToken] is
  /// cancelled, parsing or writing stops at the next file or record batch and
  /// an [ImportCancelled] result is returned: the transaction rolls back and
  /// staging is deleted, so nothing of this archive is left in the database.
  Future<ImportResult> importArchive(
    File archive, {
    CancelToken? cancelToken,
  }) => importSource(archive.path, cancelToken: cancelToken);

  /// Imports a ZIP archive or an already-extracted folder at [path].
  /// Imports a ZIP that is already in memory, which is what the browser build
  /// receives from its file picker.
  Future<ImportResult> importArchiveBytes(
    Uint8List bytes, {
    CancelToken? cancelToken,
  }) => importSource('', archiveBytes: bytes, cancelToken: cancelToken);

  /// Imports a Telegram `result.json`, or a ZIP/folder containing one.
  ///
  /// Parsing is the pure [TelegramJsonImporter]; persistence goes through the
  /// same transaction as a Facebook import, only with `platform = telegram`.
  Future<ImportResult> importTelegramSource(
    String path, {
    CancelToken? cancelToken,
    Uint8List? archiveBytes,
  }) async {
    final source = await _telegramResultFile(path, archiveBytes);
    final records = const TelegramJsonImporter().toRecords(
      source.chat,
      sourcePath: source.path,
    );
    if (records.isEmpty) throw _noTelegramFile;
    return importSource(
      path,
      archiveBytes: archiveBytes,
      cancelToken: cancelToken,
      previewOverride: _telegramPreview(
        chat: source.chat,
        sourcePath: source.path,
        byteLength: source.bytes.length,
        records: records,
      ),
      platformOverride: telegramPlatform,
    );
  }

  static const FacebookImportException _noTelegramFile = FacebookImportException(
    'no_supported_files_found',
    'No Telegram result.json chat was found.',
  );

  static const int _maxTelegramJsonBytes = 256 * 1024 * 1024;
  static const int _maxTelegramJsonFileBytes = 128 * 1024 * 1024;

  /// Locates and decodes the one `result.json` a Telegram export carries.
  /// A bare JSON file is read directly; a ZIP or folder goes through the same
  /// validated inspector Facebook uses, so no entry is blindly extracted.
  Future<({TelegramChat chat, Uint8List bytes, String path})>
  _telegramResultFile(String path, Uint8List? archiveBytes) async {
    final Uint8List bytes;
    final String sourcePath;
    if (archiveBytes != null) {
      final scan = await inspector.scanJsonBytes(
        archiveBytes,
        maxJsonBytes: _maxTelegramJsonBytes,
        maxJsonFileBytes: _maxTelegramJsonFileBytes,
        jsonPathPattern: _telegramFilePattern,
      );
      final file = scan.jsonFiles.firstOrNull;
      if (file == null) throw _noTelegramFile;
      bytes = file.bytes;
      sourcePath = file.path;
    } else if (path.toLowerCase().endsWith('.json')) {
      final file = File(path);
      if (!await file.exists()) throw _noTelegramFile;
      bytes = await file.readAsBytes();
      sourcePath = path.split(RegExp(r'[\\/]')).last;
    } else {
      final scan = await inspector.scanJsonFiles(
        path,
        maxJsonBytes: _maxTelegramJsonBytes,
        maxJsonFileBytes: _maxTelegramJsonFileBytes,
        jsonPathPattern: _telegramFilePattern,
      );
      final file = scan.jsonFiles.firstOrNull;
      if (file == null) throw _noTelegramFile;
      bytes = file.bytes;
      sourcePath = file.path;
    }
    return (
      chat: const TelegramJsonImporter().parseBytes(bytes),
      bytes: bytes,
      path: sourcePath,
    );
  }

  /// Builds the preview the existing write path expects, from one chat.
  FacebookImportPreview _telegramPreview({
    required TelegramChat chat,
    required String sourcePath,
    required int byteLength,
    required List<FacebookRecord> records,
  }) {
    final inspection = ArchiveInspection(
      entries: 1,
      totalExpandedBytes: byteLength,
      jsonFiles: 1,
      mediaFiles: 0,
      ignoredFiles: 0,
      warnings: const [],
    );
    final scan = ArchiveScan(
      inspection: inspection,
      jsonFiles: const [],
      entries: [
        InspectedArchiveEntry(
          relativePath: sourcePath,
          size: byteLength,
          isDirectory: false,
          isMedia: false,
        ),
      ],
    );
    final coverage = ImportCoverageReport(entries: [
      ImportCoverageEntry(
        relativePath: sourcePath,
        sourceType: 'json',
        supported: true,
        reason: ImportCoverageReason.supported,
        recordsParsed: records.length,
        recordsSkipped: chat.skipped,
      ),
    ]);
    return FacebookImportPreview(
      archiveInspection: inspection,
      scan: scan,
      records: List.unmodifiable(records),
      files: [
        FacebookPreviewFile(
          path: sourcePath,
          status: FacebookPreviewFileStatus.parsed,
          recordsParsed: records.length,
          recordsSkipped: chat.skipped,
        ),
      ],
      coverage: coverage,
      supportedFiles: 1,
      unsupportedJsonFiles: 0,
      knownNotImportedJsonFiles: 0,
      skippedRecords: chat.skipped,
      warnings: const [],
    );
  }

  Future<ImportResult> importSource(
    String path, {
    CancelToken? cancelToken,
    Uint8List? archiveBytes,
    FacebookImportPreview? previewOverride,
    String? platformOverride,
  }) async {
    final importPlatform = platformOverride ?? platform;
    final inMemory = archiveBytes != null;
    _lastCoverageReport = null;
    _emit(const ImportProgress(phase: ImportPhase.inspecting));
    log.event('import.started', {
      'platform': importPlatform,
      'format': format,
      'importerVersion': importerVersion,
      'sourceKind': ExportInspector.isFolder(path) ? 'folder' : 'archive',
    });
    if (cancelToken?.isCancelled ?? false) {
      return _cancelledResult(ImportPhase.inspecting);
    }

    // Hashing streams the file, so the archive is not read twice. A folder is
    // walked here, so its walk can reject the import before anything is read
    // for parsing; that rejection is reported the same way a scan rejection is.
    final String fingerprint;
    final int? existingImportId;
    try {
      fingerprint = inMemory
          ? 'sha256:${sha256.convert(archiveBytes)}'
          : await _fingerprint(path);
      existingImportId = await _importIdForFingerprint(fingerprint);
    } on ArchiveInspectionException catch (error) {
      _lastCoverageReport = ImportCoverageReport.blocked(
        ImportCoverageReason.forInspectionCode(error.code),
      );
      log.failure(
        'import.failed',
        code: error.code,
        error: error,
        fields: {'phase': ImportPhase.inspecting.name},
      );
      rethrow;
    } on Object catch (error) {
      // The source can vanish or become unreadable between selection and
      // hashing, and the duplicate lookup reads the database. Either failure
      // happens before validation and must still leave a failure record.
      _recordUnexpectedFailure(error, ImportPhase.inspecting);
      rethrow;
    }

    if (existingImportId != null) {
      // A reused import is already complete, so cancelling here changes
      // nothing; it still reports the stored totals as completed.
      final ImportOutcome outcome;
      final ImportCoverageReport coverage;
      try {
        outcome = await _outcomeForExisting(existingImportId);
        coverage = await _reportForExistingImport(existingImportId);
      } on Object catch (error) {
        _recordUnexpectedFailure(error, ImportPhase.inspecting);
        rethrow;
      }
      _lastCoverageReport = coverage;
      _emit(
        ImportProgress(
          phase: ImportPhase.completed,
          filesDone: outcome.sourceFiles,
          filesTotal: outcome.sourceFiles,
          recordsWritten: outcome.events,
        ),
      );
      log.event('import.deduplicated', {
        'platform': importPlatform,
        'importId': outcome.importId,
        'sourceFiles': outcome.sourceFiles,
        'events': outcome.events,
        'conversations': outcome.conversations,
        'attachments': outcome.attachments,
      });
      return outcome;
    }

    // Validation and parsing happen before the transaction, so a rejected
    // archive never touches the database. A rejected archive is still
    // reported, with its reason code and no path.
    _emit(const ImportProgress(phase: ImportPhase.parsing));
    final FacebookImportPreview preview;
    try {
      preview = previewOverride ??
          (inMemory
              ? await importer.previewArchiveBytes(archiveBytes)
              : await importer.previewSource(path));
    } on ArchiveInspectionException catch (error) {
      _lastCoverageReport = ImportCoverageReport.blocked(
        ImportCoverageReason.forInspectionCode(error.code),
      );
      log.failure(
        'import.failed',
        code: error.code,
        error: error,
        fields: {'phase': ImportPhase.parsing.name},
      );
      rethrow;
    } on FacebookImportException catch (error) {
      _lastCoverageReport = ImportCoverageReport.blocked(
        ImportCoverageReason.forImportCode(error.code),
      );
      log.failure(
        'import.failed',
        code: error.code,
        error: error,
        fields: {'phase': ImportPhase.parsing.name},
      );
      rethrow;
    } on Object catch (error) {
      // An unexpected error while reading the source is still a failure of this
      // import; record it before it leaves the pipeline.
      _recordUnexpectedFailure(error, ImportPhase.parsing);
      rethrow;
    }

    // The preview owns the per-file classification, so the stored report and
    // the on-screen preview cannot disagree about a file.
    final report = preview.coverage;
    _lastCoverageReport = report;
    if (preview.supportedFiles == 0) {
      throw const FacebookImportException(
        'no_supported_files_found',
        'No supported Facebook export files were found.',
      );
    }

    // The parse itself runs in one isolate call, so cancellation is checked at
    // every file boundary the preview reports, before any write begins.
    final filesTotal = preview.files.length;
    var filesDone = 0;
    for (final file in preview.files) {
      if (cancelToken?.isCancelled ?? false) {
        await _discardStaging();
        return _cancelledResult(
          ImportPhase.parsing,
          filesDone: filesDone,
          filesTotal: filesTotal,
        );
      }
      filesDone++;
      _emit(
        ImportProgress(
          phase: ImportPhase.parsing,
          filesDone: filesDone,
          filesTotal: filesTotal,
          currentRelativePath: file.path,
        ),
      );
    }

    return _persistPreview(
      preview: preview,
      fingerprint: fingerprint,
      importPlatform: importPlatform,
      format: format,
      cancelToken: cancelToken,
    );
  }

  /// Imports a WhatsApp `.txt` chat export, or a ZIP whose `_chat.txt` entries
  /// are the chat logs. Nothing outside the chosen source is read.
  Future<ImportResult> importWhatsAppText(
    String path, {
    CancelToken? cancelToken,
  }) async {
    final fingerprint = await _fingerprint(path);
    return _persistWhatsApp(
      fingerprint: fingerprint,
      chats: await _whatsAppChatsFromPath(path),
      cancelToken: cancelToken,
    );
  }

  /// Same import for bytes handed over by a browser picker: raw `.txt` bytes
  /// or a ZIP, told apart by the ZIP signature (no extension guessing).
  Future<ImportResult> importWhatsAppTextBytes(
    Uint8List bytes, {
    CancelToken? cancelToken,
  }) async {
    final fingerprint = 'sha256:${sha256.convert(bytes)}';
    final isZip = bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4b &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
    final chats = isZip
        ? await _whatsAppChatsFromScan(
            await inspector.scanJsonBytes(bytes, jsonPathPattern: _chatPattern),
          )
        : {'chat.txt': utf8.decode(bytes, allowMalformed: true)};
    return _persistWhatsApp(
      fingerprint: fingerprint,
      chats: chats,
      cancelToken: cancelToken,
    );
  }

  static const String _chatPattern = r'\.txt$';

  Future<Map<String, String>> _whatsAppChatsFromPath(String path) async {
    if (path.toLowerCase().endsWith('.txt')) {
      final name = path.split(RegExp(r'[\\/]')).last;
      return {
        name: utf8.decode(await File(path).readAsBytes(), allowMalformed: true),
      };
    }
    return _whatsAppChatsFromScan(
      await inspector.scanJsonFiles(path, jsonPathPattern: _chatPattern),
    );
  }

  /// Reuses the validated ZIP scan; only `.txt` entries are decoded, never
  /// media. The scan enforces the same quarantine rules as a Facebook ZIP.
  Future<Map<String, String>> _whatsAppChatsFromScan(ArchiveScan scan) => Isolate.run(
    () => {
      for (final file in scan.jsonFiles)
        file.path: utf8.decode(file.bytes, allowMalformed: true),
    },
  );

  Future<ImportResult> _persistWhatsApp({
    required String fingerprint,
    required Map<String, String> chats,
    CancelToken? cancelToken,
  }) async {
    log.event('import.started', {
      'platform': whatsappPlatform,
      'format': whatsappTxtFormat,
      'importerVersion': importerVersion,
      'sourceFiles': chats.length,
    });
    final existingId = await _importIdForFingerprint(fingerprint);
    if (existingId != null) {
      return _outcomeForExisting(existingId);
    }
    final preview = const WhatsAppImportAdapter().preview(chats);
    _lastCoverageReport = preview.coverage;
    if (preview.supportedFiles == 0) {
      throw const FacebookImportException(
        'no_supported_files_found',
        'No WhatsApp chat files were found.',
      );
    }
    for (final file in preview.files) {
      if (cancelToken?.isCancelled ?? false) {
        await _discardStaging();
        return _cancelledResult(ImportPhase.parsing);
      }
      _emit(
        ImportProgress(
          phase: ImportPhase.parsing,
          filesDone: 1,
          filesTotal: preview.files.length,
          currentRelativePath: file.path,
        ),
      );
    }
    return _persistPreview(
      preview: preview,
      fingerprint: fingerprint,
      importPlatform: whatsappPlatform,
      format: whatsappTxtFormat,
      cancelToken: cancelToken,
    );
  }

  /// The single write transaction shared by Facebook and WhatsApp imports.
  Future<ImportResult> _persistPreview({
    required FacebookImportPreview preview,
    required String fingerprint,
    required String importPlatform,
    required String format,
    CancelToken? cancelToken,
  }) async {
    final report = preview.coverage;
    try {
      final writeWarnings = <String>{};
      final outcome = await database.transaction(() async {
        final importId = await database
            .into(database.imports)
            .insert(
              ImportsCompanion.insert(
                platform: importPlatform,
                format: format,
                sourceFingerprint: fingerprint,
                startedAt: DateTime.now().toUtc(),
                completedAt: Value(DateTime.now().toUtc()),
                importerVersion: importerVersion,
                status: ImportStatus.completed,
                coverageJson: Value(
                  normalizeImportText(
                    jsonEncode(report.counts),
                    ImportTextColumns.importsCoverageJson,
                  ).value,
                ),
              ),
            );

        final sourceFiles = await _writeSourceFiles(
          importId,
          report,
          cancelToken: cancelToken,
          warnings: writeWarnings,
        );
        final people = await _writePeople(
          preview,
          importPlatform: importPlatform,
          warnings: writeWarnings,
        );
        final conversations = await _writeConversations(
          importId,
          preview,
          warnings: writeWarnings,
        );
        final events = await _writeEvents(
          importId: importId,
          preview: preview,
          importPlatform: importPlatform,
          sourceFileIds: sourceFiles.ids,
          personIds: people.ids,
          conversationIds: conversations.ids,
          cancelToken: cancelToken,
          filesTotal: sourceFiles.ids.length,
          warnings: writeWarnings,
        );
        final attachments = await _writeAttachments(
          preview: preview,
          sourceFileIds: sourceFiles.ids,
          eventIds: events.ids,
          cancelToken: cancelToken,
          filesTotal: sourceFiles.ids.length,
          warnings: writeWarnings,
        );

        return ImportOutcome(
          importId: importId,
          reusedExistingImport: false,
          sourceFiles: sourceFiles.ids.length,
          events: events.ids.length,
          people: people.ids.length,
          conversations: conversations.ids.length,
          attachments: attachments.stored,
          skippedRecords:
              preview.skippedRecords +
              sourceFiles.skipped +
              people.skipped +
              conversations.skipped +
              events.skipped +
              attachments.skipped,
          warnings: [...preview.warnings, ...writeWarnings],
        );
      });
      _emit(
        ImportProgress(
          phase: ImportPhase.completed,
          filesDone: outcome.sourceFiles,
          filesTotal: outcome.sourceFiles,
          recordsWritten: outcome.events,
        ),
      );
      log.event('import.completed', {
        'platform': importPlatform,
        'importerVersion': importerVersion,
        'importId': outcome.importId,
        'sourceFiles': outcome.sourceFiles,
        'events': outcome.events,
        'people': outcome.people,
        'conversations': outcome.conversations,
        'attachments': outcome.attachments,
        'skippedRecords': outcome.skippedRecords,
        'warnings': outcome.warnings.length,
      });
      return outcome;
    } on _ImportCancelledSignal catch (signal) {
      // Drift rolled the transaction back, so the database holds no row of
      // this archive. Staging is deleted for the same reason: no partial work.
      await _discardStaging();
      return _cancelledResult(
        signal.phase,
        filesDone: signal.filesDone,
        filesTotal: signal.filesTotal,
        recordsWritten: 0,
      );
    } on ImportException catch (error) {
      await _discardStaging();
      _emit(const ImportProgress(phase: ImportPhase.cancelled));
      log.failure(
        'import.failed',
        code: error.code,
        error: error,
        fields: {'phase': ImportPhase.writing.name},
      );
      rethrow;
    } on Object catch (error) {
      // The transaction is rolled back by drift on any throw, so the database
      // holds nothing from this archive.
      await _discardStaging();
      _emit(const ImportProgress(phase: ImportPhase.cancelled));
      // One opaque code hid every cause behind "it did not save", which cost
      // days of guessing. The code now names what failed, so the import screen
      // can say it and the next report is a diagnosis instead of a riddle.
      final code = _writeFailureCode(error);
      log.failure(
        'import.failed',
        code: code,
        error: error,
        fields: {'phase': ImportPhase.writing.name},
      );
      throw ImportException(
        code,
        'The import could not be written; nothing was saved.',
        error,
      );
    }
  }

  /// Names the failure that stopped the write, without leaking its message.
  ///
  /// [error]'s text is never shown to the user (it can carry a path or a
  /// value); the class and, for SQLite, the result code decide the name.
  static String _writeFailureCode(Object error) {
    // A native database runs on its own isolate, so drift wraps the original
    // SQLite error in [DriftRemoteException]. Unwrap it before classifying.
    final cause = error is DriftRemoteException ? error.remoteCause : error;
    if (cause is InvalidDataException) return 'import_write_invalid_value';
    if (cause is SqliteException) {
      final text = cause.message.toLowerCase();
      if (text.contains('unique') || text.contains('constraint')) {
        return 'import_write_conflict';
      }
      if (cause.extendedResultCode == 5 || cause.extendedResultCode == 6) {
        return 'import_write_busy';
      }
      if (cause.resultCode == 13 || text.contains('disk is full')) {
        return 'import_disk_full';
      }
      return 'import_write_failed';
    }
    if (cause is FileSystemException) return 'import_write_io_error';
    return 'import_write_failed';
  }

  /// Writes one row, turning a value the schema refuses into a skipped row.
  ///
  /// drift throws before the statement runs when a declared text bound fails;
  /// SQLite throws while the statement runs for a constraint. Both are local
  /// to this row, and neither may roll the whole archive back. Disk-full,
  /// busy, I/O and other infrastructure failures are not caught here, so the
  /// surrounding transaction still aborts and leaves nothing behind.
  Future<T?> _writeSkippingBadRecord<T>({
    required Future<T> Function() write,
    required String relativePath,
    required ImportTextColumn column,
    required Set<String> warnings,
    required void Function() onSkipped,
  }) async {
    try {
      return await write();
    } on Exception catch (error) {
      if (!_isSkippableRowFailure(error)) rethrow;
      onSkipped();
      warnings.add(
        importRecordSkippedWarningFor(
          relativePath: relativePath,
          column: column,
          field: _failedFieldOf(error),
        ),
      );
      return null;
    }
  }

  /// The schema field SQLite named when it refused the row, or null when its
  /// message does not name a registered column.
  ///
  /// SQLite's message carries identifiers such as `events.text_content`, never
  /// values, and a match is accepted only when it is a field of
  /// [ImportTextColumns]. The message itself is never stored or shown.
  static String? _failedFieldOf(Object error) {
    final cause = error is DriftRemoteException ? error.remoteCause : error;
    if (cause is! SqliteException) return null;
    final match = _constraintColumn.firstMatch(cause.message);
    if (match == null) return null;
    return ImportTextColumns.byField(match.group(1)!, match.group(2)!)?.field;
  }

  /// A constraint message's `table.column`, e.g. `events.text_content`.
  static final RegExp _constraintColumn = RegExp(
    r'constraint failed:\s*([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)',
  );

  /// Whether [error] belongs to one row and may be skipped.
  ///
  /// A trigger's `RAISE(ABORT)` (1811), a busy database or a disk/IO failure is
  /// deliberately absent: those are infrastructure failures, must abort the
  /// transaction and still roll the whole import back.
  static bool _isSkippableRowFailure(Object error) {
    if (error is InvalidDataException) return true;

    final cause = error is DriftRemoteException ? error.remoteCause : error;
    if (cause is! SqliteException) return false;
    const rowFailures = {
      275, // SQLITE_CONSTRAINT_CHECK
      787, // SQLITE_CONSTRAINT_FOREIGNKEY
      1299, // SQLITE_CONSTRAINT_NOTNULL
      1555, // SQLITE_CONSTRAINT_PRIMARYKEY
      2067, // SQLITE_CONSTRAINT_UNIQUE
    };
    return rowFailures.contains(cause.extendedResultCode);
  }

  /// The first rejected value in [values], or null when all fit.
  static ImportTextRejected? _firstRejection(
    Iterable<NormalizedImportText> values,
  ) {
    for (final value in values) {
      final rejection = value.rejection;
      if (rejection != null) return rejection;
    }
    return null;
  }

  void _emit(ImportProgress progress) {
    if (!_progressController.isClosed) _progressController.add(progress);
  }

  ImportCancelled _cancelledResult(
    ImportPhase phase, {
    int filesDone = 0,
    int filesTotal = 0,
    int recordsWritten = 0,
  }) {
    log.event('import.cancelled', {
      'phase': phase.name,
      'filesDone': filesDone,
      'filesTotal': filesTotal,
      'recordsWritten': recordsWritten,
    });
    _emit(
      ImportProgress(
        phase: ImportPhase.cancelled,
        filesDone: filesDone,
        filesTotal: filesTotal,
        recordsWritten: recordsWritten,
      ),
    );
    return ImportCancelled(
      phase: phase,
      filesDone: filesDone,
      filesTotal: filesTotal,
      recordsWritten: recordsWritten,
    );
  }

  /// Records a failure that no typed handler covered, with a stable code.
  ///
  /// The source fingerprint, the duplicate lookup and the preview all run
  /// before the write transaction. A missing or unreadable source, a database
  /// read error, or any other unexpected error here still leaves an
  /// `import.failed` record with its phase, so an import never ends with only
  /// `import.started` on the log. The error's message is never recorded.
  void _recordUnexpectedFailure(Object error, ImportPhase phase) {
    log.failure(
      'import.failed',
      code: 'import_unexpected_failed',
      error: error,
      fields: {'phase': phase.name},
    );
  }

  /// Deletes the coordinator's staging directory, if it exists. Cleanup is
  /// best effort: a cancellation must still report its result when the
  /// filesystem refuses the delete.
  Future<void> _discardStaging() async {
    final staging = stagingDirectory;
    if (staging == null) return;
    try {
      if (await staging.exists()) await staging.delete(recursive: true);
    } on FileSystemException {
      // Nothing to recover: staging holds no committed data.
    }
  }

  /// Fingerprint of a chosen export, used to detect a re-import.
  ///
  /// A ZIP is hashed by its bytes. A folder has no single byte stream, so it is
  /// hashed as its sorted file list with each file's content digest: the same
  /// export extracted twice fingerprints the same, and *any* edit - including
  /// one that keeps the file size - changes the fingerprint. Content is read as
  /// a stream, so an export of any size is never held in memory.
  Future<String> _fingerprint(String path) async {
    if (!ExportInspector.isFolder(path)) {
      final digest = await sha256.bind(File(path).openRead()).first;
      return 'sha256:${digest.toString()}';
    }
    final inspectionLimits = inspector.limits;
    final entries = await Isolate.run(
      () => folderFingerprintEntries(path, inspectionLimits),
    );
    return 'sha256:${sha256.convert(utf8.encode(entries.join('\n')))}';
  }

  Future<int?> _importIdForFingerprint(String fingerprint) async {
    final row =
        await (database.select(database.imports)
              ..where((table) => table.sourceFingerprint.equals(fingerprint))
              ..orderBy([(table) => OrderingTerm.asc(table.id)])
              ..limit(1))
            .getSingleOrNull();
    return row?.id;
  }

  /// Writes one `source_files` row per reported file whose path and error code
  /// fit their declared bounds. A file that violates a bound is counted and
  /// named in [warnings] instead of throwing, so the stored coverage can be
  /// smaller than the report by exactly the skipped entries. Cancellation is
  /// checked before each file.
  Future<({Map<String, int> ids, int skipped})> _writeSourceFiles(
    int importId,
    ImportCoverageReport report, {
    CancelToken? cancelToken,
    required Set<String> warnings,
  }) async {
    final ids = <String, int>{};
    var skipped = 0;
    final filesTotal = report.entries
        .where((entry) => entry.relativePath != null)
        .length;
    for (final entry in report.entries) {
      final relativePath = entry.relativePath;
      if (relativePath == null) continue;

      if (cancelToken?.isCancelled ?? false) {
        throw _ImportCancelledSignal(
          ImportPhase.writing,
          filesDone: ids.length,
          filesTotal: filesTotal,
        );
      }

      final path = normalizeImportText(
        relativePath,
        ImportTextColumns.sourceFilePath,
      );
      final pathRejection = path.rejection;
      if (pathRejection != null) {
        skipped++;
        warnings.add(pathRejection.warningFor(relativePath));
        continue;
      }

      final error = entry.supported
          ? const ImportTextValue(null)
          : normalizeImportText(
              entry.reason.code,
              ImportTextColumns.sourceFileErrorCode,
            );
      final errorRejection = error.rejection;
      if (errorRejection != null) {
        skipped++;
        warnings.add(errorRejection.warningFor(relativePath));
        continue;
      }

      final id = await _writeSkippingBadRecord<int>(
        write: () => database
            .into(database.sourceFiles)
            .insert(
              SourceFilesCompanion.insert(
                importId: importId,
                relativePath: path.value!,
                parseStatus: _parseStatusFor(entry),
                errorCode: Value(error.value),
              ),
            ),
        relativePath: relativePath,
        column: ImportTextColumns.sourceFilePath,
        warnings: warnings,
        onSkipped: () => skipped++,
      );
      if (id == null) continue;
      ids[relativePath] = id;
      _emit(
        ImportProgress(
          phase: ImportPhase.writing,
          filesDone: ids.length,
          filesTotal: filesTotal,
          currentRelativePath: relativePath,
        ),
      );
    }
    return (ids: ids, skipped: skipped);
  }

  static ParseStatus _parseStatusFor(ImportCoverageEntry entry) {
    if (entry.supported) return ParseStatus.parsed;
    return switch (entry.reason) {
      ImportCoverageReason.malformedJson => ParseStatus.failed,
      ImportCoverageReason.unsupportedMedia => ParseStatus.skipped,
      // Recognized by its folder, intentionally left for later.
      ImportCoverageReason.knownNotImported => ParseStatus.skipped,
      _ => ParseStatus.unsupported,
    };
  }

  /// Returns the person id for every sender name in the preview.
  ///
  /// The export gives no platform id here, so people are matched by exported
  /// name within one platform. No two names are merged, and a name is never
  /// merged with a row that has its own platform id. An exported name that is
  /// empty or only whitespace is required by the schema, so it is skipped and
  /// counted instead of inventing a placeholder person; its event is still
  /// written with no actor.
  Future<({Map<String, int> ids, int skipped})> _writePeople(
    FacebookImportPreview preview, {
    required String importPlatform,
    required Set<String> warnings,
  }) async {
    final ids = <String, int>{};
    final seen = <String>{};
    var skipped = 0;
    for (final record in preview.records) {
      final name = record.senderName;
      if (name == null || !seen.add(name)) continue;

      final normalized = normalizeImportText(
        name,
        ImportTextColumns.personDisplayName,
      );
      final rejection = normalized.rejection;
      if (rejection != null) {
        skipped++;
        warnings.add(rejection.warningFor(record.sourcePath));
        continue;
      }
      final stored = normalized.value!;

      final existing =
          await (database.select(database.people)
                ..where(
                  (row) =>
                      row.platform.equals(importPlatform) &
                      row.displayName.equals(stored) &
                      row.platformPersonId.isNull(),
                )
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) {
        ids[name] = existing.id;
        continue;
      }

      final id = await _writeSkippingBadRecord<int>(
        write: () => database
            .into(database.people)
            .insert(
              PeopleCompanion.insert(
                platform: importPlatform,
                displayName: stored,
              ),
            ),
        relativePath: record.sourcePath,
        column: ImportTextColumns.personDisplayName,
        warnings: warnings,
        onSkipped: () => skipped++,
      );
      if (id != null) ids[name] = id;
    }
    return (ids: ids, skipped: skipped);
  }

  Future<({Map<String, int> ids, int skipped})> _writeConversations(
    int importId,
    FacebookImportPreview preview, {
    required Set<String> warnings,
  }) async {
    final ids = <String, int>{};
    var skipped = 0;
    for (final record in preview.records) {
      final key = record.conversationKey;
      // Comments are not part of a conversation.
      if (key == null || ids.containsKey(key)) continue;

      final normalizedKey = normalizeImportText(
        key,
        ImportTextColumns.conversationSourceId,
      );
      final normalizedTitle = normalizeImportText(
        record.conversationTitle,
        ImportTextColumns.conversationTitle,
      );
      final rejection = _firstRejection([normalizedKey, normalizedTitle]);
      if (rejection != null) {
        skipped++;
        warnings.add(rejection.warningFor(record.sourcePath));
        continue;
      }

      final id = await _writeSkippingBadRecord<int>(
        write: () => database
            .into(database.conversations)
            .insert(
              ConversationsCompanion.insert(
                importId: importId,
                sourceConversationId: Value(normalizedKey.value),
                title: Value(normalizedTitle.value),
              ),
            ),
        relativePath: record.sourcePath,
        column: ImportTextColumns.conversationSourceId,
        warnings: warnings,
        onSkipped: () => skipped++,
      );
      if (id != null) ids[key] = id;
    }
    return (ids: ids, skipped: skipped);
  }

  /// Returns the new event id for each record's source locator, plus how many
  /// records the schema refused.
  Future<({Map<String, int> ids, int skipped})> _writeEvents({
    required int importId,
    required FacebookImportPreview preview,
    required String importPlatform,
    required Map<String, int> sourceFileIds,
    required Map<String, int> personIds,
    required Map<String, int> conversationIds,
    required int filesTotal,
    required Set<String> warnings,
    CancelToken? cancelToken,
  }) async {
    final ids = <String, int>{};
    var written = 0;
    var skipped = 0;
    for (final record in preview.records) {
      // Cancellation is checked between record batches, so a large file never
      // holds the write phase open once the caller has given up.
      if (written % _writeBatchSize == 0 &&
          (cancelToken?.isCancelled ?? false)) {
        throw _ImportCancelledSignal(
          ImportPhase.writing,
          filesDone: filesTotal,
          filesTotal: filesTotal,
          recordsWritten: written,
        );
      }

      final sourceFileId = sourceFileIds[record.sourcePath];
      if (sourceFileId == null) {
        // A record without its file row would be unattributable evidence. One
        // such record must not throw away a whole export, so it is skipped and
        // counted; the warning names the reason on the import screen.
        skipped++;
        warnings.add(_unattributableRecordWarning);
        continue;
      }
      // Every archive value is normalized against its declared column before
      // drift sees it. A rejected value costs this record, never the archive.
      final locator = normalizeImportText(
        record.sourceLocator,
        ImportTextColumns.eventSourceLocator,
      );
      final eventType = normalizeImportText(
        record.eventType,
        ImportTextColumns.eventType,
      );
      final timestampRaw = normalizeImportText(
        record.timestampRaw,
        ImportTextColumns.eventTimestampRaw,
      );
      final textContent = normalizeImportText(
        record.text,
        ImportTextColumns.eventTextContent,
      );
      final metadataJson = normalizeImportText(
        record.metadata == null ? null : jsonEncode(record.metadata),
        ImportTextColumns.eventMetadataJson,
      );
      final platformValue = normalizeImportText(
        importPlatform,
        ImportTextColumns.eventPlatform,
      );
      final rejection = _firstRejection([
        locator,
        eventType,
        timestampRaw,
        textContent,
        metadataJson,
        platformValue,
      ]);
      if (rejection != null) {
        skipped++;
        warnings.add(rejection.warningFor(record.sourcePath));
        continue;
      }

      final eventId = await _writeSkippingBadRecord<int>(
        write: () => database
            .into(database.events)
            .insert(
              EventsCompanion.insert(
                importId: importId,
                sourceFileId: sourceFileId,
                sourceLocator: locator.value!,
                platform: platformValue.value!,
                eventType: eventType.value!,
                // The export timestamp is epoch milliseconds: an absolute
                // instant, so a parsed value is UTC by construction. A raw
                // value that failed to parse is `invalid`, not `utc`; no raw
                // value at all is `unknown`.
                timezoneStatus: record.timezoneStatus ??
                    (record.timestampUtc != null
                        ? TimezoneStatus.utc
                        : record.timestampRaw == null
                        ? TimezoneStatus.unknown
                        : TimezoneStatus.invalid),
                timestampRaw: Value(timestampRaw.value),
                timestampNormalized: Value(
                  record.timezoneStatus == TimezoneStatus.localTime
                      ? record.timestampUtc
                      : record.timestampUtc?.toUtc(),
                ),
                actorId: Value(
                  record.senderName == null
                      ? null
                      : personIds[record.senderName],
                ),
                conversationId: Value(
                  record.conversationKey == null
                      ? null
                      : conversationIds[record.conversationKey],
                ),
                // The user's own words are evidence: a body past the ceiling
                // is skipped and counted, never truncated into a
                // half-quotation. An empty body becomes null, which keeps the
                // column's minimum satisfied.
                textContent: Value(textContent.value),
                // Allowlisted metadata only, as bounded by the importer.
                metadataJson: Value(metadataJson.value),
              ),
            ),
        relativePath: record.sourcePath,
        column: ImportTextColumns.eventSourceLocator,
        warnings: warnings,
        onSkipped: () => skipped++,
      );
      if (eventId == null) continue;
      ids[record.sourceLocator] = eventId;
      written++;
      if (written % _writeBatchSize == 0) {
        _emit(
          ImportProgress(
            phase: ImportPhase.writing,
            filesDone: filesTotal,
            filesTotal: filesTotal,
            recordsWritten: written,
            currentRelativePath: record.sourcePath,
          ),
        );
      }
    }
    return (ids: ids, skipped: skipped);
  }

  /// Writes one `attachments` row per media reference, linked to its event and
  /// to the archive entry that backs it. Only metadata is written; the media
  /// bytes stay inside the archive.
  Future<({int stored, int skipped})> _writeAttachments({
    required FacebookImportPreview preview,
    required Map<String, int> sourceFileIds,
    required Map<String, int> eventIds,
    required int filesTotal,
    CancelToken? cancelToken,
    required Set<String> warnings,
  }) async {
    var processed = 0;
    var stored = 0;
    var skipped = 0;
    for (final attachment in preview.attachments) {
      if (processed % _writeBatchSize == 0 &&
          (cancelToken?.isCancelled ?? false)) {
        throw _ImportCancelledSignal(
          ImportPhase.writing,
          filesDone: filesTotal,
          filesTotal: filesTotal,
          recordsWritten: stored,
        );
      }
      processed++;
      final sourceFileId = sourceFileIds[attachment.relativePath];
      if (sourceFileId == null) {
        // Same rule as events: an attachment without its media entry is
        // skipped and counted instead of failing the whole archive. Media
        // metadata is the least valuable row here.
        skipped++;
        warnings.add(_unattributableRecordWarning);
        continue;
      }

      final relativePath = normalizeImportText(
        attachment.relativePath,
        ImportTextColumns.attachmentPath,
      );
      final mediaType = normalizeImportText(
        attachment.mediaType,
        ImportTextColumns.attachmentMediaType,
      );
      final contentHash = normalizeImportText(
        attachment.contentHash,
        ImportTextColumns.attachmentContentHash,
      );
      final rejection = _firstRejection([relativePath, mediaType, contentHash]);
      if (rejection != null) {
        skipped++;
        warnings.add(rejection.warningFor(attachment.relativePath));
        continue;
      }

      final record = AttachmentRecord(
        eventId: eventIds[attachment.sourceLocator],
        sourceFileId: sourceFileId,
        relativePath: relativePath.value,
        mediaType: mediaType.value!,
        sizeBytes: attachment.sizeBytes,
        contentHash: contentHash.value,
      );
      final ids = await _writeSkippingBadRecord<List<int>>(
        write: () => attachmentRepository.insertAll([record]),
        relativePath: attachment.relativePath,
        column: ImportTextColumns.attachmentMediaType,
        warnings: warnings,
        onSkipped: () => skipped++,
      );
      if (ids != null && ids.isNotEmpty) stored++;
    }
    return (stored: stored, skipped: skipped);
  }

  /// Rebuilds the per-file report of an already imported archive from its
  /// stored source files, so a deduplicated import still reports coverage.
  Future<ImportCoverageReport> _reportForExistingImport(int importId) async {
    final rows =
        await (database.select(database.sourceFiles)
              ..where((table) => table.importId.equals(importId))
              ..orderBy([(table) => OrderingTerm.asc(table.relativePath)]))
            .get();
    return ImportCoverageReport.fromStoredFiles([
      for (final row in rows)
        (
          relativePath: row.relativePath,
          parseStatus: row.parseStatus.name,
          errorCode: row.errorCode,
        ),
    ]);
  }

  Future<ImportOutcome> _outcomeForExisting(int importId) async {
    return ImportOutcome(
      importId: importId,
      reusedExistingImport: true,
      sourceFiles: await _countRows('source_files', importId),
      events: await _countRows('events', importId),
      people: await _countRows('people', null),
      conversations: await _countRows('conversations', importId),
      attachments: await _countAttachments(importId),
      skippedRecords: 0,
      warnings: const [],
    );
  }

  /// Counts attachment rows of [importId] through their backing source file.
  /// (Never reached on a cancelled import: its rows were rolled back.)
  Future<int> _countAttachments(int importId) async {
    final rows = await database
        .customSelect(
          'SELECT COUNT(*) AS row_count FROM attachments a '
          'JOIN source_files s ON s.id = a.source_file_id WHERE s.import_id = ?',
          variables: [Variable<int>(importId)],
        )
        .getSingle();
    return rows.read<int>('row_count');
  }

  /// Counts rows of [table], scoped to [importId] when it is given. Both names
  /// are internal constants, never user input.
  Future<int> _countRows(String table, int? importId) async {
    final where = importId == null ? '' : ' WHERE import_id = ?';
    final rows = await database
        .customSelect(
          'SELECT COUNT(*) AS row_count FROM $table$where',
          variables: importId == null ? const [] : [Variable<int>(importId)],
        )
        .getSingle();
    return rows.read<int>('row_count');
  }
}

/// Internal signal used to unwind the import transaction on cancellation.
///
/// It never leaves the coordinator: callers receive an [ImportCancelled]
/// result instead, so no internal error object or path escapes.
class _ImportCancelledSignal implements Exception {
  const _ImportCancelledSignal(
    this.phase, {
    required this.filesDone,
    required this.filesTotal,
    this.recordsWritten = 0,
  });

  final ImportPhase phase;
  final int filesDone;
  final int filesTotal;
  final int recordsWritten;
}
