import '../../core/l10n/import_categories.dart';
import 'archive_inspector.dart';

/// Why a file is or is not usable for this import.
///
/// Codes are content-free: they carry no path, no file text and no user data,
/// so a report can be shown, logged or stored without leaking the archive.
enum ImportCoverageReason {
  /// Read and parsed; its records were normalized.
  supported('supported'),

  /// Matched the supported file shape but is not valid JSON.
  malformedJson('malformed_json'),

  /// Valid JSON, but not the supported messages shape.
  unsupportedJsonShape('unsupported_json_shape'),

  /// A media file: reported, not parsed for records.
  unsupportedMedia('unsupported_media'),

  /// Not a file type this importer knows.
  unknownExtension('unknown_extension'),

  /// A file under a documented Facebook export root that this importer does
  /// not model yet. It is not "unsupported": the export named the folder, so
  /// the report can say what it holds and that it was left for later.
  knownNotImported('known_not_imported'),

  /// The archive was rejected as unsafe (traversal, absolute path, link,
  /// duplicate or ambiguous entry). The offending path is never reported.
  blockedUnsafePath('blocked_unsafe_path'),

  /// The archive was rejected by a configured size, count or byte limit.
  oversizedArchive('oversized_archive'),

  /// The archive is not a readable, intact ZIP.
  invalidArchive('invalid_archive');

  const ImportCoverageReason(this.code);

  /// Stable, content-free identifier used in storage and tests.
  final String code;

  /// True when the file or archive could not be processed at all, as opposed
  /// to being processed and found unsupported.
  bool get isBlocked =>
      this == ImportCoverageReason.blockedUnsafePath ||
      this == ImportCoverageReason.oversizedArchive ||
      this == ImportCoverageReason.invalidArchive;

  static ImportCoverageReason? byCode(String? code) {
    if (code == null) return null;
    for (final reason in values) {
      if (reason.code == code) return reason;
    }
    return null;
  }

  /// Maps an [ArchiveInspectionException] code to a report reason.
  static ImportCoverageReason forInspectionCode(String code) {
    switch (code) {
      case 'path_traversal':
      case 'absolute_entry_path':
      case 'symbolic_link_rejected':
      case 'duplicate_entry':
      case 'invalid_entry_path':
        return ImportCoverageReason.blockedUnsafePath;
      case 'archive_invalid':
      case 'archive_changed':
      case 'archive_corrupt':
        return ImportCoverageReason.invalidArchive;
      default:
        return ImportCoverageReason.oversizedArchive;
    }
  }

  /// Maps a [FacebookImportException] code to a report reason.
  static ImportCoverageReason forImportCode(String code) =>
      code == 'record_count_limit'
      ? ImportCoverageReason.oversizedArchive
      : ImportCoverageReason.invalidArchive;
}

/// What one archive file yielded, as seen by a parser.
class ImportFileOutcome {
  const ImportFileOutcome({
    required this.path,
    required this.reason,
    this.recordsParsed = 0,
    this.recordsSkipped = 0,
  });

  final String path;
  final ImportCoverageReason reason;
  final int recordsParsed;
  final int recordsSkipped;

  bool get isSupported => reason == ImportCoverageReason.supported;
}

/// One row of the coverage report: what happened to one archive file.
class ImportCoverageEntry {
  const ImportCoverageEntry({
    required this.relativePath,
    required this.sourceType,
    required this.supported,
    required this.reason,
    this.category,
    this.recordsParsed = 0,
    this.recordsSkipped = 0,
  });

  /// Archive-relative path, or null for a file that was never readable
  /// (a blocked archive reports the reason without any path).
  final String? relativePath;

  /// `json`, `media` or `other`.
  final String sourceType;

  final bool supported;
  final ImportCoverageReason reason;

  /// The documented export root this path belongs to, when it has one.
  final ImportCategory? category;

  final int recordsParsed;
  final int recordsSkipped;
}

/// Per-file coverage of one import, plus totals.
///
/// Purely local and content-free: it names archive-relative paths and reason
/// codes, never file contents and never a host path.
class ImportCoverageReport {
  const ImportCoverageReport({required this.entries, this.warnings = const []});

  /// Builds the report from a validated scan and the parser's per-file results.
  factory ImportCoverageReport.fromScan(
    ArchiveScan scan, {
    List<ImportFileOutcome> outcomes = const [],
  }) {
    final byPath = {for (final outcome in outcomes) outcome.path: outcome};
    final entries = <ImportCoverageEntry>[];
    for (final entry in scan.entries) {
      if (entry.isDirectory) continue;
      final path = entry.relativePath;
      final outcome = byPath[path];
      final category = importCategoryForPath(path);
      var reason =
          outcome?.reason ??
          (entry.isMedia
              ? ImportCoverageReason.unsupportedMedia
              : path.toLowerCase().endsWith('.json')
              ? ImportCoverageReason.unsupportedJsonShape
              : ImportCoverageReason.unknownExtension);
      // A path under a documented root is never reported as unknown: if the
      // parser has no model for it, that is "known, not imported yet".
      if (category != null &&
          (reason == ImportCoverageReason.unsupportedJsonShape ||
              reason == ImportCoverageReason.unknownExtension)) {
        reason = ImportCoverageReason.knownNotImported;
      }
      entries.add(
        ImportCoverageEntry(
          relativePath: path,
          sourceType: entry.isMedia
              ? 'media'
              : path.toLowerCase().endsWith('.json')
              ? 'json'
              : 'other',
          supported: outcome?.isSupported ?? false,
          reason: reason,
          category: category,
          recordsParsed: outcome?.recordsParsed ?? 0,
          recordsSkipped: outcome?.recordsSkipped ?? 0,
        ),
      );
    }
    return ImportCoverageReport(
      entries: List.unmodifiable(entries),
      warnings: List.unmodifiable(scan.inspection.warnings),
    );
  }

