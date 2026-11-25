// Probe: يشغّل خط الاستيراد الحقيقي (ArchiveInspector + FacebookJsonImporter)
// على أرشيف صناعي كبير موجود على القرص — مش أرشيف صغير مكتوب بالكود.
//
// Run: $FLUTTER_ROOT/bin/flutter test test/probe_big_export_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/services/importing/archive_inspector.dart';
import 'package:personal_data_agent/src/services/importing/facebook_json_importer.dart';

/// Generated locally, never committed (see `.gitignore`). Override with
/// `SYNTHETIC_EXPORT_ZIP=/path/to/facebook-export.zip` in CI.
String get _zip =>
    Platform.environment['SYNTHETIC_EXPORT_ZIP'] ??
    'build/synthetic/facebook-export.zip';

void main() {
  test('archive inspector + importer on the big synthetic export', () async {
    final file = File(_zip);
    if (!file.existsSync()) {
      // The big export is generated locally, not committed:
      //   python3 test/fixtures/make_export.py build/synthetic
      markTestSkipped('$_zip not generated');
      return;
    }

    final inspection = await ArchiveInspector().inspect(file);
    // ignore: avoid_print
    print('INSPECT entries=${inspection.entries} json=${inspection.jsonFiles} '
        'media=${inspection.mediaFiles} ignored=${inspection.ignoredFiles} '
        'warnings=${inspection.warnings.length}');

    final preview = await FacebookJsonImporter().preview(file);
    final convs = preview.records.where((r) => r.conversationKey != null).length;
    // ignore: avoid_print
    print('IMPORT records=${preview.records.length} inConversations=$convs '
        'supportedFiles=${preview.supportedFiles} '
        'skipped=${preview.skippedRecords} '
        'attachments=${preview.attachments.length} '
        'warnings=${preview.warnings.length}');
    for (final w in preview.warnings.take(5)) {
      // ignore: avoid_print
      print('WARN $w');
    }
    for (final f in preview.files.where((f) => f.errorCode != null).take(5)) {
      // ignore: avoid_print
      print('FILE-ERR ${f.path} code=${f.errorCode}');
    }

    expect(preview.records, isNotEmpty);
    expect(preview.supportedFiles, greaterThan(400));
  });
}
