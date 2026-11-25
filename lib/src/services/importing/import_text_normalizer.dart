/// The text bounds of the columns an import writes, and the one normalizer
/// every write path uses.
///
/// `tables.dart` declares each text column with `withLength(min: …, max: …)`,
/// which drift compiles into a check that rejects **either** bound. The
/// importer used to clip only the ceiling, so one blank exported name made the
/// whole insert throw and the surrounding transaction rolled a real archive
/// back. Every archive value now passes through [normalizeImportText] against
/// its column here before it reaches drift.
///
/// The registry is deliberately declarative: `import_text_normalizer_test.dart`
/// walks the generated schema, compares every bounded text column with its
/// entry, and fails when a column is added without a spec.
library;

import 'import_text_repair.dart';

/// Which declared bound a value violated.
enum ImportTextBound {
  /// The value was empty (or shorter than the declared minimum).
  minimum,

  /// The value was longer than the declared maximum.
  maximum,
}

/// One text column as declared in `tables.dart`.
///
/// [nullable] mirrors the column's `NOT NULL` constraint. [clipOversized]
/// decides whether an over-long value is clipped to [max] or rejected: labels,
/// paths and metadata are clipped, while evidence text and unique source
/// locators are rejected so a stored quotation is never a half-quotation.
/// [trim] is for display labels, where surrounding whitespace is not part of
/// the value. Identity keys - such as `people.display_name`, which is matched
/// verbatim on re-import - must keep `trim: false` so two exported spellings
/// never collapse into one person.
class ImportTextColumn {
  const ImportTextColumn({
    required this.table,
    required this.column,
    required this.min,
    required this.max,
    required this.nullable,
    this.clipOversized = true,
    this.trim = false,
  });

  /// Database table name, e.g. `people`.
  final String table;

  /// Database column name, e.g. `display_name`.
  final String column;

  final int min;
  final int max;
  final bool nullable;
  final bool clipOversized;
  final bool trim;

  /// Stable, content-free field name used in a warning.
  String get field => '$table.$column';
}

/// The normalized value, or why it could not be stored.
///
/// A rejection carries the field and the violated bound, never the value, so
/// it can be reported without leaking archive content.
sealed class NormalizedImportText {
  const NormalizedImportText();

  /// The value to store, or null for an empty optional column.
  String? get value;

  /// The rejection, or null when [value] may be stored.
  ImportTextRejected? get rejection;
}

/// A value that fits its column.
final class ImportTextValue extends NormalizedImportText {
  const ImportTextValue(this.value);

  @override
  final String? value;

  @override
  ImportTextRejected? get rejection => null;
}

/// A value that cannot be stored.
final class ImportTextRejected extends NormalizedImportText {
  const ImportTextRejected(this.column, this.bound);

  final ImportTextColumn column;
  final ImportTextBound bound;

  @override
  String? get value => null;

  @override
  ImportTextRejected get rejection => this;

  /// A content-free warning naming the file, the field and the bound.
  ///
  /// The value itself is never included, consistent with the import error
  /// catalog and the redacted logging rules.
  String warningFor(String relativePath) => importRecordSkippedWarningFor(
    relativePath: relativePath,
    column: column,
    bound: bound,
  );
}

/// Prefix of a warning for one skipped record.
const String importRecordSkippedCode = 'import_record_skipped';

/// Builds the warning for a skipped record.
///
/// [bound] is null when the skip came from a database constraint rather than a
/// declared text bound; the warning then says `bound=write`. [field] overrides
/// the column name when SQLite itself named the failing column, while [column]
/// supplies the fallback.
String importRecordSkippedWarningFor({
  required String relativePath,
  required ImportTextColumn column,
  ImportTextBound? bound,
  String? field,
}) =>
    '$importRecordSkippedCode file=$relativePath '
    'field=${field ?? column.field} bound=${bound?.name ?? 'write'}';

/// Normalizes [raw] against [column].
///
/// - empty or whitespace-only, optional → `null`;
/// - empty or whitespace-only, required → [ImportTextBound.minimum] rejection;
/// - shorter than [ImportTextColumn.min] → minimum rejection;
/// - longer than [ImportTextColumn.max] → clipped or maximum rejection;
/// - otherwise unchanged (after an optional trim).
NormalizedImportText normalizeImportText(String? raw, ImportTextColumn column) {
  var value = raw;
  // An export can hand back text in a broken encoding (see
  // `import_text_repair.dart`); repairing here covers every write path at once,
  // and the repair returns null for text that is already correct.
  if (value != null) value = repairExportedText(value) ?? value;
  if (value != null && column.trim) value = value.trim();

  if (value == null || value.trim().isEmpty) {
    if (column.nullable) return const ImportTextValue(null);
    return ImportTextRejected(column, ImportTextBound.minimum);
  }
  if (value.length < column.min) {
    return ImportTextRejected(column, ImportTextBound.minimum);
  }
  if (value.length > column.max) {
    if (!column.clipOversized) {
      return ImportTextRejected(column, ImportTextBound.maximum);
    }
    value = value.substring(0, column.max);
  }
  return ImportTextValue(value);
}

