import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/repositories/import_repository.dart';
import 'package:personal_data_agent/src/data/workspace/workspace_service.dart';
import 'package:personal_data_agent/src/domain/models/import_record.dart';

void main() {
  late Directory sandbox;
  late Directory root;
  late WorkspaceService workspace;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('pda-delete-workspace-');
    root = Directory('${sandbox.path}${Platform.pathSeparator}root');
    await root.create(recursive: true);
    workspace = WorkspaceService(rootDirectory: root);
  });

  tearDown(() async {
    await workspace.close();
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  Directory workspaceDirectory() =>
      Directory('${root.path}${Platform.pathSeparator}workspace');

  Future<void> writeSomeData() async {
    await workspace.open();
    await ImportRepository(workspace.database).insertImport(
      ImportRecord(
        platform: 'facebook',
        format: 'json',
        sourceFingerprint: 'sha256:fixture',
        startedAt: DateTime.utc(2026, 1, 2),
        importerVersion: '0.1.0',
        status: ImportStatus.completed,
      ),
      const [],
    );
  }

  test('removes the workspace folder and keeps no orphan files', () async {
    await writeSomeData();
    expect(await workspaceDirectory().exists(), isTrue);

    await workspace.deleteWorkspace();

    expect(await workspaceDirectory().exists(), isFalse);
    expect(workspace.isOpen, isFalse);
    expect(workspace.currentDatabasePath, isNull);
    expect(await workspace.workspaceExists(), isFalse);

    // Nothing named after the database, or any other file, is left behind.
    final leftovers = await root.list(recursive: true).toList();
    expect(leftovers, isEmpty);
    expect(await root.exists(), isTrue, reason: 'the root itself is kept');
  });

  test('deleting an already deleted workspace succeeds', () async {
    await writeSomeData();
    await workspace.deleteWorkspace();

    // Same service, then a fresh one: both are no-ops.
    await workspace.deleteWorkspace();
    final fresh = WorkspaceService(rootDirectory: root);
    addTearDown(fresh.close);
    await fresh.deleteWorkspace();

    expect(await workspaceDirectory().exists(), isFalse);
  });

  test('deleting a workspace that was never created succeeds', () async {
    final untouched = WorkspaceService(rootDirectory: root);
    addTearDown(untouched.close);

    await untouched.deleteWorkspace();

    expect(await untouched.workspaceExists(), isFalse);
    expect(await root.exists(), isTrue);
  });

  test(
    'unlinks a symbolic link inside the workspace instead of following it',
    () async {
      await writeSomeData();

      final outside = Directory(
        '${sandbox.path}${Platform.pathSeparator}outside',
      );
      await outside.create(recursive: true);
      final sentinel = File('${outside.path}${Platform.pathSeparator}keep.txt');
      await sentinel.writeAsString('must survive the workspace delete');

      final link = Link(
        '${workspaceDirectory().path}${Platform.pathSeparator}link',
      );
      try {
        await link.create(outside.path);
      } on FileSystemException catch (error) {
        markTestSkipped('This platform refuses symlink creation: $error');
        return;
      }
      expect(await link.exists(), isTrue);

      await workspace.deleteWorkspace();

      expect(await workspaceDirectory().exists(), isFalse);
      expect(await outside.exists(), isTrue);
      expect(
        await sentinel.readAsString(),
        'must survive the workspace delete',
      );
    },
  );

  test('refuses a workspace that resolves outside its root', () async {
    final outside = Directory(
      '${sandbox.path}${Platform.pathSeparator}outside',
    );
    await outside.create(recursive: true);
    final sentinel = File('${outside.path}${Platform.pathSeparator}keep.txt');
    await sentinel.writeAsString('outside content');

    // A crafted root whose `workspace` entry is a link to a folder elsewhere:
    // resolving it lands outside the root.
    await root.create(recursive: true);
    try {
      await Link(workspaceDirectory().path).create(outside.path);
    } on FileSystemException catch (error) {
      markTestSkipped('This platform refuses symlink creation: $error');
      return;
    }

    await expectLater(
      workspace.deleteWorkspace(),
      throwsA(
        isA<WorkspaceException>().having(
          (error) => error.code,
          'code',
          'workspace_outside_root',
        ),
      ),
    );

    expect(
      await outside.exists(),
      isTrue,
      reason: 'nothing outside is touched',
    );
    expect(await sentinel.readAsString(), 'outside content');
  });

  test(
    'refuses a dangling workspace link that points outside the root',
    () async {
      final outsidePath = '${sandbox.path}${Platform.pathSeparator}vanished';
      try {
        await Link(workspaceDirectory().path).create(outsidePath);
      } on FileSystemException catch (error) {
        markTestSkipped('This platform refuses symlink creation: $error');
        return;
      }

      await expectLater(
        workspace.deleteWorkspace(),
        throwsA(
          isA<WorkspaceException>().having(
            (error) => error.code,
            'code',
            'workspace_outside_root',
          ),
        ),
      );

      expect(
        FileSystemEntity.typeSync(
          workspaceDirectory().path,
          followLinks: false,
        ),
        FileSystemEntityType.link,
      );
      expect(Directory(outsidePath).existsSync(), isFalse);
    },
  );

  test('removes a stray file where the workspace folder belongs', () async {
    final stray = File(workspaceDirectory().path);
    await stray.writeAsString('not a workspace');

    await workspace.deleteWorkspace();

    expect(await stray.exists(), isFalse);
    expect(await root.exists(), isTrue);
  });
}
