import 'package:drift/drift.dart'
    show DriftSqlType, GeneratedColumn, VerificationMeta, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/data/database/app_database.dart';
import 'package:personal_data_agent/src/services/importing/import_text_normalizer.dart';

/// Guards the class of bug that made a real 816 MB export save nothing: drift
/// enforces a text column's minimum as well as its maximum, and the writer used
/// to clip only the maximum.
///
/// The first test walks the generated schema, so adding or widening a bounded
/// text column without teaching the normalizer about it fails here. The rest
/// are table-driven over the same registry.
void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('schema guard', () {
    late AppDatabase database;

    setUp(() async {
      database = AppDatabase(NativeDatabase.memory());
      await database.customSelect('SELECT 1').get();
    });

    tearDown(() => database.close());

    test('every bounded text column has one coherent spec', () {
      final covered = <String>{};
      for (final table in database.allTables) {
        for (final column in table.$columns) {
          if (column.type != DriftSqlType.string) continue;
          final text = column as GeneratedColumn<String>;
          if (text.additionalChecks == null) continue;

          final field = '${table.actualTableName}.${column.$name}';
          final spec = ImportTextColumns.byField(
            table.actualTableName,
            column.$name,
          );
          expect(
            spec,
            isNotNull,
            reason:
                '$field declares a text bound; add it to ImportTextColumns '
                'and route its writer through normalizeImportText',
          );

          const meta = VerificationMeta('guard');
          final min = _minAccepted(text, meta);
          final max = _maxAccepted(text, meta, min);
          expect(spec!.min, min, reason: '$field minimum drifted from schema');
          expect(spec.max, max, reason: '$field maximum drifted from schema');
          expect(
            spec.nullable,
            column.$nullable,
            reason: '$field nullability drifted from schema',
          );
          expect(
            covered.add(spec.field),
            isTrue,
            reason: '${spec.field} is registered twice',
          );
        }
      }

      for (final spec in ImportTextColumns.all) {
        expect(
          covered,
          contains(spec.field),
          reason: '${spec.field} is registered but has no bounded column',
        );
      }
      expect(covered, isNotEmpty);
    });
  });

  group('normalizeImportText', () {
    for (final spec in ImportTextColumns.all) {
      test('${spec.field} enforces both bounds', () {
        final empty = normalizeImportText('', spec);
        if (spec.nullable) {
          expect(empty.rejection, isNull, reason: spec.field);
          expect(empty.value, isNull, reason: spec.field);
        } else {
          expect(empty.rejection?.bound, ImportTextBound.minimum);
          expect(empty.value, isNull);
        }

        final blank = normalizeImportText('   ', spec);
        expect(
          blank.rejection?.bound,
          spec.nullable ? null : ImportTextBound.minimum,
        );

        final atMax = normalizeImportText('a' * spec.max, spec);
        expect(atMax.rejection, isNull, reason: spec.field);
        expect(atMax.value!.length, spec.max);

        final tooLong = normalizeImportText('a' * (spec.max + 1), spec);
        if (spec.clipOversized) {
          expect(tooLong.rejection, isNull, reason: spec.field);
          expect(tooLong.value!.length, spec.max, reason: spec.field);
        } else {
          expect(tooLong.rejection?.bound, ImportTextBound.maximum);
          expect(tooLong.value, isNull);
        }
      });

      test('${spec.field} warning names the path, field and bound only', () {
        final secret = 'SECRET-${'z' * (spec.max + 1)}';
        final result = normalizeImportText(secret, spec);
        // Clipped columns have no rejection; their value is bounded instead.
        if (result.rejection == null) {
          expect(result.value!.length, lessThanOrEqualTo(spec.max));
          return;
        }

        final warning = result.rejection!.warningFor(
          'messages/inbox/leila/message_1.json',
        );
        expect(warning, startsWith(importRecordSkippedCode));
        expect(warning, contains('file=messages/inbox/leila/message_1.json'));
        expect(warning, contains('field=${spec.field}'));
        expect(warning, contains('bound=maximum'));
        expect(warning, isNot(contains('SECRET')));
        expect(warning, isNot(contains('zzz')));
      });
    }

    test('a clipped value is accepted by the real drift column', () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      for (final table in database.allTables) {
        for (final column in table.$columns) {
          if (column.type != DriftSqlType.string) continue;
          final text = column as GeneratedColumn<String>;
          if (text.additionalChecks == null) continue;
          final spec = ImportTextColumns.byField(
            table.actualTableName,
            column.$name,
          )!;
          const meta = VerificationMeta('guard');

          final oversized = normalizeImportText('q' * (spec.max + 1), spec);
          if (oversized.rejection == null) {
            expect(
              text.isAcceptableValue(oversized.value, meta).success,
              isTrue,
              reason: '${spec.field} clipped to a value drift still rejects',
            );
          }

          final optional = normalizeImportText('', spec);
          if (optional.rejection == null) {
            expect(
              text.isAcceptableValue(optional.value, meta).success,
              isTrue,
              reason: '${spec.field} normalized an empty value drift rejects',
            );
          }
        }
      }
    });

    test('required empty values are rejected, optional ones become null', () {
      final required = normalizeImportText(
        '',
        ImportTextColumns.personDisplayName,
      );
      expect(required.rejection?.bound, ImportTextBound.minimum);
      expect(required.rejection?.column.field, 'people.display_name');

      final optional = normalizeImportText(
        '  ',
        ImportTextColumns.conversationTitle,
      );
      expect(optional.rejection, isNull);
      expect(optional.value, isNull);
    });

    test('identity names stay verbatim, titles trim, evidence does not', () {
      // display_name is the lookup key on re-import: trimming it would merge
      // two exported spellings and miss a person already stored verbatim.
      expect(
        normalizeImportText(
          '  Ada  ',
          ImportTextColumns.personDisplayName,
        ).value,
        '  Ada  ',
      );
      expect(
        normalizeImportText(
          '  Thread  ',
          ImportTextColumns.conversationTitle,
        ).value,
        'Thread',
      );
      expect(
        normalizeImportText(
          '  quoted  ',
          ImportTextColumns.eventTextContent,
        ).value,
        '  quoted  ',
      );
    });

    test('a whitespace-only name is rejected without the trim flag', () {
      final result = normalizeImportText(
        '   ',
        ImportTextColumns.personDisplayName,
      );
      expect(result.rejection?.bound, ImportTextBound.minimum);
      expect(result.value, isNull);
    });

    test('an over-long locator or body is rejected, not truncated', () {
      for (final spec in [
        ImportTextColumns.eventSourceLocator,
        ImportTextColumns.eventTextContent,
      ]) {
        final value = 'x' * (spec.max + 1);
        final result = normalizeImportText(value, spec);
        expect(result.rejection?.bound, ImportTextBound.maximum);
        expect(result.value, isNull);
      }
    });
  });
}

/// The shortest accepted non-null string, found through the real drift check.
int _minAccepted(GeneratedColumn<String> column, VerificationMeta meta) {
  for (var length = 0; length <= 16; length++) {
    if (column.isAcceptableValue('a' * length, meta).success) return length;
  }
  throw StateError('${column.$name} accepts no string up to 16 characters');
}

/// The longest accepted string, found by binary search through the real check.
int _maxAccepted(
  GeneratedColumn<String> column,
  VerificationMeta meta,
  int min,
) {
  var low = min;
  var high = 1 << 20;
  if (column.isAcceptableValue('a' * high, meta).success) {
    throw StateError('${column.$name} accepts a 1 MiB string');
  }
  while (low < high) {
    final mid = (low + high + 1) >> 1;
    if (column.isAcceptableValue('a' * mid, meta).success) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return low;
}