  /// A report for an archive that never produced a scan.
  factory ImportCoverageReport.blocked(ImportCoverageReason reason) =>
      ImportCoverageReport(
        entries: [
          ImportCoverageEntry(
            relativePath: null,
            sourceType: 'archive',
            supported: false,
            reason: reason,
          ),
        ],
      );

  /// Rebuilds the per-file part of a report from persisted source files.
  factory ImportCoverageReport.fromStoredFiles(
    List<({String relativePath, String parseStatus, String? errorCode})> files,
  ) {
    return ImportCoverageReport(
      entries: List.unmodifiable([
        for (final file in files)
          _storedEntry(file.relativePath, file.parseStatus, file.errorCode),
      ]),
    );
  }

  final List<ImportCoverageEntry> entries;
  final List<String> warnings;

  Iterable<ImportCoverageEntry> byReason(ImportCoverageReason reason) =>
      entries.where((entry) => entry.reason == reason);

  int get totalFiles => entries.length;
  int get supportedFiles => entries.where((entry) => entry.supported).length;
  int get blockedFiles =>
      entries.where((entry) => entry.reason.isBlocked).length;
  int get knownNotImportedFiles =>
      byReason(ImportCoverageReason.knownNotImported).length;

  /// Files that are neither imported, blocked, nor explained by a known root.
  int get unsupportedFiles =>
      totalFiles - supportedFiles - blockedFiles - knownNotImportedFiles;

  int get recordsParsed =>
      entries.fold(0, (sum, entry) => sum + entry.recordsParsed);
  int get recordsSkipped =>
      entries.fold(0, (sum, entry) => sum + entry.recordsSkipped);

  /// Per-category totals for the documented export roots, in catalog order.
  /// Empty categories are omitted, so a row only appears when the archive has
  /// files under that root.
  List<ImportCategoryCoverage> get categories {
    final rows = <ImportCategoryCoverage>[];
    for (final category in importCategories) {
      final members = entries
          .where((entry) => entry.category?.code == category.code)
          .toList(growable: false);
      if (members.isEmpty) continue;
      rows.add(
        ImportCategoryCoverage(
          category: category,
          files: members.length,
          supportedFiles: members.where((entry) => entry.supported).length,
          knownNotImportedFiles: members
              .where(
                (entry) =>
                    entry.reason == ImportCoverageReason.knownNotImported,
              )
              .length,
          recordsParsed: members.fold(
            0,
            (sum, entry) => sum + entry.recordsParsed,
          ),
          recordsSkipped: members.fold(
            0,
            (sum, entry) => sum + entry.recordsSkipped,
          ),
        ),
      );
    }
    return List.unmodifiable(rows);
  }

  double get supportedPercent => _percent(supportedFiles);
  double get knownNotImportedPercent => _percent(knownNotImportedFiles);
  double get unsupportedPercent => _percent(unsupportedFiles);
  double get blockedPercent => _percent(blockedFiles);

  /// Aggregate counts, stored with the import for later reporting.
  Map<String, int> get counts => {
    'files': totalFiles,
    'supported_files': supportedFiles,
    'unsupported_files': unsupportedFiles,
    'known_not_imported_files': knownNotImportedFiles,
    'blocked_files': blockedFiles,
    'records_parsed': recordsParsed,
    'records_skipped': recordsSkipped,
  };

  double _percent(int part) => totalFiles == 0 ? 0 : part * 100 / totalFiles;
}

/// Files and records that fell under one documented export root.
class ImportCategoryCoverage {
  const ImportCategoryCoverage({
    required this.category,
    required this.files,
    required this.supportedFiles,
    required this.knownNotImportedFiles,
    required this.recordsParsed,
    required this.recordsSkipped,
  });

  final ImportCategory category;
  final int files;
  final int supportedFiles;

  /// Files under this root the importer does not model yet.
  final int knownNotImportedFiles;

  final int recordsParsed;
  final int recordsSkipped;
}

/// Rebuilds one stored `source_files` row as a coverage entry.
///
/// A stored row keeps only a parse status and a reason code, so the category is
/// derived from the path again. A non-empty category that was not parsed is
/// "known, not imported", unless the file was malformed or its media bytes were
/// deliberately not read - those keep their own specific reason.
ImportCoverageEntry _storedEntry(
  String relativePath,
  String parseStatus,
  String? errorCode,
) {
  final category = importCategoryForPath(relativePath);
  final parsed = parseStatus == 'parsed';
  var reason = parsed
      ? ImportCoverageReason.supported
      : ImportCoverageReason.byCode(errorCode) ??
            ImportCoverageReason.unknownExtension;
  if (!parsed &&
      category != null &&
      reason != ImportCoverageReason.unsupportedMedia &&
      !(errorCode?.startsWith('malformed') ?? false)) {
    reason = ImportCoverageReason.knownNotImported;
  }
  return ImportCoverageEntry(
    relativePath: relativePath,
    sourceType: relativePath.toLowerCase().endsWith('.json') ? 'json' : 'other',
    supported: parsed,
    reason: reason,
    category: category,
  );
}
