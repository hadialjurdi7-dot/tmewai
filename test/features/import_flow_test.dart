import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/app/workspace_provider.dart';
import 'package:personal_data_agent/src/core/l10n/app_strings.dart';
import 'package:personal_data_agent/src/data/workspace/workspace_service.dart';
import 'package:personal_data_agent/src/features/home/home_controller.dart';
import 'package:personal_data_agent/src/features/import/import_controller.dart';
import 'package:personal_data_agent/src/features/messages/messages_controller.dart';

const _fixturePath = 'test/fixtures/facebook_export';

typedef _TestWorkspace = ({
  Directory root,
  WorkspaceService workspace,
  ProviderContainer container,
});

Future<_TestWorkspace> _testWorkspace(String prefix) async {
  final root = await Directory.systemTemp.createTemp(prefix);
  final workspace = WorkspaceService(
    rootDirectory: Directory('${root.path}/workspace'),
  );
  await workspace.open();
  final container = ProviderContainer(
    overrides: [
      workspaceProvider.overrideWith((ref) async => workspace),
      appLocaleModeProvider.overrideWith(() => _FixedLocaleController()),
      appLocaleStoreProvider.overrideWithValue(const _MemoryLocaleStore()),
    ],
  );
  return (root: root, workspace: workspace, container: container);
}

Future<void> _closeWorkspace(_TestWorkspace test) async {
  test.container.dispose();
  await test.workspace.close();
  await test.root.delete(recursive: true);
}

class _MemoryLocaleStore extends AppLocaleStore {
  const _MemoryLocaleStore();

  @override
  Future<AppLocaleMode?> read() async => AppLocaleMode.en;

  @override
  Future<void> write(AppLocaleMode mode) async {}
}

class _FixedLocaleController extends AppLocaleController {
  @override
  AppLocaleMode build() => AppLocaleMode.en;
}

void _copyFixture(Directory destination) {
  for (final entity in Directory(_fixturePath).listSync(recursive: true)) {
    if (entity is! File) continue;
    final relative = entity.path.substring(_fixturePath.length + 1);
    final target = File('${destination.path}/$relative');
    target.parent.createSync(recursive: true);
    entity.copySync(target.path);
  }
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test(
    'imports a Facebook-shaped folder and refreshes archive snapshots',
    () async {
      final testWorkspace = await _testWorkspace('import-flow-success-');
      final folder = Directory('${testWorkspace.root.path}/export')
        ..createSync();
      _copyFixture(folder);
      addTearDown(() => _closeWorkspace(testWorkspace));

      expect(
        (await testWorkspace.container.read(homeSnapshotProvider.future))
            .isEmpty,
        isTrue,
      );
      expect(
        (await testWorkspace.container.read(messagesSnapshotProvider.future))
            .isEmpty,
        isTrue,
      );

      await testWorkspace.container
          .read(importRunProvider.notifier)
          .run(folder.path);

      final state = testWorkspace.container.read(importRunProvider);
      expect(state.progress?.recordsWritten, greaterThan(0));
      expect(state.outcome, isNotNull);
      expect(state.outcome!.events, greaterThan(0));
      expect(
        (await testWorkspace.container.read(homeSnapshotProvider.future))
            .isEmpty,
        isFalse,
      );
      expect(
        (await testWorkspace.container.read(messagesSnapshotProvider.future))
            .isEmpty,
        isFalse,
      );
    },
  );

  test('unrelated JSON fails without writing rows', () async {
    final testWorkspace = await _testWorkspace('import-flow-failure-');
    final folder = Directory('${testWorkspace.root.path}/unrelated')
      ..createSync();
    File('${folder.path}/project/config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"name":"unrelated project"}');
    addTearDown(() => _closeWorkspace(testWorkspace));

    await testWorkspace.container
        .read(importRunProvider.notifier)
        .run(folder.path);

    final state = testWorkspace.container.read(importRunProvider);
    expect(state.errorCode, 'no_supported_files_found');
    expect(state.outcome, isNull);
    final database = testWorkspace.workspace.database;
    expect(await database.select(database.imports).get(), isEmpty);
    expect(await database.select(database.sourceFiles).get(), isEmpty);
    expect(await database.select(database.people).get(), isEmpty);
    expect(await database.select(database.conversations).get(), isEmpty);
    expect(await database.select(database.events).get(), isEmpty);
    expect(await database.select(database.attachments).get(), isEmpty);
  });
}
