/// A person as the source platform exported them.
///
/// People are identified per platform: [platformPersonId] is the platform's own
/// identifier when the export provides one. Display names are never used on
/// their own to merge two people.
class PersonRecord {
  const PersonRecord({
    required this.platform,
    required this.displayName,
    this.id,
    this.platformPersonId,
  });

  /// Assigned by the database; null before the row is inserted.
  final int? id;

  final String platform;

  /// Platform-scoped identifier, when the export exposes one.
  final String? platformPersonId;

  /// The name exactly as exported.
  final String displayName;
}
