import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/core/errors/import_error_catalog.dart';
import 'package:personal_data_agent/src/core/errors/import_report.dart';
import 'package:personal_data_agent/src/services/importing/archive_inspector.dart';

void main() {
  group('ImportErrorCatalog', () {
    test('has no duplicate codes or aliases', () {
      final primary = <String>{};
      for (final entry in ImportErrorCatalog.entries) {
        expect(
          primary.add(entry.code),
          isTrue,
          reason: 'duplicate code ${entry.code}',
        );
        expect(entry.code, matches(RegExp(r'^[a-z][a-z0-9_]*$')));
      }

      final aliases = <String>{};
      for (final entry in ImportErrorCatalog.entries) {
        for (final alias in entry.aliases) {
          expect(
            primary.contains(alias),
            isFalse,
            reason: '${entry.code} aliases a primary code: $alias',
          );
          expect(
            aliases.add(alias),
            isTrue,
            reason: 'alias $alias is claimed twice',
          );
        }
      }
      expect(ImportErrorCatalog.codes, contains('unknown_error'));
    });

    test('every code literal in the import sources is catalogued', () {
      const sources = [
        'lib/src/services/importing/archive_inspector.dart',
        'lib/src/services/importing/facebook_json_importer.dart',
        'lib/src/services/importing/import_coordinator.dart',
        'lib/src/services/importing/import_coverage_report.dart',
      ];
      // Code-like literals share these prefixes with real codes.
      final codePattern = RegExp(
        r"'(?:archive|path|absolute|invalid|symbolic|duplicate|entry|expanded|"
        r"json|malformed|unsupported|no|attachment|blocked|oversized|record|"
        r"import|cancelled|unknown)[a-z0-9_]*'",
      );
      // Values that are data, not codes: table columns, metadata keys and
      // coverage counter names.
      const notCodes = {
        'attachments',
        'attachment_types',
        'unsupported_files',
        'blocked_files',
        'records_parsed',
        'records_skipped',
      };

      final checked = <String>{};
      for (final source in sources) {
        final text = File(source).readAsStringSync();
        for (final match in codePattern.allMatches(text)) {
          final code = match.group(0)!.replaceAll("'", '');
          if (!code.contains('_') || notCodes.contains(code)) continue;
          checked.add(code);
          expect(
            ImportErrorCatalog.byCode(code),
            isNotNull,
            reason: '$source reports $code, which is not in the catalog',
          );
        }
      }

      // The sweep must actually find the codes, not pass on an empty set.
      expect(checked, containsAll(['archive_invalid', 'record_count_limit']));
      expect(checked.length, greaterThan(30));
    });

    test('every entry has English and Arabic messages and actions', () {
      final arabic = RegExp(r'[\u0600-\u06FF]');
      for (final entry in ImportErrorCatalog.entries) {
        expect(entry.messageEn.trim(), isNotEmpty, reason: entry.code);
        expect(entry.messageAr.trim(), isNotEmpty, reason: entry.code);
        expect(entry.actionEn.trim(), isNotEmpty, reason: entry.code);
        expect(entry.actionAr.trim(), isNotEmpty, reason: entry.code);
        expect(
          entry.messageEn,
          matches(RegExp(r'[A-Za-z]')),
          reason: '${entry.code} has no English message',
        );
        expect(
          entry.messageAr,
          matches(arabic),
          reason: '${entry.code} has no Arabic message',
        );
        expect(
          entry.actionAr,
          matches(arabic),
          reason: '${entry.code} has no Arabic action',
        );
      }
    });

    test('resolves aliases and falls back to unknown_error', () {
      expect(ImportErrorCatalog.byCode('path_escape')?.code, 'path_traversal');
      expect(
        ImportErrorCatalog.byCode('symlink_entry')?.code,
        'symbolic_link_rejected',
      );
      expect(ImportErrorCatalog.byCode('payload_size_limit'), isNotNull);
      expect(ImportErrorCatalog.lookup('not_a_code').code, 'unknown_error');
      expect(ImportErrorCatalog.lookup(null).code, 'unknown_error');
    });
  });

  group('ImportReport', () {
    test('keeps a coded error and its relative path', () {
      final report = ImportReport.fromError(
        const ArchiveInspectionException('archive_invalid', 'host /Users/me'),
        relativePath: 'posts/your_posts_1.json',
      );

      final issue = report.issues.single;
      expect(issue.code, 'archive_invalid');
      expect(issue.relativePath, 'posts/your_posts_1.json');
      expect(issue.severity, ImportErrorSeverity.error);
      expect(report.hasErrors, isTrue);
      expect(report.toString(), isNot(contains('/Users/me')));
    });

    test('maps an unknown exception without leaking its message', () {
      final report = ImportReport.fromError(
        StateError('secret token abc123 at /home/person/export.zip'),
      );

      final issue = report.issues.single;
      expect(issue.code, 'unknown_error');
      expect(issue.relativePath, isNull);
      expect(issue.messageEn, ImportErrorCatalog.unknownError.messageEn);
      expect(issue.messageAr, ImportErrorCatalog.unknownError.messageAr);
      expect(report.toString(), isNot(contains('secret')));
      expect(report.toString(), isNot(contains('export.zip')));
    });
  });
}
