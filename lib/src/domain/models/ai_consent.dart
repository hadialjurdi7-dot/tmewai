/// A stored record of one explicit AI consent.
///
/// It holds what the user approved, not the content that was approved: no
/// excerpt text is ever stored here.
class AiConsentRecord {
  const AiConsentRecord({
    required this.providerId,
    required this.policyVersion,
    required this.scopeSummary,
    required this.grantedAt,
    required this.eventCount,
    required this.byteCount,
    this.id,
  });

  /// Assigned by the database; null before the row is inserted.
  final int? id;

  final String providerId;
  final String policyVersion;

  /// A short, content-free summary of what was approved (counts and model).
  final String scopeSummary;

  final DateTime grantedAt;
  final int eventCount;
  final int byteCount;
}
