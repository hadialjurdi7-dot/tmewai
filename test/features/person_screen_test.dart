import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/core/l10n/app_strings.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/data/repositories/attachment_repository.dart';
import 'package:personal_data_agent/src/data/repositories/overview_repository.dart';
import 'package:personal_data_agent/src/data/repositories/person_repository.dart';
import 'package:personal_data_agent/src/domain/models/event_record.dart';
import 'package:personal_data_agent/src/domain/models/import_record.dart';
import 'package:personal_data_agent/src/domain/models/source_file.dart';
import 'package:personal_data_agent/src/features/media/media_controller.dart';
import 'package:personal_data_agent/src/features/media/media_service.dart';
import 'package:personal_data_agent/src/features/overview/overview_controller.dart';
import 'package:personal_data_agent/src/features/people/person_controller.dart';
import 'package:personal_data_agent/src/features/people/person_screen.dart';
import 'package:personal_data_agent/src/features/people/person_service.dart';

const _people = [
  PersonSummary(id: 1, name: 'ليلى خالد', messageCount: 1284),
  PersonSummary(id: 2, name: 'عمر بيطار', messageCount: 340),
];

final _leila = PersonProfile(
  id: 1,
  name: 'ليلى خالد',
  platform: 'facebook',
  platformPersonId: 'fb-1001',
  messageCount: 1284,
  messageTotal: 1284,
  photoCount: 214,
  firstAt: DateTime.utc(2013, 3, 12),
  lastAt: DateTime.utc(2024, 6, 1),
  days: 512,
  conversationId: 7,
  years: const [
    PersonYear(year: 2019, count: 120),
    PersonYear(year: 2020, count: 0),
    PersonYear(year: 2021, count: 248),
  ],
  lines: [
    PersonLine(
      id: 101,
      at: DateTime.utc(2019, 3, 12, 10, 14),
      text: 'صباح الخير يا صديقي',
    ),
    PersonLine(
      id: 102,
      at: DateTime.utc(2021, 8, 24, 9, 5),
      text: 'ذكرى السنة',
    ),
  ],
  photos: [
    MediaItem(
      id: 501,
      mediaType: 'image',
      sizeBytes: 1024,
      at: DateTime.utc(2019, 3, 12),
      hasPath: true,
    ),
    MediaItem(
      id: 502,
      mediaType: 'image',
      sizeBytes: 2048,
      at: DateTime.utc(2021, 8, 24),
      hasPath: true,
    ),
  ],
);

const _omar = PersonProfile(
  id: 2,
  name: 'عمر بيطار',
  platform: 'facebook',
  messageCount: 340,
  messageTotal: 0,
  photoCount: 0,
  firstAt: null,
  lastAt: null,
  days: 0,
  conversationId: null,
  years: [],
  lines: [],
  photos: [],
);

PersonSnapshot _snapshotFor(int? personId) => PersonSnapshot(
  people: _people,
  selected: personId == 2 ? _omar : _leila,
);

const _emptyPeople = PersonSnapshot(people: [], selected: null);

