import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/core/l10n/app_strings.dart';
import 'package:personal_data_agent/src/features/import/import_run_status.dart';
import 'package:personal_data_agent/src/services/importing/import_coordinator.dart';
import 'package:personal_data_agent/src/services/importing/import_text_normalizer.dart';

void main() {
  ImportOutcome outcomeWith(List<String> warnings) => ImportOutcome(
    importId: 1,
    reusedExistingImport: false,
    sourceFiles: 1,
    events: 4,
    people: 2,
    conversations: 1,
    attachments: 0,
    skippedRecords: warnings.length,
    warnings: warnings,
  );

  Future<void> pumpSummary(
    WidgetTester tester, {
    required ImportOutcome outcome,
    required AppStrings strings,
    TextDirection direction = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: ImportOutcomeSummary(outcome: outcome, strings: strings),
          ),
        ),
      ),
    );
  }

  testWidgets('renders each skip warning with file, field and bound', (
    tester,
  ) async {
    final outcome = outcomeWith([
      importRecordSkippedWarningFor(
        relativePath: 'messages/inbox/thread/message_1.json',
        column: ImportTextColumns.eventTextContent,
        bound: ImportTextBound.maximum,
      ),
      importRecordSkippedWarningFor(
        relativePath: 'messages/inbox/thread/message_1.json',
        column: ImportTextColumns.personDisplayName,
        bound: ImportTextBound.minimum,
      ),
    ]);

    await pumpSummary(tester, outcome: outcome, strings: const AppStringsEn());

    expect(find.textContaining('Skipped record details'), findsOneWidget);
    expect(
      find.textContaining('messages/inbox/thread/message_1.json'),
      findsOneWidget,
    );
    expect(
      find.textContaining('events.text_content'),
      findsOneWidget,
    );
    expect(find.textContaining('maximum allowed'), findsOneWidget);
    expect(
      find.textContaining('people.display_name'),
      findsOneWidget,
    );
    expect(find.textContaining('minimum required'), findsOneWidget);
  });

  testWidgets('renders the warning details in Arabic', (tester) async {
    final outcome = outcomeWith([
      importRecordSkippedWarningFor(
        relativePath: 'messages/inbox/thread/message_1.json',
        column: ImportTextColumns.eventTextContent,
        bound: ImportTextBound.maximum,
      ),
    ]);

    await pumpSummary(
      tester,
      outcome: outcome,
      strings: const AppStringsAr(),
      direction: TextDirection.rtl,
    );

    expect(find.textContaining('تفاصيل السجلات المتجاوزة'), findsOneWidget);
    expect(find.textContaining('الملف:'), findsOneWidget);
    expect(find.textContaining('الحقل:'), findsOneWidget);
    expect(find.textContaining('الحد الأعلى المسموح'), findsOneWidget);
    expect(
      find.textContaining('messages/inbox/thread/message_1.json'),
      findsOneWidget,
    );
  });

  testWidgets('caps the list and reports how many details were omitted', (
    tester,
  ) async {
    final outcome = outcomeWith([
      for (var i = 0; i < 8; i++)
        importRecordSkippedWarningFor(
          relativePath: 'messages/inbox/thread_$i/message_1.json',
          column: ImportTextColumns.eventTextContent,
          bound: ImportTextBound.maximum,
        ),
    ]);

    await pumpSummary(tester, outcome: outcome, strings: const AppStringsEn());

    expect(find.textContaining('thread_0'), findsOneWidget);
    expect(find.textContaining('thread_4'), findsOneWidget);
    expect(find.textContaining('thread_5'), findsNothing);
    expect(find.textContaining('and 3 more'), findsOneWidget);
  });

  testWidgets('falls back to a generic line for an unknown warning code', (
    tester,
  ) async {
    final outcome = outcomeWith(['a_future_warning_code']);

    await pumpSummary(tester, outcome: outcome, strings: const AppStringsEn());

    expect(
      find.textContaining(
        'A record was skipped; no further details are available.',
      ),
      findsOneWidget,
    );
  });
}
