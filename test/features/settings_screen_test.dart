import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/app/workspace_provider.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/ai_consent_repository.dart';
import 'package:personal_data_agent/src/data/workspace/workspace_service.dart';
import 'package:personal_data_agent/src/domain/models/ai_consent.dart';
import 'package:personal_data_agent/src/features/settings/settings_controller.dart';
import 'package:personal_data_agent/src/features/settings/settings_screen.dart';
import 'package:personal_data_agent/src/features/home/home_controller.dart';
import 'package:personal_data_agent/src/features/analytics/analytics_controller.dart';
import 'package:personal_data_agent/src/features/messages/messages_controller.dart';
import 'package:personal_data_agent/src/features/media/media_controller.dart';

/// Workspace that deletes with synchronous filesystem calls, so a widget test
/// never waits on platform I/O inside the fake async zone.
class _TestWorkspace extends WorkspaceService {
  _TestWorkspace(this.workspacePath) : super();

  final String workspacePath;

  @override
  Future<void> deleteWorkspace() async {
    final directory = Directory(workspacePath);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  }
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late Directory root;
  late _TestWorkspace workspace;
  late AppDatabase database;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pda-settings-test-');
    workspace = _TestWorkspace('${root.path}/workspace');
    await Directory('${root.path}/workspace').create(recursive: true);
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workspaceProvider.overrideWith((ref) async => workspace),
          settingsInfoProvider.overrideWith((ref) async {
            final consents = await AiConsentRepository(database).findAll();
            return SettingsInfo(
              path: '${root.path}/workspace',
              sizeBytes: 4096,
              consents: consents,
            );
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders consent history from ai_consents', (tester) async {
    await AiConsentRepository(database).insert(
      AiConsentRecord(
        providerId: 'fake_provider',
        policyVersion: '2026-10-01',
        scopeSummary: 'events:2; chars:20; bytes:20; model:tiny',
        grantedAt: DateTime.utc(2026, 10, 26, 9, 30),
        eventCount: 2,
        byteCount: 20,
      ),
    );

    await pumpSettings(tester);

    expect(find.text('AI consent history'), findsOneWidget);
    expect(find.textContaining('fake_provider · 2026-10-01'), findsOneWidget);
    expect(find.textContaining('2026-10-26 09:30 UTC'), findsOneWidget);
    expect(find.textContaining('tiny'), findsNothing);
    expect(find.byKey(const Key('settings-workspace-path')), findsOneWidget);
    expect(find.textContaining('4.0 KB'), findsOneWidget);
    expect(find.byKey(const Key('settings-delete-hint')), findsOneWidget);
  });

  testWidgets('delete stays blocked until the word DELETE is typed', (
    tester,
  ) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('settings-delete-button')));
    await tester.pumpAndSettle();

    FilledButton confirm() => tester.widget<FilledButton>(
      find.byKey(const Key('settings-delete-confirm-button')),
    );

    expect(confirm().onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('settings-delete-confirm-field')),
      'delete',
    );
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNull);
    expect(
      await tester.runAsync(() => Directory('${root.path}/workspace').exists()),
      isTrue,
    );

    await tester.enterText(
      find.byKey(const Key('settings-delete-confirm-field')),
      ' DELETE ',
    );
    await tester.pumpAndSettle();
    expect(confirm().onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('settings-delete-confirm-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-deleted-state')), findsOneWidget);
    expect(find.text('Start by importing a data export.'), findsOneWidget);
    expect(workspace.isOpen, isFalse);
    expect(
      await tester.runAsync(() => Directory('${root.path}/workspace').exists()),
      isFalse,
      reason: 'the workspace folder is gone',
    );
  });

  test('successful deletion clears every mounted archive snapshot', () async {
    final container = ProviderContainer.test(
      overrides: [workspaceProvider.overrideWith((ref) async => workspace)],
    );

    expect(
      await container
          .read(settingsControllerProvider.notifier)
          .deleteWorkspace(),
      isTrue,
    );
    expect(container.read(workspaceDeletedProvider), isTrue);

    final home = await container.read(homeSnapshotProvider.future);
    final analytics = await container.read(analyticsSnapshotProvider.future);
    final messages = await container.read(messagesSnapshotProvider.future);
    final media = await container.read(mediaSnapshotProvider.future);

    expect(home.totals.events, 0);
    expect(analytics.totals.events, 0);
    expect(messages.conversations, isEmpty);
    expect(messages.selected, isNull);
    expect(media.items, isEmpty);
  });

  testWidgets('cancelling the dialog leaves the workspace intact', (
    tester,
  ) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('settings-delete-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-deleted-state')), findsNothing);
    expect(
      await tester.runAsync(() => Directory('${root.path}/workspace').exists()),
      isTrue,
    );
  });
}
