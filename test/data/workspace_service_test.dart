import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:personal_data_agent/src/data/repositories/import_repository.dart';
import 'package:personal_data_agent/src/data/workspace/workspace_service.dart';
import 'package:personal_data_agent/src/domain/models/import_record.dart';
import 'package:personal_data_agent/src/domain/models/source_file.dart';

void main() {
  late Directory root;
  late WorkspaceService workspace;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pda-workspace-test-');
    workspace = WorkspaceService(rootDirectory: root);
  });

  tearDown(() async {
    await workspace.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  ImportRecord fixtureImport() => ImportRecord(
    platform: 'facebook',
    format: 'json',
    sourceFingerprint: 'sha256:fixture',
    startedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    importerVersion: '0.1.0',
    status: ImportStatus.completed,
  );

  test('creates the workspace folder inside the given root', () async {
    expect(await workspace.workspaceExists(), isFalse);
    expect(workspace.isOpen, isFalse);

    await workspace.open();

    expect(workspace.isOpen, isTrue);
    expect(await workspace.workspaceExists(), isTrue);

    final expectedDirectory = Directory(
      '${root.path}${Platform.pathSeparator}workspace',
    );
    expect(await expectedDirectory.exists(), isTrue);

    final path = workspace.currentDatabasePath;
    expect(path, isNotNull);
    expect(path, startsWith(expectedDirectory.path));
    expect(path, endsWith(WorkspaceService.databaseFileName));
    expect(await File(path!).exists(), isTrue);
  });

  test('keeps data written before close readable after reopen', () async {
    await workspace.open();
    final firstPath = workspace.currentDatabasePath;

    final repository = ImportRepository(workspace.database);
    final importId = await repository.insertImport(fixtureImport(), const [
      SourceFileRecord(
        relativePath: 'messages/inbox/message_1.json',
        parseStatus: ParseStatus.parsed,
      ),
    ]);

    await workspace.close();
    expect(workspace.isOpen, isFalse);
    expect(workspace.currentDatabasePath, isNull);
    expect(
      () => workspace.database,
      throwsA(isA<StateError>()),
      reason: 'a closed workspace must not hand out a database',
    );

    // A fresh service on the same root is what a restarted app does.
    final reopened = WorkspaceService(rootDirectory: root);
    addTearDown(reopened.close);
    await reopened.open();

    expect(reopened.currentDatabasePath, firstPath);

    final stored = await ImportRepository(
      reopened.database,
    ).findImport(importId);
    expect(stored, isNotNull);
    expect(stored!.importRecord.platform, 'facebook');
    expect(
      stored.sourceFiles.single.relativePath,
      'messages/inbox/message_1.json',
    );
  });

  test('reports a typed error when the root cannot hold a workspace', () async {
    // A file where the root folder should be: creating `<file>/workspace`
    // cannot succeed, on any platform and for any user.
    final blockingFile = File('${root.path}${Platform.pathSeparator}root.txt');
    await blockingFile.writeAsString('not a directory');

    final blocked = WorkspaceService(
      rootDirectory: Directory(blockingFile.path),
    );
    addTearDown(blocked.close);

    await expectLater(
      blocked.open(),
      throwsA(
        isA<WorkspaceException>()
            .having((error) => error.code, 'code', 'workspace_unavailable')
            .having((error) => error.cause, 'cause', isNotNull),
      ),
    );
    expect(blocked.isOpen, isFalse);
    expect(blocked.currentDatabasePath, isNull);
  });

  test('opening twice keeps one open database', () async {
    await workspace.open();
    final path = workspace.currentDatabasePath;
    final database = workspace.database;

    await workspace.open();

    expect(workspace.currentDatabasePath, path);
    expect(workspace.isOpen, isTrue);
    expect(
      identical(workspace.database, database),
      isTrue,
      reason: 'a second open must not replace the existing handle',
    );
  });

  test('a close during open leaves the workspace closed', () async {
    // close() invalidates the in-flight open before its first await, so the
    // open must discard the handle instead of publishing it.
    final opening = workspace.open();
    final closing = workspace.close();
    await Future.wait([opening, closing]);

    expect(workspace.isOpen, isFalse);
    expect(workspace.currentDatabasePath, isNull);
    expect(() => workspace.database, throwsA(isA<StateError>()));

    // A leaked sqlite handle would keep this folder locked on Windows, so a
    // successful recursive delete is part of the assertion.
    await root.delete(recursive: true);
    expect(await root.exists(), isFalse);
  });

  test('resolves a relative root to an absolute database path', () async {
    final previousDirectory = Directory.current;
    final relativeRoot = await Directory.systemTemp.createTemp(
      'pda-relative-root-',
    );
    addTearDown(() async {
      Directory.current = previousDirectory;
      if (await relativeRoot.exists()) {
        await relativeRoot.delete(recursive: true);
      }
    });
    Directory.current = relativeRoot;

    final relativeWorkspace = WorkspaceService(
      rootDirectory: Directory('relative-root'),
    );
    addTearDown(relativeWorkspace.close);
    await relativeWorkspace.open();

    final path = relativeWorkspace.currentDatabasePath;
    expect(path, isNotNull);
    expect(p.isAbsolute(path!), isTrue);
    expect(path, contains('relative-root'));
  });
}
