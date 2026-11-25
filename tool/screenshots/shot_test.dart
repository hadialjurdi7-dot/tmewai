import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/app/app_shell.dart';
import 'package:personal_data_agent/src/core/design/theme.dart';
import 'package:personal_data_agent/src/core/l10n/app_strings.dart';
import 'package:personal_data_agent/src/data/repositories/overview_repository.dart';
import 'package:personal_data_agent/src/data/repositories/timeline_repository.dart';
import 'package:personal_data_agent/src/features/analytics/analytics_controller.dart';
import 'package:personal_data_agent/src/features/analytics/analytics_service.dart';
import 'package:personal_data_agent/src/features/home/home_controller.dart';
import 'package:personal_data_agent/src/features/home/home_service.dart';
import 'package:personal_data_agent/src/features/media/media_controller.dart';
import 'package:personal_data_agent/src/features/media/media_service.dart';
import 'package:personal_data_agent/src/features/messages/messages_controller.dart';
import 'package:personal_data_agent/src/features/messages/messages_service.dart';
import 'package:personal_data_agent/src/features/people/person_controller.dart';
import 'package:personal_data_agent/src/features/people/person_service.dart';

/// Renders the real shell to a PNG so the layout can be compared with
/// `design/reference/stitch/home.html`.
/// Run with `flutter test --update-goldens tool/screenshots/shot_test.dart`.
final populatedHome = HomeSnapshot(
  totals: ArchiveTotals(
    messages: 12480,
    photos: 3204,
    people: 164,
    days: 4700,
    events: 82341,
    first: DateTime.utc(2011, 5, 3),
    last: DateTime.utc(2023, 6, 1),
  ),
  topPeople: const [
    HomePerson(id: 1, name: 'ليلى خالد', count: 1284),
    HomePerson(id: 2, name: 'عمر بيطار', count: 940),
    HomePerson(id: 3, name: 'خالتي أم سامر', count: 720),
    HomePerson(id: 4, name: 'سامر العبدالله', count: 512),
    HomePerson(id: 5, name: 'أبو كريم (المحل)', count: 385),
  ],
  latest: [
    TimelineRow(
      eventId: 11,
      eventType: 'message',
      sourceLocator: 'messages/inbox/one.json',
      timestampNormalized: DateTime.utc(2023, 6, 1),
      textContent: 'أجمل قعدة مع العيلة، يوم ما بينتسى مع الضحكة والجمعة الحلوة.',
    ),
    TimelineRow(
      eventId: 12,
      eventType: 'post',
      sourceLocator: 'posts/your_posts_1.json',
      timestampNormalized: DateTime.utc(2019, 3, 12),
      textContent: 'كل عام وانتي بخير يا خالتي، عقبال المية يا رب.',
    ),
  ],
);

const emptyAnalytics = AnalyticsSnapshot(
  selectedYear: null,
  years: [],
  totals: ArchiveTotals(messages: 0, photos: 0, people: 0, days: 0, events: 0),
  months: [],
  hours: [],
  types: [],
  people: [],
);

const emptyMessages = MessagesSnapshot(
  conversations: [],
  totalConversations: 0,
  selected: null,
);

const emptyMedia = MediaSnapshot(
  total: 0,
  years: [],
  selectedYear: null,
  items: [],
  people: [],
  matched: 0,
  limit: 60,
);

const emptyPerson = PersonSnapshot(people: [], selected: null);

class _ArabicLocale extends AppLocaleController {
  @override
  AppLocaleMode build() => AppLocaleMode.ar;
}

class _MemoryLocaleStore extends AppLocaleStore {
  const _MemoryLocaleStore();

  @override
  Future<AppLocaleMode?> read() async => null;

  @override
  Future<void> write(AppLocaleMode mode) async {}
}

/// Reads the TTFs off disk: `rootBundle` does not resolve declared fonts
/// inside `flutter test`, and an unloaded family renders as Ahem boxes.
Future<void> _loadFonts() async {
  final loader = FontLoader('IBMPlexSansArabic');
  for (final path in const [
    'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'assets/fonts/IBMPlexSansArabic-Medium.ttf',
    'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
    'assets/fonts/IBMPlexSansArabic-Bold.ttf',
  ]) {
    final bytes = await File(path).readAsBytes();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();

  // Icons are a font too; without it every Icon is a box in the PNG.
  final icons = FontLoader('MaterialIcons');
  final iconPath =
      '${Platform.environment['FLUTTER_ROOT'] ?? 'flutter'}'
      '/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final iconBytes = await File(iconPath).readAsBytes();
  icons.addFont(Future.value(ByteData.view(iconBytes.buffer)));
  await icons.load();
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('home screenshot', (tester) async {
    tester.view.physicalSize = const Size(1600, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeSnapshotProvider.overrideWith((ref) async => populatedHome),
          analyticsSnapshotProvider.overrideWith(
            (ref) async => emptyAnalytics,
          ),
          messagesSnapshotProvider.overrideWith((ref) async => emptyMessages),
          mediaSnapshotProvider.overrideWith((ref) async => emptyMedia),
          personSnapshotProvider.overrideWith((ref) async => emptyPerson),
          appLocaleModeProvider.overrideWith(_ArabicLocale.new),
          appLocaleStoreProvider.overrideWithValue(const _MemoryLocaleStore()),
        ],
        child: MaterialApp(
          theme: buildTmewaiTheme(),
          home: AppShell(
            importPageBuilder: (context) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(AppShell),
      matchesGoldenFile('goldens/shell_home.png'),
    );
  });
}
