/// One-shot repair of text a previous import stored in a broken encoding.
///
/// `normalizeImportText` repairs every value a **new** import writes, but an
/// archive that was already imported keeps its mojibake rows: the messages are
/// in the database, they just read as `Ø£Ù‡Ù„Ø§Ù‹`. This migration rewrites the
/// columns a reader actually looks at, then lets the FTS triggers (which fire on
/// `UPDATE`) carry the repaired text into the search index.
///
/// It is idempotent: `repairExportedText` returns null for text that is already
/// correct, so a second run touches no rows.
library;

import 'package:drift/drift.dart';

import '../../services/importing/import_text_repair.dart';

/// The columns worth rewriting: message text and the two display names.
const List<(String, String)> _repairTargets = [
  ('events', 'text_content'),
  ('people', 'display_name'),
  ('conversations', 'title'),
];

/// Rewrites every repairable value in place. Returns the rows changed per table.
Future<Map<String, int>> repairExportedTextInPlace(GeneratedDatabase database) async {
  final changed = <String, int>{};
  for (final (table, column) in _repairTargets) {
    final rows = await database
        .customSelect('SELECT id AS id, $column AS value FROM $table')
        .get();
    var count = 0;
    for (final row in rows) {
      if (row.data['value'] is! String) continue;
      final original = row.read<String>('value');
      final repaired = repairExportedText(original);
      if (repaired == null || repaired == original) continue;
      await database.customUpdate(
        'UPDATE $table SET $column = ? WHERE id = ?',
        variables: [Variable<String>(repaired), Variable<int>(row.read<int>('id'))],
      );
      count++;
    }
    if (count > 0) changed[table] = count;
  }
  return changed;
}
