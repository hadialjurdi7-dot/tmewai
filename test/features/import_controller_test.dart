import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/app/workspace_provider.dart';
import 'package:personal_data_agent/src/data/workspace/workspace_service.dart';
import 'package:personal_data_agent/src/features/analytics/analytics_controller.dart';
import 'package:personal_data_agent/src/features/home/home_controller.dart';
import 'package:personal_data_agent/src/features/import/import_controller.dart';
import 'package:personal_data_agent/src/features/media/media_controller.dart';
import 'package:personal_data_agent/src/features/messages/messages_controller.dart';
import 'package:personal_data_agent/src/features/people/person_controller.dart';

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  test(
    'imports through the UI controller and refreshes archive screens',
    () async {
      final temp = await Directory.systemTemp.createTemp('import-controller-');
      final workspace = WorkspaceService(rootDirectory: temp);
      await workspace.open();
      final container = ProviderContainer(
        overrides: [workspaceProvider.overrideWith((ref) async => workspace)],
      );
      addTearDown(() async {
        container.dispose();
        await workspace.close();
        await temp.delete(recursive: true);
      });

      expect(
        (await container.read(homeSnapshotProvider.future)).isEmpty,
        isTrue,
      );
      expect(
        (await container.read(messagesSnapshotProvider.future)).isEmpty,
        isTrue,
      );
      expect(
        (await container.read(mediaSnapshotProvider.future)).isEmpty,
        isTrue,
      );
      expect(
        (await container.read(personSnapshotProvider.future)).isEmpty,
        isTrue,
      );
      expect(
        (await container.read(analyticsSnapshotProvider.future)).isEmpty,
        isTrue,
      );

      await container
          .read(importRunProvider.notifier)
          .run('test/fixtures/facebook_export');

      final result = container.read(importRunProvider);
      expect(result.outcome, isNotNull);
      expect(result.errorCode, isNull);
      expect(result.outcome!.events, 5);
      expect(result.outcome!.attachments, 2);
      expect(
        (await container.read(homeSnapshotProvider.future)).isEmpty,
        isFalse,
      );
      expect(
        (await container.read(messagesSnapshotProvider.future)).isEmpty,
        isFalse,
      );
      expect(
        (await container.read(mediaSnapshotProvider.future)).isEmpty,
        isFalse,
      );
      expect(
        (await container.read(personSnapshotProvider.future)).isEmpty,
        isFalse,
      );
      expect(
        (await container.read(analyticsSnapshotProvider.future)).isEmpty,
        isFalse,
      );
    },
  );
}
