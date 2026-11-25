import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/services/importing/facebook_json_importer.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

const _fixturePath = 'test/fixtures/facebook_export';

Future<File> _zipFixture(Directory temp) async {
  final archive = Archive();
  await for (final entity in Directory(_fixturePath).list(recursive: true)) {
    if (entity is! File) continue;
    final relative = entity.path.substring(_fixturePath.length + 1);
    archive.addFile(ArchiveFile.bytes(relative, await entity.readAsBytes()));
  }
  final file = File('${temp.path}/facebook_export.zip');
  await file.writeAsBytes(ZipEncoder().encode(archive));
  return file;
}

Map<String, int> _counts(FacebookImportPreview preview) => {
  for (final type in const ['message', 'comment', 'reaction', 'post'])
    type: preview.records.where((record) => record.eventType == type).length,
  'attachment': preview.attachments.length,
};

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test(
    'imports Facebook-shaped folder and its ZIP with all supported types',
    () async {
      final temp = await Directory.systemTemp.createTemp('facebook-fixture-');
      final folderDatabase = AppDatabase(NativeDatabase.memory());
      final zipDatabase = AppDatabase(NativeDatabase.memory());
      final folderCoordinator = ImportCoordinator(database: folderDatabase);
      final zipCoordinator = ImportCoordinator(database: zipDatabase);
      addTearDown(() async {
        await folderCoordinator.dispose();
        await zipCoordinator.dispose();
        await folderDatabase.close();
        await zipDatabase.close();
        await temp.delete(recursive: true);
      });

      final folderPreview = await const FacebookJsonImporter().previewSource(
        Directory(_fixturePath).path,
      );
      final zip = await _zipFixture(temp);
      final zipPreview = await const FacebookJsonImporter().preview(zip);

      const expected = {
        'message': 2,
        'comment': 1,
        'reaction': 1,
        'post': 1,
        'attachment': 2,
      };
      expect(_counts(folderPreview), expected);
      expect(_counts(zipPreview), expected);
      expect(folderPreview.warnings, isNot(contains('attachment_missing')));
      expect(zipPreview.warnings, isNot(contains('attachment_missing')));
      expect(
        folderPreview.attachments.map((a) => a.relativePath),
        containsAll([
          'your_activity_across_facebook/messages/inbox/layla_123456/photos/1.jpg',
          'your_activity_across_facebook/posts/media/1.jpg',
        ]),
      );

      final folderResult =
          await folderCoordinator.importSource(_fixturePath) as ImportOutcome;
      final zipResult =
          await zipCoordinator.importArchive(zip) as ImportOutcome;
      expect(folderResult.events, 5);
      expect(folderResult.attachments, 2);
      expect(zipResult.events, 5);
      expect(zipResult.attachments, 2);
      expect(
        (await folderDatabase.select(folderDatabase.events).get())
            .map((event) => event.eventType)
            .toSet(),
        {'message', 'comment', 'reaction', 'post'},
      );
      expect(
        await zipDatabase.select(zipDatabase.attachments).get(),
        hasLength(2),
      );
    },
  );
}
