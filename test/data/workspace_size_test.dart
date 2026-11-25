import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/workspace/workspace_service.dart';

/// `workspaceSizeBytes` is the number the settings screen shows as «size on
/// disk»: it must count real files, never follow a link out of the workspace,
/// and degrade to 0 instead of throwing when the folder is gone.
void main() {
  late Directory sandbox;
  late Directory root;
  late WorkspaceService workspace;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('pda-workspace-size-');
    root = Directory('${sandbox.path}${Platform.pathSeparator}root');
    await root.create(recursive: true);
    workspace = WorkspaceService(rootDirectory: root);
  });

  tearDown(() async {
    await workspace.close();
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('a workspace that was never opened has no size', () async {
    expect(workspace.isOpen, isFalse);
    expect(await workspace.workspaceSizeBytes(), 0);
  });

  test('counts nested files on top of the database file', () async {
    await workspace.open();
    final databaseBytes = await File(workspace.currentDatabasePath!).length();
    expect(databaseBytes, greaterThan(0));

    final start = await workspace.workspaceSizeBytes();
    expect(
      start,
      greaterThanOrEqualTo(databaseBytes),
      reason: 'the open database is part of the workspace size',
    );

    final nested = Directory(
      '${workspace.workspaceDirectory!.path}'
      '${Platform.pathSeparator}nested${Platform.pathSeparator}deeper',
    );
    await nested.create(recursive: true);
    await File('${nested.path}${Platform.pathSeparator}a.bin')
        .writeAsBytes(List<int>.filled(1234, 7));
    await File(
      '${workspace.workspaceDirectory!.path}${Platform.pathSeparator}b.bin',
    ).writeAsBytes(List<int>.filled(2000, 7));

    expect(await workspace.workspaceSizeBytes(), start + 1234 + 2000);
  });

  test('skips a symbolic link instead of measuring its target', () async {
    await workspace.open();
    final withoutLink = await workspace.workspaceSizeBytes();

    final outside = File('${sandbox.path}${Platform.pathSeparator}outside.bin');
    await outside.writeAsBytes(List<int>.filled(64 * 1024, 3));
    final link = Link(
      '${workspace.workspaceDirectory!.path}${Platform.pathSeparator}link.bin',
    );
    try {
      await link.create(outside.path);
    } on FileSystemException catch (error) {
      markTestSkipped('This platform refuses symlink creation: $error');
      return;
    }

    // A followed link would add the outside file's 64 KB and expose a path
    // outside the workspace; the measured size must not move at all.
    expect(await workspace.workspaceSizeBytes(), withoutLink);
    expect(await outside.length(), 64 * 1024);
  });

  test('returns zero when the workspace folder disappeared', () async {
    await workspace.open();
    final directory = workspace.workspaceDirectory!;
    // Close before deleting: on Windows an open SQLite handle keeps the folder
    // locked, so removing it while the database is live fails with errno 32 and
    // the test flakes on the Windows build instead of testing the vanished folder.
    await workspace.close();
    await directory.delete(recursive: true);

    expect(await workspace.workspaceSizeBytes(), 0);
  });
}
