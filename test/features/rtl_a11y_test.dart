import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/app/app.dart';
import 'package:personal_data_agent/src/core/l10n/app_strings.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/event_search_repository.dart';
import 'package:personal_data_agent/src/data/repositories/overview_repository.dart';
import 'package:personal_data_agent/src/data/repositories/timeline_repository.dart';
import 'package:personal_data_agent/src/features/home/home_screen.dart';
import 'package:personal_data_agent/src/features/overview/overview_controller.dart';
import 'package:personal_data_agent/src/features/overview/overview_screen.dart';
import 'package:personal_data_agent/src/features/search/search_controller.dart';
import 'package:personal_data_agent/src/features/search/search_screen.dart';
import 'package:personal_data_agent/src/features/search/search_service.dart';
import 'package:personal_data_agent/src/features/settings/settings_controller.dart';
import 'package:personal_data_agent/src/features/settings/settings_screen.dart';
import 'package:personal_data_agent/src/features/timeline/timeline_screen.dart';
import 'package:personal_data_agent/src/features/timeline/timeline_service.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';

/// Locale store that never touches the filesystem.
class _MemoryLocaleStore extends AppLocaleStore {
  const _MemoryLocaleStore();

  @override
  Future<AppLocaleMode?> read() async => null;

  @override
  Future<void> write(AppLocaleMode mode) async {}
}

class _FixedLocaleController extends AppLocaleController {
  _FixedLocaleController(this.mode);

  final AppLocaleMode mode;

  @override
  AppLocaleMode build() => mode;
}