/// Every bounded text column of the schema an import can reach.
///
/// Values mirror `tables.dart`; the table-driven test compares them with the
/// generated drift columns so a schema edit cannot silently escape the guard.
abstract final class ImportTextColumns {
  // imports
  static const importsPlatform = ImportTextColumn(
    table: 'imports',
    column: 'platform',
    min: 1,
    max: 64,
    nullable: false,
  );
  static const importsFormat = ImportTextColumn(
    table: 'imports',
    column: 'format',
    min: 1,
    max: 64,
    nullable: false,
  );
  static const importsSourceFingerprint = ImportTextColumn(
    table: 'imports',
    column: 'source_fingerprint',
    min: 1,
    max: 128,
    nullable: false,
  );
  static const importsImporterVersion = ImportTextColumn(
    table: 'imports',
    column: 'importer_version',
    min: 1,
    max: 64,
    nullable: false,
  );
  static const importsCoverageJson = ImportTextColumn(
    table: 'imports',
    column: 'coverage_json',
    min: 2,
    max: 4096,
    nullable: true,
    clipOversized: false,
  );

  // source_files
  static const sourceFilePath = ImportTextColumn(
    table: 'source_files',
    column: 'relative_path',
    min: 1,
    max: 1024,
    nullable: false,
  );
  static const sourceFileMediaType = ImportTextColumn(
    table: 'source_files',
    column: 'media_type',
    min: 1,
    max: 128,
    nullable: true,
  );
  static const sourceFileContentHash = ImportTextColumn(
    table: 'source_files',
    column: 'content_hash',
    min: 1,
    max: 128,
    nullable: true,
  );
  static const sourceFileErrorCode = ImportTextColumn(
    table: 'source_files',
    column: 'error_code',
    min: 1,
    max: 64,
    nullable: true,
  );

  // people
  static const personPlatform = ImportTextColumn(
    table: 'people',
    column: 'platform',
    min: 1,
    max: 64,
    nullable: false,
  );
  static const personPlatformId = ImportTextColumn(
    table: 'people',
    column: 'platform_person_id',
    min: 1,
    max: 128,
    nullable: true,
  );
  /// An identity key: `_writePeople` looks an existing person up by this
  /// stored value, so it is kept verbatim. Blank values are still rejected by
  /// [normalizeImportText]'s independent whitespace check.
  static const personDisplayName = ImportTextColumn(
    table: 'people',
    column: 'display_name',
    min: 1,
    max: 512,
    nullable: false,
  );

  // conversations
  static const conversationSourceId = ImportTextColumn(
    table: 'conversations',
    column: 'source_conversation_id',
    min: 1,
    max: 128,
    nullable: true,
  );
  static const conversationTitle = ImportTextColumn(
    table: 'conversations',
    column: 'title',
    min: 1,
    max: 512,
    nullable: true,
    trim: true,
  );

  // events
  static const eventSourceLocator = ImportTextColumn(
    table: 'events',
    column: 'source_locator',
    min: 1,
    max: 2048,
    nullable: false,
    clipOversized: false,
  );
  static const eventPlatform = ImportTextColumn(
    table: 'events',
    column: 'platform',
    min: 1,
    max: 64,
    nullable: false,
  );
  static const eventType = ImportTextColumn(
    table: 'events',
    column: 'event_type',
    min: 1,
    max: 64,
    nullable: false,
  );
  static const eventTimestampRaw = ImportTextColumn(
    table: 'events',
    column: 'timestamp_raw',
    min: 1,
    max: 64,
    nullable: true,
  );
  static const eventTextContent = ImportTextColumn(
    table: 'events',
    column: 'text_content',
    min: 0,
    max: 100000,
    nullable: true,
    clipOversized: false,
  );
  static const eventMetadataJson = ImportTextColumn(
    table: 'events',
    column: 'metadata_json',
    min: 0,
    max: 8192,
    nullable: true,
  );

  // ai_consents
  static const consentProviderId = ImportTextColumn(
    table: 'ai_consents',
    column: 'provider_id',
    min: 1,
    max: 64,
    nullable: false,
  );
  static const consentPolicyVersion = ImportTextColumn(
    table: 'ai_consents',
    column: 'policy_version',
    min: 1,
    max: 64,
    nullable: false,
  );
  static const consentScopeSummary = ImportTextColumn(
    table: 'ai_consents',
    column: 'scope_summary',
    min: 1,
    max: 1024,
    nullable: false,
  );

  // attachments
  static const attachmentPath = ImportTextColumn(
    table: 'attachments',
    column: 'relative_path',
    min: 1,
    max: 1024,
    nullable: true,
  );
  static const attachmentMediaType = ImportTextColumn(
    table: 'attachments',
    column: 'media_type',
    min: 1,
    max: 128,
    nullable: false,
  );
  static const attachmentContentHash = ImportTextColumn(
    table: 'attachments',
    column: 'content_hash',
    min: 1,
    max: 128,
    nullable: true,
  );

  /// Every bounded text column, in schema order.
  static const List<ImportTextColumn> all = [
    importsPlatform,
    importsFormat,
    importsSourceFingerprint,
    importsImporterVersion,
    importsCoverageJson,
    sourceFilePath,
    sourceFileMediaType,
    sourceFileContentHash,
    sourceFileErrorCode,
    personPlatform,
    personPlatformId,
    personDisplayName,
    conversationSourceId,
    conversationTitle,
    eventSourceLocator,
    eventPlatform,
    eventType,
    eventTimestampRaw,
    eventTextContent,
    eventMetadataJson,
    consentProviderId,
    consentPolicyVersion,
    consentScopeSummary,
    attachmentPath,
    attachmentMediaType,
    attachmentContentHash,
  ];

  /// The spec for a database table and column, when one exists.
  static ImportTextColumn? byField(String table, String column) {
    for (final spec in all) {
      if (spec.table == table && spec.column == column) return spec;
    }
    return null;
  }
}
