import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/features/media/media_controller.dart';
import 'package:personal_data_agent/src/features/media/media_screen.dart';
import 'package:personal_data_agent/src/features/media/media_service.dart';

MediaItem _item(
  int id,
  DateTime at, {
  String type = 'image',
  bool hasPath = true,
}) => MediaItem(
  id: id,
  mediaType: type,
  sizeBytes: 1024,
  at: at,
  hasPath: hasPath,
);

const _years = [
  (year: 2023, count: 900),
  (year: 2021, count: 1200),
  (year: 2019, count: 1104),
];

const _people = [
  MediaPerson(id: 1, name: 'ليلى خالد', count: 512),
  MediaPerson(id: 2, name: 'عمر بيطار', count: 340),
  MediaPerson(id: 3, name: 'خالي أم سامر', count: 285),
  MediaPerson(id: 4, name: 'سامر العبدالله', count: 190),
  MediaPerson(id: 5, name: 'أبو كريم (المحل)', count: 142),
];

MediaSnapshot _snapshotFor(int? year) {
  final all = [
    _item(1, DateTime.utc(2023, 5, 1)),
    _item(2, DateTime.utc(2021, 8, 24)),
    _item(3, DateTime.utc(2019, 3, 12), type: 'video'),
    _item(4, DateTime.utc(2019, 3, 12), hasPath: false),
  ];
  final items = year == null
      ? all
      : [
          for (final item in all)
            if (item.at!.year == year) item,
        ];
  return MediaSnapshot(
    total: 3204,
    years: _years,
    selectedYear: year,
    items: items,
    people: _people,
    matched: year == null ? 3204 : items.length,
    limit: 60,
  );
}

const _emptyMedia = MediaSnapshot(
  total: 0,
  years: [],
  selectedYear: null,
  items: [],
  people: [],
  matched: 0,
  limit: 60,
);