/// One entry per screen the feature covers.
const Map<String, Widget> screens = <String, Widget>{
  'search': SearchScreen(),
  'timeline': TimelineScreen(),
  'overview': OverviewScreen(),
  'settings': SettingsScreen(),
};

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late Directory tempDirectory;
  late AppDatabase database;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('pda-rtl-a11y-');
    database = AppDatabase(NativeDatabase.memory());
    final archive = Archive()
      ..addFile(
        ArchiveFile.string(
          'messages/inbox/friends/message_1.json',
          jsonEncode({
            'title': 'Friends',
            'messages': [
              {
                'sender_name': 'Fixtures Person',
                'timestamp_ms': 1698796800000,
                'content': 'first synthetic message',
              },
              {
                'sender_name': 'Fixtures Person',
                'timestamp_ms': 1698883200000,
                'content': 'second synthetic message',
              },
              {
                'sender_name': 'Fixtures Person',
                'content': 'message with no timestamp',
              },
            ],
          }),
        ),
      )
      ..addFile(
        ArchiveFile.string(
          'posts/your_posts_1.json',
          jsonEncode({
            'posts': [
              {
                'timestamp': 1698883200,
                'data': [
                  {'post': 'a synthetic post'},
                ],
                'attachments': const [],
              },
            ],
          }),
        ),
      );
    final file = File('${tempDirectory.path}/rtl.zip');
    await file.writeAsBytes(ZipEncoder().encode(archive));
    await ImportCoordinator(database: database).importArchive(file);
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  /// Wires the screens to an in-memory database and a fixed language.
  Widget scoped(AppLocaleMode mode, Widget child) => ProviderScope(
    overrides: [
      appLocaleModeProvider.overrideWith(() => _FixedLocaleController(mode)),
      appLocaleStoreProvider.overrideWithValue(const _MemoryLocaleStore()),
      searchRepositoryProvider.overrideWith(
        (ref) async => EventSearchRepository(database),
      ),
      searchServiceProvider.overrideWith(
        (ref) async => SearchService(database),
      ),
      timelineRepositoryProvider.overrideWith(
        (ref) async => TimelineRepository(database),
      ),
      overviewRepositoryProvider.overrideWith(
        (ref) async => OverviewRepository(database),
      ),
      settingsInfoProvider.overrideWith(
        (ref) async => SettingsInfo(
          path: '/home/person/Library/Application Support/workspace',
          sizeBytes: 4096,
          consents: const [],
        ),
      ),
    ],
    child: child,
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    required AppLocaleMode mode,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      scoped(
        mode,
        MaterialApp(
          locale: Locale(mode.name),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(body: screen),
            ),
          ),
        ),
      ),
    );
    // A fixed pump instead of pumpAndSettle: screens may keep loaders alive.
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('Arabic mode makes the whole app right-to-left', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      scoped(AppLocaleMode.ar, const PersonalDataAgentApp()),
    );
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(HomeScreen))),
      TextDirection.rtl,
    );

    // The import prototype keeps its own wording and is only mirrored; it is
    // opened from the home screen.
    await tester.tap(find.byKey(const Key('home-import')));
    await tester.pumpAndSettle();
    expect(find.text('اختر مجلدًا'), findsOneWidget);
    expect(find.text('أو افتح أرشيف ZIP'), findsOneWidget);
    expect(find.text('الخصوصية والإعدادات'), findsOneWidget);
  });

  testWidgets('every covered screen is RTL and uses Arabic strings', (
    tester,
  ) async {
    for (final entry in screens.entries) {
      await pumpScreen(tester, entry.value, mode: AppLocaleMode.ar);

      expect(
        Directionality.of(tester.element(find.byWidget(entry.value))),
        TextDirection.rtl,
        reason: '${entry.key} should be right-to-left in Arabic',
      );
      expect(tester.takeException(), isNull, reason: entry.key);
    }

    await pumpScreen(tester, const SearchScreen(), mode: AppLocaleMode.ar);
    expect(find.text('البحث المتقدم'), findsOneWidget);
    expect(find.text('مسح المرشحات'), findsOneWidget);

    await pumpScreen(tester, const TimelineScreen(), mode: AppLocaleMode.ar);
    expect(find.text('الخط الزمني'), findsOneWidget);
    expect(find.text('تاريخ غير معروف'), findsOneWidget);

    await pumpScreen(tester, const OverviewScreen(), mode: AppLocaleMode.ar);
    expect(find.text('نظرة عامة'), findsOneWidget);

    await pumpScreen(tester, const SettingsScreen(), mode: AppLocaleMode.ar);
    expect(find.text('الخصوصية والإعدادات'), findsOneWidget);
  });

  testWidgets('LTR data stays readable inside the Arabic layout', (
    tester,
  ) async {
    await pumpScreen(tester, const SettingsScreen(), mode: AppLocaleMode.ar);

    final path = tester.widget<Text>(
      find.byKey(const Key('settings-workspace-path')),
    );
    expect(path.textDirection, TextDirection.ltr);
    expect(path.data, contains('Application Support/workspace'));
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('settings-workspace-path'))),
      ),
      TextDirection.rtl,
    );

    await pumpScreen(tester, const SearchScreen(), mode: AppLocaleMode.ar);
    await tester.enterText(
      find.byKey(const Key('search-query-field')),
      'first',
    );
    await tester.pump(const Duration(milliseconds: 300));

    final source = tester
        .widgetList<Text>(find.textContaining('المصدر:'))
        .first;
    expect(source.textDirection, TextDirection.ltr);
  });

  for (final entry in screens.entries) {
    testWidgets('${entry.key} renders at 1.5x text scale without overflow', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        entry.value,
        mode: AppLocaleMode.ar,
        textScale: 1.5,
      );

      expect(tester.takeException(), isNull);
      expect(find.byWidget(entry.value), findsOneWidget);
    });
  }

  testWidgets('primary actions keep a 44px pointer target', (tester) async {
    await pumpScreen(tester, const SearchScreen(), mode: AppLocaleMode.en);
    expect(
      tester.getSize(find.byKey(const Key('search-clear-filters'))).height,
      greaterThanOrEqualTo(44),
    );

    await pumpScreen(tester, const TimelineScreen(), mode: AppLocaleMode.en);
    expect(
      tester.getSize(find.byKey(const Key('timeline-clear-filters'))).height,
      greaterThanOrEqualTo(44),
    );

    await pumpScreen(tester, const SettingsScreen(), mode: AppLocaleMode.en);
    expect(
      tester.getSize(find.byKey(const Key('settings-delete-button'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byKey(const Key('settings-language-toggle'))).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('overview cards announce their number and purpose', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await pumpScreen(tester, const OverviewScreen(), mode: AppLocaleMode.en);

    final node = tester.getSemantics(
      find.byKey(const Key('overview-card-activity')),
    );
    expect(node.label, contains('Activity period'));
    expect(node.hint, 'Open the records behind this number');

    semantics.dispose();
  });
}
