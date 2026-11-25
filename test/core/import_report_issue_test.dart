import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/core/errors/import_error_catalog.dart';
import 'package:personal_data_agent/src/core/errors/import_report.dart';

/// The import screen renders one row per issue and shows its action text from
/// the catalog. These getters are the only path from a stored code to user
/// text, so they are exercised directly, including the unknown-code fallback.
void main() {
  test('an issue renders its catalog text in both languages', () {
    const issue = ImportReportIssue(
      relativePath: 'messages/inbox/leila/message_1.json',
      code: 'archive_corrupt',
    );

    expect(issue.entry.code, 'archive_corrupt');
    expect(issue.severity, ImportErrorSeverity.error);
    expect(issue.messageEn, contains('size'));
    expect(issue.messageAr, matches(RegExp(r'[\u0600-\u06FF]')));
    expect(issue.actionEn.trim(), isNotEmpty);
    expect(issue.actionAr, matches(RegExp(r'[\u0600-\u06FF]')));
  });

  test('an unknown code resolves to the generic unknown_error entry', () {
    const issue = ImportReportIssue(relativePath: null, code: 'not_a_code');

    expect(issue.entry.code, 'unknown_error');
    expect(issue.messageEn, ImportErrorCatalog.unknownError.messageEn);
    expect(issue.actionEn, ImportErrorCatalog.unknownError.actionEn);
    expect(issue.actionAr, ImportErrorCatalog.unknownError.actionAr);
  });

  test('a warning-only report is not flagged as an error', () {
    final report = ImportReport.fromError(
      const _Coded('attachment_missing'),
      relativePath: 'messages/inbox/leila/message_1.json',
    );
    final issue = report.issues.single;

    expect(issue.code, 'attachment_missing');
    expect(issue.relativePath, 'messages/inbox/leila/message_1.json');
    expect(issue.severity, ImportErrorSeverity.warning);
    expect(report.hasErrors, isFalse);

    final failure = ImportReport.fromError(const _Coded('archive_corrupt'));
    expect(failure.hasErrors, isTrue);
  });
}

class _Coded implements CodedException {
  const _Coded(this.code);

  @override
  final String code;
}
