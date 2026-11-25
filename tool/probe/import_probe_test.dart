// Headless probe of the real import pipeline against real folders on disk.
//
// Purpose: exercise ExportInspector + FacebookJsonImporter exactly as the app
// does, print one line per failure with its error code, and write a machine
// readable report. Not part of the shipped app.
//
// Run: $FLUTTER_ROOT/bin/flutter test tool/probe/import_probe_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/services/importing/archive_inspector.dart';
import 'package:personal_data_agent/src/services/importing/facebook_json_importer.dart';

/// A Facebook-shaped export: the layout Meta actually ships, including the
/// wrapper folder and the files this app claims to support.
const Map<String, String> facebookExport = {
  'your_activity_across_facebook/messages/inbox/layla_123456/message_1.json':
      '{"participants":[{"name":"ليلى خالد"},{"name":"سامر خالد"}],'
          '"messages":['
          '{"sender_name":"ليلى خالد","timestamp_ms":1552345200000,'
          '"content":"كيفك يا خيي؟","is_geoblocked_for_viewer":false},'
          '{"sender_name":"سامر خالد","timestamp_ms":1552345260000,'
          '"content":"تمام الحمد لله","photos":[{"uri":"messages/inbox/'
          'layla_123456/photos/1.jpg","creation_timestamp":1552345200}]}'
          '],"title":"ليلى خالد","is_still_participant":true,'
          '"thread_path":"inbox/layla_123456"}',
  'your_activity_across_facebook/comments/comments.json':
      '{"comments_v2":[{"timestamp":1552345200,"data":[{"comment":'
          '{"timestamp":1552345200,"comment":"مبروك المحل الجديد",'
          '"author":"سامر خالد"}}]}]}',
  'your_activity_across_facebook/likes_and_reactions/likes_and_reactions_1.json':
      '{"reactions_v2":[{"timestamp":1552345200,"data":[{"reaction":'
          '{"reaction":"😍","actor":"سامر خالد"}}]}]}',
  'your_activity_across_facebook/posts/your_posts__check_ins__photos_and_videos_1.json':
      '[{"timestamp":1552345200,"data":[{"post":"أجمل قعدة مع العيلة"}],'
          '"attachments":[{"data":[{"media":{"uri":"posts/media/1.jpg",'
          '"creation_timestamp":1552345200}}]}],"title":"سامر خالد posted"}]',
  // Files the app does not classify: they must be reported, not fatal.
  'your_activity_across_facebook/profile_information/profile_information.json':
      '{"profile_v2":{"name":{"full_name":"سامر خالد"}}}',
  'your_activity_across_facebook/friends_and_followers/friends.json':
      '{"friends_v2":[{"name":"عمر بيطار"}]}',
};

/// A folder that is real, readable and simply not a Facebook export - what the
/// user actually selected when the app said "unsupported JSON file".
const Map<String, String> unrelatedProject = {
  'README.md': '# مشروع فك تشفير بياناتي\n',
  'package.json': '{"name":"my-project","version":"1.0.0"}',
  'src/main.py': 'print("hello")\n',
  'data/config.json': '{"key":"value"}',
};

void writeTree(Directory root, Map<String, String> files) {
  for (final entry in files.entries) {
    final file = File('${root.path}/${entry.key}');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(entry.value);
  }
}

Map<String, Object?> summarize(FacebookImportPreview preview) => {
  'records': preview.records.length,
  'byType': {
    for (final type in ['message', 'comment', 'reaction', 'post'])
      type: preview.records.where((record) => record.eventType == type).length,
  },
  'supportedFiles': preview.supportedFiles,
  'unsupportedJsonFiles': preview.unsupportedJsonFiles,
  'skippedRecords': preview.skippedRecords,
  'attachments': preview.attachments.length,
  'warnings': preview.warnings,
  'files': [
    for (final file in preview.files) '${file.status.name}: ${file.path}',
  ],
};

Future<Map<String, Object?>> probe(String label, Directory root) async {
  final report = <String, Object?>{'case': label, 'path': root.path};
  try {
    final inspection = await const ExportInspector().inspect(root.path);
    report['inspection'] = {
      'entries': inspection.entries,
      'expandedBytes': inspection.totalExpandedBytes,
      'jsonFiles': inspection.jsonFiles,
      'mediaFiles': inspection.mediaFiles,
      'ignoredFiles': inspection.ignoredFiles,
      'warnings': inspection.warnings,
    };
  } on ArchiveInspectionException catch (error) {
    report['inspectionError'] = error.code;
    report['inspectionMessage'] = error.message;
  } on Object catch (error) {
    report['inspectionError'] = 'uncaught: $error';
  }
  try {
    final preview = await const FacebookJsonImporter().previewSource(root.path);
    report['preview'] = summarize(preview);
  } on ArchiveInspectionException catch (error) {
    report['previewError'] = error.code;
    report['previewMessage'] = error.message;
  } on FacebookImportException catch (error) {
    report['previewError'] = error.code;
    report['previewMessage'] = error.message;
  } on Object catch (error) {
    report['previewError'] = 'uncaught: $error';
  }
  return report;
}

void main() {
  test('probe real import sources', () async {
    final base = Directory('/tmp/tmewai-probe')..createSync(recursive: true);
    final reports = <Map<String, Object?>>[];

    final facebook = Directory('${base.path}/facebook_export')..createSync();
    writeTree(facebook, facebookExport);
    reports.add(await probe('facebook-shaped export folder', facebook));

    final zip = File('${base.path}/facebook_export.zip');
    if (!zip.existsSync()) {
      final result = Process.runSync('python3', [
        '-c',
        'import shutil,sys;shutil.make_archive("${base.path}/facebook_export","zip","${facebook.path}")',
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
    }
    final zipInspection = await const ExportInspector().inspect(zip.path);
    final zipPreview = await const FacebookJsonImporter().preview(zip);
    reports.add({
      'case': 'facebook-shaped export ZIP',
      'path': zip.path,
      'inspection': {
        'entries': zipInspection.entries,
        'jsonFiles': zipInspection.jsonFiles,
        'warnings': zipInspection.warnings,
      },
      'preview': summarize(zipPreview),
    });

    final unrelated = Directory('${base.path}/unrelated_project')..createSync();
    writeTree(unrelated, unrelatedProject);
    reports.add(await probe('unrelated project folder', unrelated));

    final empty = Directory('${base.path}/empty_folder')..createSync();
    reports.add(await probe('empty folder', empty));

    final report = File('/tmp/tmewai-probe/report.json');
    report.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(reports));

    final failures = <String>[];
    for (final entry in reports) {
      final error = entry['previewError'] ?? entry['inspectionError'];
      if (error != null) failures.add('${entry['case']}: $error');
    }
    // ignore: avoid_print
    print('PROBE_REPORT ${report.path}');
    // ignore: avoid_print
    print(const JsonEncoder.withIndent('  ').convert(reports));
    // ignore: avoid_print
    print('PROBE_FAILURES ${failures.length}: $failures');
  });
}