Future<void> _pumpPerson(
  WidgetTester tester, {
  PersonSnapshot Function(int? personId)? snapshot,
  ValueChanged<int>? onOpenConversation,
  VoidCallback? onOpenPhotos,
  ValueChanged<String>? onOpenSection,
  AppStrings strings = const AppStringsAr(),
  TextDirection direction = TextDirection.rtl,
}) async {
  tester.view.physicalSize = const Size(1600, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appStringsProvider.overrideWithValue(strings),
        personSnapshotProvider.overrideWith((ref) async {
          final selected = ref.watch(personSelectionProvider);
          return (snapshot ?? _snapshotFor)(selected);
        }),
      ],
      child: MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: PersonScreen(
              onOpenConversation: onOpenConversation,
              onOpenPhotos: onOpenPhotos,
              onOpenSection: onOpenSection,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// A local archive with one person, 25 dated text messages and one photo.
///
/// The fixture goes through the same tables the importer writes, so the screen
/// reads real SQL instead of a hand-made snapshot: counts, ordering and the
/// page boundary are exercised end to end.
class _ArchiveFixture {
  _ArchiveFixture(this.database, this.personId);

  final AppDatabase database;
  final int personId;
}

Future<_ArchiveFixture> _openArchive() async {
  final database = AppDatabase(NativeDatabase.memory());
  final importId = await database
      .into(database.imports)
      .insert(
        ImportsCompanion.insert(
          platform: 'facebook',
          format: 'json',
          sourceFingerprint: 'fixture-person',
          startedAt: DateTime.utc(2026, 1, 1),
          importerVersion: 'test',
          status: ImportStatus.completed,
        ),
      );
  final sourceFileId = await database
      .into(database.sourceFiles)
      .insert(
        SourceFilesCompanion.insert(
          importId: importId,
          relativePath: 'messages/inbox/leila/message_1.json',
          parseStatus: ParseStatus.parsed,
        ),
      );
  final personId = await database
      .into(database.people)
      .insert(
        PeopleCompanion.insert(
          platform: 'facebook',
          platformPersonId: const Value('fb-leila'),
          displayName: 'ليلى خالد',
        ),
      );
  for (var index = 1; index <= 25; index++) {
    await database
        .into(database.events)
        .insert(
          EventsCompanion.insert(
            importId: importId,
            sourceFileId: sourceFileId,
            sourceLocator: 'locator-$index',
            platform: 'facebook',
            eventType: 'message',
            timestampNormalized: Value(
              DateTime.utc(2019, 1, 1).add(Duration(days: index)),
            ),
            timezoneStatus: TimezoneStatus.utc,
            actorId: Value(personId),
            textContent: Value('رسالة $index'),
          ),
        );
  }
  final newest = await (database.select(
    database.events,
  )..where((event) => event.sourceLocator.equals('locator-25'))).getSingle();
  await database
      .into(database.attachments)
      .insert(
        AttachmentsCompanion.insert(
          eventId: Value(newest.id),
          sourceFileId: sourceFileId,
          mediaType: 'image',
          sizeBytes: 1024,
          relativePath: const Value('messages/inbox/leila/photos/1.jpg'),
        ),
      );
  return _ArchiveFixture(database, personId);
}

Future<void> _pumpLivePerson(
  WidgetTester tester,
  AppDatabase database, {
  AppStrings strings = const AppStringsAr(),
  TextDirection direction = TextDirection.rtl,
}) async {
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appStringsProvider.overrideWithValue(strings),
        personRepositoryProvider.overrideWith(
          (ref) async => PersonRepository(database),
        ),
        overviewRepositoryProvider.overrideWith(
          (ref) async => OverviewRepository(database),
        ),
        attachmentRepositoryProvider.overrideWith(
          (ref) async => AttachmentRepository(database),
        ),
      ],
      child: MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Scaffold(body: PersonScreen()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  testWidgets('the profile shows the name, identity, range, numbers and lines', (
    tester,
  ) async {
    await _pumpPerson(tester);

    expect(
      tester.widget<Text>(find.byKey(const Key('person-name'))).data,
      'ليلى خالد',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('person-range'))).data,
      'حكيتوا 1,284 رسالة · من 2013 لـ2024 · فيسبوك',
    );
    // The platform id is the identity's second line, straight from the export.
    expect(
      tester.widget<Text>(find.byKey(const Key('person-platform-id'))).data,
      'معرّف المنصة fb-1001',
    );
    // Cover and avatar are both drawn; the avatar is the initial letter.
    expect(find.byKey(const Key('person-cover')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('person-hero')),
        matching: find.text('ل'),
      ),
      findsOneWidget,
    );

    for (final key in [
      'person-stat-messages',
      'person-stat-photos',
      'person-stat-first',
      'person-stat-last',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(
      find.descendant(
        of: find.byKey(const Key('person-stat-first')),
        matching: find.text('12 آذار 2013'),
      ),
      findsOneWidget,
    );

    // The three reference columns are all drawn: shortcuts, profile, side
    // cards.
    for (final key in [
      'person-shortcuts',
      'person-nearby',
      'person-archive-info',
      'person-memory',
      'person-ownership',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(
      find.descendant(
        of: find.byKey(const Key('person-nearby')),
        matching: find.text('ليلى خالد'),
      ),
      findsOneWidget,
    );
    // The memory card quotes the oldest stored line, not an invented one.
    expect(
      find.descendant(
        of: find.byKey(const Key('person-memory')),
        matching: find.text('«ذكرى السنة»'),
      ),
      findsOneWidget,
    );

    expect(find.byKey(const ValueKey('person-line-101')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('person-recent')),
        matching: find.text('«ذكرى السنة»'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('person-photo-501')), findsOneWidget);
    expect(find.byKey(const ValueKey('person-year-2020')), findsOneWidget);
    expect(find.text('المجموع: 368 رسالة أرسلها'), findsOneWidget);
    expect(find.text('ذروة التواصل: 2021'), findsOneWidget);
  });

  testWidgets('the live archive fills the header, the numbers and the page', (
    tester,
  ) async {
    final fixture = await _openArchive();
    addTearDown(fixture.database.close);

    await _pumpLivePerson(tester, fixture.database);

    // Header: exported name first, then the exported platform id.
    expect(
      tester.widget<Text>(find.byKey(const Key('person-name'))).data,
      'ليلى خالد',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('person-platform-id'))).data,
      'معرّف المنصة fb-leila',
    );

    // Counts: messages, attachments (the image row) and first/last seen.
    expect(
      find.descendant(
        of: find.byKey(const Key('person-stat-messages')),
        matching: find.text('25'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('person-stat-photos')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('person-stat-first')),
        matching: find.text('2 كانون الثاني 2019'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('person-stat-last')),
        matching: find.text('26 كانون الثاني 2019'),
      ),
      findsOneWidget,
    );

    // Message list: newest first, one bounded page of 20 rows. The memory
    // card may quote the oldest loaded line too, so the list is scoped.
    Finder inList(String text) => find.descendant(
      of: find.byKey(const Key('person-recent')),
      matching: find.text(text),
    );
    expect(inList('«رسالة 25»'), findsOneWidget);
    expect(inList('«رسالة 6»'), findsOneWidget);
    expect(inList('«رسالة 5»'), findsNothing);
    expect(find.text('تم تحميل 20 من 25'), findsOneWidget);
    final newest = tester.getTopLeft(inList('«رسالة 25»')).dy;
    final oldestLoaded = tester.getTopLeft(inList('«رسالة 6»')).dy;
    expect(newest, lessThan(oldestLoaded));

    // Loading the next page appends the rest and turns the control off.
    await tester.tap(find.byKey(const Key('person-load-older')));
    await tester.pumpAndSettle();

    expect(inList('«رسالة 1»'), findsOneWidget);
    expect(find.text('تم تحميل 25 من 25'), findsOneWidget);
    expect(find.byKey(const Key('person-load-older')), findsNothing);
  });

  testWidgets('an empty archive shows one honest card', (tester) async {
    final fixture = await _openArchive();
    addTearDown(fixture.database.close);
    await (fixture.database.delete(fixture.database.events)).go();
    await (fixture.database.delete(fixture.database.people)).go();

    await _pumpLivePerson(tester, fixture.database);

    expect(find.byKey(const Key('person-empty')), findsOneWidget);
    expect(find.text('ما في أشخاص بعد'), findsOneWidget);
    expect(find.byKey(const Key('person-hero')), findsNothing);
  });

  testWidgets('English renders the same screen left-to-right', (tester) async {
    final fixture = await _openArchive();
    addTearDown(fixture.database.close);

    await _pumpLivePerson(
      tester,
      fixture.database,
      strings: const AppStringsEn(),
      direction: TextDirection.ltr,
    );

    expect(
      Directionality.of(tester.element(find.byKey(const Key('person-screen')))),
      TextDirection.ltr,
    );
    // Copy is translated; the exported name and id are not.
    expect(find.text('Last things they said'), findsOneWidget);
    expect(find.text('Loaded 20 of 25'), findsOneWidget);
    expect(find.text('Platform ID fb-leila'), findsOneWidget);
    expect(find.text('Show photos · 1'), findsOneWidget);
    expect(find.text('ليلى خالد'), findsWidgets);
  });

  testWidgets('the reference three-column order follows RTL at wide width', (
    tester,
  ) async {
    await _pumpPerson(tester);

    double x(String key) => tester.getTopLeft(find.byKey(Key(key))).dx;
    // RTL: shortcuts at the right edge, profile in the middle, archive cards
    // at the left. The assertion is order, not pixels.
    expect(x('person-shortcuts'), greaterThan(x('person-hero')));
    expect(x('person-hero'), greaterThan(x('person-nearby')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the side list opens another person', (tester) async {
    await _pumpPerson(tester);

    await tester.tap(find.byKey(const ValueKey('person-people-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.widget<Text>(find.byKey(const Key('person-name'))).data,
      'عمر بيطار',
    );
    expect(find.text('ما في رسائل نصية محفوظة.'), findsOneWidget);
    expect(find.text('ما في صور مشتركة بالأرشيف.'), findsOneWidget);
    expect(find.text('ما في رسائل مؤرخة أرسلها هذا الشخص.'), findsOneWidget);
    // No conversation to open, so the hero action is disabled.
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('person-hero-chat')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('the hero buttons reach the host callbacks', (tester) async {
    final opened = <int>[];
    var photos = 0;

    await _pumpPerson(
      tester,
      onOpenConversation: opened.add,
      onOpenPhotos: () => photos++,
    );

    await tester.tap(find.byKey(const Key('person-hero-chat')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('person-hero-photos')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('person-all-photos')));
    await tester.pump();

    expect(opened, [7]);
    expect(photos, 2);
  });

  testWidgets('the shortcuts column navigates through the host', (
    tester,
  ) async {
    final sections = <String>[];
    await _pumpPerson(tester, onOpenSection: sections.add);

    await tester.tap(find.byKey(const ValueKey('person-shortcut-messages')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('person-shortcut-media')));
    await tester.pump();

    expect(sections, ['messages', 'media']);
    // «الأشخاص» is the active row of the reference.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('person-shortcut-people')),
        matching: find.text('الأشخاص'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an empty fixture shows the empty state, not a hero', (
    tester,
  ) async {
    await _pumpPerson(tester, snapshot: (_) => _emptyPeople);

    expect(find.byKey(const Key('person-empty')), findsOneWidget);
    expect(find.text('ما في أشخاص بعد'), findsOneWidget);
    expect(find.byKey(const Key('person-hero')), findsNothing);
  });

  testWidgets('Arabic renders right-to-left with 44px list rows', (
    tester,
  ) async {
    await _pumpPerson(tester);

    expect(
      Directionality.of(tester.element(find.byKey(const Key('person-screen')))),
      TextDirection.rtl,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('person-people-1'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byKey(const Key('person-hero-chat'))).height,
      greaterThanOrEqualTo(44),
    );
  });
}
