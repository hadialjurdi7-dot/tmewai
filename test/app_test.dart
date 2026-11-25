import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/app/app.dart';
import 'package:personal_data_agent/src/data/repositories/overview_repository.dart';
import 'package:personal_data_agent/src/features/home/home_controller.dart';
import 'package:personal_data_agent/src/features/home/home_service.dart';

const _emptySnapshot = HomeSnapshot(
  totals: ArchiveTotals(messages: 0, photos: 0, people: 0, days: 0, events: 0),
  topPeople: [],
  latest: [],
);

Widget _app() => ProviderScope(
  overrides: [
    // The test environment has no platform storage; the home section is
    // exercised with an empty archive so the import path stays testable.
    homeSnapshotProvider.overrideWith((ref) async => _emptySnapshot),
  ],
  child: const PersonalDataAgentApp(),
);

void main() {
  testWidgets(
    'home opens the local-first archive inspection and import screen',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // The home section matches the owner's greeting, local archive state,
      // and three top-level destinations before opening the import page.
      expect(find.text('مساء الخير'), findsOneWidget);
      expect(find.text('أرشيف محلي مفتوح'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Memories'), findsOneWidget);
      expect(find.text('People'), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-import')));
      await tester.pumpAndSettle();

      expect(find.text('Local — no data sent'), findsOneWidget);
      expect(find.text('Tmewai'), findsOneWidget);
      expect(find.text('Tell me exactly who I am'), findsOneWidget);
      // The folder is the primary source; a ZIP is the fallback.
      expect(find.text('Choose folder'), findsOneWidget);
      expect(find.text('Or open a ZIP archive'), findsOneWidget);
      expect(find.text('Advanced search'), findsOneWidget);
      expect(
        find.text(
          'Tmewai reads the selected folder or ZIP on this device and stores supported records in the local archive.',
        ),
        findsOneWidget,
      );
      final back = tester.widget<IconButton>(
        find.byKey(const ValueKey('import-page-back')),
      );
      expect(back.onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('import-page-back')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('home-screen')), findsOneWidget);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
    },
  );
}
