import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/core/l10n/import_categories.dart';
import 'package:personal_data_agent/src/services/importing/archive_inspector.dart';
import 'package:personal_data_agent/src/services/importing/facebook_json_importer.dart';
import 'package:personal_data_agent/src/services/importing/import_coverage_report.dart';

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('pda-coverage-');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<File> writeZip(
    Map<String, String> entries, {
    String name = 'a.zip',
  }) async {
    final archive = Archive();
    for (final entry in entries.entries) {
      archive.addFile(ArchiveFile.string(entry.key, entry.value));
    }
    final file = File('${tempDirectory.path}/$name');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    return file;
  }

  /// Everything the report says, as one string, to search for leaked content.
  String reportText(ImportCoverageReport report) => [
    for (final entry in report.entries)
      '${entry.relativePath}|${entry.sourceType}|${entry.reason.code}',
    ...report.warnings,
    report.counts.toString(),
  ].join('\n');

  test('classifies a mixed archive per file with totals that add up', () async {
    final file = await writeZip({
      'messages/inbox/message_1.json':
          '{"messages":[{"sender_name":"Fixtures","content":"hello","timestamp_ms":1767225600000},7]}',
      'notes/your_notes.json': '{"posts":[]}',
      'photos/image.jpg': 'fake image bytes',
      'notes/readme.txt': 'unrelated',
    });

    final scan = await const ArchiveInspector().scanJsonFiles(
      file,
      jsonPathPattern: r'(^|/)message_[0-9]+\.json$',
    );

    final report = ImportCoverageReport.fromScan(
      scan,
      outcomes: const [
        ImportFileOutcome(
          path: 'messages/inbox/message_1.json',
          reason: ImportCoverageReason.supported,
          recordsParsed: 1,
          recordsSkipped: 1,
        ),
      ],
    );

    final byPath = {
      for (final entry in report.entries) entry.relativePath: entry,
    };
    expect(
      byPath['messages/inbox/message_1.json']!.supported,
      isTrue,
      reason: 'the supported messages file is parsed',
    );
    expect(byPath['messages/inbox/message_1.json']!.sourceType, 'json');
    expect(byPath['messages/inbox/message_1.json']!.recordsParsed, 1);
    expect(byPath['messages/inbox/message_1.json']!.recordsSkipped, 1);
    expect(
      byPath['notes/your_notes.json']!.reason,
      ImportCoverageReason.unsupportedJsonShape,
    );
    expect(
      byPath['photos/image.jpg']!.reason,
      ImportCoverageReason.unsupportedMedia,
    );
    expect(
      byPath['notes/readme.txt']!.reason,
      ImportCoverageReason.unknownExtension,
    );

    expect(report.totalFiles, 4);
    expect(report.supportedFiles, 1);
    expect(report.unsupportedFiles, 3);
    expect(report.blockedFiles, 0);
    expect(report.recordsParsed, 1);
    expect(report.recordsSkipped, 1);

    expect(report.supportedPercent, 25);
    expect(report.unsupportedPercent, 75);
    expect(report.blockedPercent, 0);
    expect(
      report.supportedPercent +
          report.unsupportedPercent +
          report.blockedPercent,
      closeTo(100, 0.0001),
    );
    expect(report.counts['files'], 4);
    expect(report.counts['supported_files'], 1);
  });

  test('reports a malformed JSON file without quoting its content', () async {
    final file = await writeZip({'messages/inbox/message_1.json': '{broken'});

    final scan = await const ArchiveInspector().scanJsonFiles(
      file,
      jsonPathPattern: r'(^|/)message_[0-9]+\.json$',
    );
    final report = ImportCoverageReport.fromScan(
      scan,
      outcomes: const [
        ImportFileOutcome(
          path: 'messages/inbox/message_1.json',
          reason: ImportCoverageReason.malformedJson,
        ),
      ],
    );

    expect(report.entries.single.reason, ImportCoverageReason.malformedJson);
    expect(report.supportedFiles, 0);
    expect(report.supportedPercent, 0);
    expect(reportText(report), isNot(contains('broken')));
  });

  test('never reports a path or content for a blocked archive', () async {
    final file = await writeZip({
      '../outside.json': '{"messages":[{"content":"secret words"}]}',
    }, name: 'unsafe.zip');

    late ImportCoverageReport report;
    try {
      final scan = await const ArchiveInspector().scanJsonFiles(file);
      report = ImportCoverageReport.fromScan(scan);
      fail('the unsafe archive must be rejected, got ${scan.entries.length}');
    } on ArchiveInspectionException catch (error) {
      expect(error.code, 'path_traversal');
      report = ImportCoverageReport.blocked(
        ImportCoverageReason.forInspectionCode(error.code),
      );
    }

    expect(report.blockedFiles, 1);
    expect(report.supportedFiles, 0);
    expect(report.blockedPercent, 100);
    expect(report.entries.single.relativePath, isNull);
    expect(
      report.entries.single.reason,
      ImportCoverageReason.blockedUnsafePath,
    );

    final text = reportText(report);
    expect(text, isNot(contains(tempDirectory.path)));
    expect(text, isNot(contains('outside.json')));
    expect(text, isNot(contains('secret words')));
  });

  test('maps inspector failure codes to report reasons', () async {
    expect(
      ImportCoverageReason.forInspectionCode('path_traversal'),
      ImportCoverageReason.blockedUnsafePath,
    );
    expect(
      ImportCoverageReason.forInspectionCode('absolute_entry_path'),
      ImportCoverageReason.blockedUnsafePath,
    );
    expect(
      ImportCoverageReason.forInspectionCode('symbolic_link_rejected'),
      ImportCoverageReason.blockedUnsafePath,
    );
    expect(
      ImportCoverageReason.forInspectionCode('entry_count_limit'),
      ImportCoverageReason.oversizedArchive,
    );
    expect(
      ImportCoverageReason.forInspectionCode('archive_invalid'),
      ImportCoverageReason.invalidArchive,
    );
  });

  test('maps documented Facebook roots and leaves unknown paths alone', () {
    expect(
      importCategoryForPath('ads_information/ads_and_topics/ads_interests.json')
          ?.code,
      'ads_information',
    );
    expect(
      importCategoryForPath('friends_and_followers/friends.json')?.code,
      'friends_and_followers',
    );
    expect(
      importCategoryForPath(
        'your_activity_across_facebook/posts/your_posts_1.json',
      )?.code,
      'activity',
    );
    // An export unzipped under one wrapper folder still classifies.
    expect(
      importCategoryForPath('facebook-2018/your_places/places.json')?.code,
      'your_places',
    );
    // A documented name deeper in the tree never classifies.
    expect(
      importCategoryForPath('notes/saved/ads_information/file.json'),
      isNull,
    );
    expect(importCategoryForPath('notes/readme.json'), isNull);

    final ads = importCategories.singleWhere(
      (category) => category.code == 'ads_information',
    );
    expect(ads.label.en, 'Ads information');
    expect(ads.label.ar, contains('الإعلانات'));
    expect(ads.description.ar, contains('فيسبوك'));
  });

  test(
    'reports known export roots by category and keeps unknown paths unsupported',
    () async {
      final file = await writeZip({
        'ads_information/ads_and_topics/ads_interests.json':
            '{"topics_v2": []}',
        'friends_and_followers/friends.json': '{"friends_v2": []}',
        'notes/readme.json': '{"nothing": []}',
        'messages/inbox/message_1.json':
            '{"messages":[{"sender_name":"Fixtures","content":"hello",'
            '"timestamp_ms":1767225600000}]}',
      });

      final preview = await const FacebookJsonImporter().preview(file);

      expect(preview.supportedFiles, 1);
      // Only the path under no documented root is genuinely unsupported.
      expect(preview.unsupportedJsonFiles, 1);
      expect(preview.knownNotImportedJsonFiles, 2);
      expect(preview.warnings, contains('known_folders_not_imported'));
      expect(preview.warnings, contains('unsupported_json_files_present'));

      final coverage = preview.coverage;
      expect(
        coverage.byReason(ImportCoverageReason.knownNotImported).map(
          (entry) => entry.relativePath,
        ),
        [
          'ads_information/ads_and_topics/ads_interests.json',
          'friends_and_followers/friends.json',
        ],
      );
      expect(
        coverage.byReason(ImportCoverageReason.unsupportedJsonShape).single
            .relativePath,
        'notes/readme.json',
      );

      final ads = coverage.categories.singleWhere(
        (row) => row.category.code == 'ads_information',
      );
      expect(ads.files, 1);
      expect(ads.recordsParsed, 0);
      expect(ads.knownNotImportedFiles, 1);
      expect(ads.category.label.inLocale(isRtl: true), 'معلومات الإعلانات');
      expect(ads.category.description.inLocale(isRtl: false), isNotEmpty);

      final friends = coverage.categories.singleWhere(
        (row) => row.category.code == 'friends_and_followers',
      );
      expect(friends.files, 1);
      expect(friends.knownNotImportedFiles, 1);

      final messages = coverage.categories.singleWhere(
        (row) => row.category.code == 'messages',
      );
      expect(messages.files, 1);
      expect(messages.supportedFiles, 1);
      expect(messages.recordsParsed, 1);

      // There is no category row for a path with no documented root.
      expect(
        coverage.categories.any((row) => row.category.code == 'notes'),
        isFalse,
      );
      expect(coverage.knownNotImportedFiles, 2);
      expect(coverage.unsupportedFiles, 1);
      expect(coverage.counts['known_not_imported_files'], 2);
      // The unsupported share no longer swallows the known folders.
      expect(coverage.supportedPercent, 25);
      expect(coverage.knownNotImportedPercent, 50);
      expect(coverage.unsupportedPercent, 25);
    },
  );

  test('a stored known folder file is not reported as unknown', () {
    final report = ImportCoverageReport.fromStoredFiles(const [
      (
        relativePath: 'ads_information/ads_and_topics/ads_interests.json',
        parseStatus: 'unsupported',
        errorCode: 'unsupported_json_shape',
      ),
      (
        relativePath: 'notes/readme.json',
        parseStatus: 'unsupported',
        errorCode: 'unsupported_json_shape',
      ),
    ]);

    expect(
      report.entries.first.reason,
      ImportCoverageReason.knownNotImported,
    );
    expect(report.entries.first.category?.code, 'ads_information');
    expect(
      report.entries.last.reason,
      ImportCoverageReason.unsupportedJsonShape,
    );
    expect(report.unsupportedFiles, 1);
    expect(report.knownNotImportedFiles, 1);
  });

  test('rebuilds coverage from persisted source files', () async {
    final report = ImportCoverageReport.fromStoredFiles(const [
      (
        relativePath: 'messages/inbox/message_1.json',
        parseStatus: 'parsed',
        errorCode: null,
      ),
      (
        relativePath: 'photos/image.jpg',
        parseStatus: 'skipped',
        errorCode: 'unsupported_media',
      ),
    ]);

    expect(report.totalFiles, 2);
    expect(report.supportedFiles, 1);
    expect(report.entries.last.reason, ImportCoverageReason.unsupportedMedia);
    expect(jsonEncode(report.counts), contains('"supported_files":1'));
  });
}
