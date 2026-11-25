import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test(
    'a version 5 database gains event_embeddings without embedding text',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pda-embeddings-v6-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/schema.sqlite';

      final version6 = AppDatabase(NativeDatabase(File(path)));
      await version6.customSelect('SELECT 1').get();
      // Reproduce a real v5 file: the table did not exist, and the recorded
      // version says so. Dropping it is safe because this test never inserts a
      // row into it before the upgrade.
      await version6.customStatement('DROP TABLE event_embeddings');
      await version6.customStatement('PRAGMA user_version = 5');
      await version6.close();

      final upgraded = AppDatabase(NativeDatabase(File(path)));
      await upgraded.customSelect('SELECT 1').get();

      expect(upgraded.schemaVersion, greaterThanOrEqualTo(6));
      final table = await upgraded
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'event_embeddings'",
          )
          .get();
      expect(table, hasLength(1));
      final index = await upgraded
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name = 'event_embeddings_model_id'",
          )
          .get();
      expect(index, hasLength(1));

      final count = await upgraded
          .customSelect('SELECT COUNT(*) AS n FROM event_embeddings')
          .getSingle();
      expect(count.read<int>('n'), 0);
      final version = await upgraded
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), greaterThanOrEqualTo(6));

      // The store holds no copy of message text: only the vector and its
      // identity metadata, so upgrading cannot expose another text copy.
      final columns = await upgraded
          .customSelect('PRAGMA table_info(event_embeddings)')
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        ['event_id', 'model_id', 'dim', 'vector'],
      );

      // Deletion is part of the schema, not a cleanup job: the upgraded table
      // must still cascade when an event goes away.
      final foreignKeys = await upgraded
          .customSelect('PRAGMA foreign_key_list(event_embeddings)')
          .get();
      expect(
        foreignKeys.any(
          (row) =>
              row.read<String>('table') == 'events' &&
              row.read<String>('on_delete') == 'CASCADE',
        ),
        isTrue,
      );
      await upgraded.close();
    },
  );
}