Future<List<String>> _pumpMedia(
  WidgetTester tester, {
  MediaSnapshot Function(int? year)? snapshot,
}) async {
  tester.view.physicalSize = const Size(1600, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final opened = <String>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaSnapshotProvider.overrideWith((ref) async {
          final year = ref.watch(mediaYearProvider);
          return (snapshot ?? _snapshotFor)(year);
        }),
      ],
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MediaScreen(
              onOpenSection: opened.add,
              importPageBuilder: (_) =>
                  const Text('import-route', key: ValueKey('media-import-route')),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return opened;
}

void main() {
  testWidgets('the header counts the archive and the grid is four across', (
    tester,
  ) async {
    await _pumpMedia(tester);

    expect(find.text('الصور والفيديو'), findsOneWidget);
    expect(find.text('3,204 صورة'), findsOneWidget);
    expect(find.text('كل السنوات'), findsOneWidget);
    for (final year in [2023, 2021, 2019]) {
      expect(find.byKey(Key('media-year-$year')), findsOneWidget);
    }
    expect(find.byKey(const Key('media-year-all')), findsOneWidget);

    final grid = tester.widget<GridView>(find.byKey(const Key('media-grid')));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 4);

    expect(find.byKey(const ValueKey('media-item-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('media-item-4')), findsOneWidget);
    // The year appears in the filter chip and on the tile badge.
    expect(find.text('2023'), findsNWidgets(2));
    expect(find.text('بلا مسار في الأرشيف'), findsOneWidget);

    // The first tile of the grid is the selected one, as in the reference.
    expect(find.byKey(const ValueKey('media-selected-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('media-selected-2')), findsNothing);

    expect(find.byKey(const Key('media-people')), findsOneWidget);
    expect(find.text('512 صورة'), findsOneWidget);
    expect(find.text('142 صورة'), findsOneWidget);
    expect(find.text('عرض الكل'), findsOneWidget);
    expect(find.byKey(const Key('media-privacy-note')), findsOneWidget);
    expect(find.textContaining('الذاكرة المحلية'), findsOneWidget);
    expect(find.textContaining('ما انرفعت لأي مكان'), findsOneWidget);
  });

  testWidgets('the shortcuts column marks photos and counts them', (
    tester,
  ) async {
    final opened = await _pumpMedia(tester);

    expect(find.byKey(const Key('media-shortcuts')), findsOneWidget);
    for (final label in [
      'ملفي',
      'الرئيسية',
      'قصتك بالأرقام',
      'التحليلات',
      'الرسائل',
      'الصور',
      'الأشخاص',
      'الإعدادات',
    ]) {
      expect(find.byKey(ValueKey('media-shortcut-$label')), findsOneWidget);
    }
    // The photo row carries the real archive count.
    expect(find.text('3,204'), findsOneWidget);
    expect(find.byKey(const Key('media-archive-note')), findsOneWidget);
    expect(find.text('أرشيفك مالكك بالكامل'), findsOneWidget);

    await tester.tap(find.byKey(const Key('media-people-all')));
    await tester.pump();
    expect(opened, ['people']);

    await tester.tap(find.byKey(const Key('media-import')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('media-import-route')), findsOneWidget);
  });

  testWidgets('a year chip filters the grid and the counter', (tester) async {
    await _pumpMedia(tester);

    await tester.tap(find.byKey(const Key('media-year-2021')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('1,200 صورة'), findsOneWidget);
    expect(find.byKey(const ValueKey('media-item-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('media-item-1')), findsNothing);
    // The selection falls back to the first tile of the filtered year.
    expect(find.byKey(const ValueKey('media-selected-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('media-year-all')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('3,204 صورة'), findsOneWidget);
    expect(find.byKey(const ValueKey('media-item-1')), findsOneWidget);
  });

  testWidgets('tapping a tile moves the blue check', (tester) async {
    await _pumpMedia(tester);

    await tester.tap(find.byKey(const ValueKey('media-item-3')));
    await tester.pump();

    expect(find.byKey(const ValueKey('media-selected-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('media-selected-1')), findsNothing);
  });

  testWidgets('the memories banner opens the oldest year', (tester) async {
    await _pumpMedia(tester);

    expect(find.byKey(const Key('media-memories')), findsOneWidget);
    expect(
      find.text('هالصور من 2019 - ما حدا شافها من زمان'),
      findsOneWidget,
    );
    expect(find.text('افتح ذكريات 2019'), findsOneWidget);

    await tester.tap(find.byKey(const Key('media-memories-open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('media-item-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('media-item-1')), findsNothing);
    // The button cannot re-open the year that is already open.
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('media-memories-open')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('a year without photos says so instead of drawing an empty grid', (
    tester,
  ) async {
    await _pumpMedia(
      tester,
      snapshot: (year) => year == 2021
          ? const MediaSnapshot(
              total: 3204,
              years: [
                (year: 2023, count: 900),
                (year: 2021, count: 1200),
                (year: 2019, count: 1104),
              ],
              selectedYear: 2021,
              items: [],
              people: [],
              matched: 0,
              limit: 60,
            )
          : _snapshotFor(year),
    );

    await tester.tap(find.byKey(const Key('media-year-2021')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('media-grid-empty')), findsOneWidget);
    expect(find.text('ما في صور بهذه السنة'), findsOneWidget);
    expect(find.byKey(const Key('media-grid')), findsNothing);
  });

  testWidgets('an empty archive shows one honest card', (tester) async {
    await _pumpMedia(tester, snapshot: (_) => _emptyMedia);

    expect(find.byKey(const Key('media-empty')), findsOneWidget);
    expect(find.text('ما في صور بعد'), findsOneWidget);
    expect(find.byKey(const Key('media-grid-card')), findsNothing);
  });

  testWidgets('Arabic renders right-to-left with 44px targets', (
    tester,
  ) async {
    await _pumpMedia(tester);

    expect(
      Directionality.of(tester.element(find.byKey(const Key('media-screen')))),
      TextDirection.rtl,
    );
    for (final key in const [
      Key('media-year-all'),
      Key('media-memories-open'),
      Key('media-people-all'),
      Key('media-people'),
    ]) {
      expect(
        tester.getSize(find.byKey(key)).height,
        greaterThanOrEqualTo(44),
        reason: '$key must keep a 44px target',
      );
    }
    expect(
      tester
          .getSize(find.byKey(const ValueKey('media-person-1')))
          .height,
      greaterThanOrEqualTo(44),
    );
  });
}
