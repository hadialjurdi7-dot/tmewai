import 'import_error_catalog.dart';

/// An exception that carries a catalog-safe code instead of free-form text.
///
/// Exception messages are for developers and may contain host paths; only
/// [code] may cross into a report, a log or the screen.
abstract interface class CodedException implements Exception {
  String get code;
}

/// One reported import issue for one archive file.
///
/// Everything here is safe to render: the path is archive-relative and the code
/// resolves to a catalog entry. The underlying exception message is never kept.
class ImportReportIssue {
  const ImportReportIssue({required this.relativePath, required this.code});

  /// Archive-relative path, or null when the issue is not tied to one file
  /// (a rejected archive, a cancelled import).
  final String? relativePath;

  /// A catalog code; construction goes through [ImportErrorCatalog.lookup], so
  /// an unknown input becomes `unknown_error`.
  final String code;

  ImportErrorEntry get entry => ImportErrorCatalog.lookup(code);

  ImportErrorSeverity get severity => entry.severity;

  String get messageEn => entry.messageEn;
  String get messageAr => entry.messageAr;
  String get actionEn => entry.actionEn;
  String get actionAr => entry.actionAr;

  @override
  String toString() => 'ImportReportIssue($code)';
}

/// The per-file issue list an import screen renders.
class ImportReport {
  const ImportReport({required this.issues});

  /// A report for one failure.
  ///
  /// A [CodedException] keeps its code; any other exception, including one
  /// from the platform, becomes `unknown_error` so its message and file content
  /// never leak.
  factory ImportReport.fromError(Object error, {String? relativePath}) {
    final code = error is CodedException ? error.code : null;
    return ImportReport(
      issues: [
        ImportReportIssue(
          relativePath: relativePath,
          code: ImportErrorCatalog.lookup(code).code,
        ),
      ],
    );
  }

  final List<ImportReportIssue> issues;

  bool get hasErrors =>
      issues.any((issue) => issue.severity == ImportErrorSeverity.error);

  @override
  String toString() =>
      'ImportReport(${issues.map((issue) => issue.code).join(', ')})';
}
