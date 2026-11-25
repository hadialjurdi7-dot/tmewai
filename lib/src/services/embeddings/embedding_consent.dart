import 'package:drift/drift.dart' show Variable;

import '../../data/database/app_database.dart';
import '../../data/repositories/ai_consent_repository.dart';
import '../../domain/models/ai_consent.dart';

/// Provider id recorded for the local embedding model.
///
/// It is distinct from any remote provider id, so a future dispatch check can
/// never confuse "approved local inference" with "approved upload".
const String embeddingProviderId = 'local-embedding-minilm-multilingual';

/// Policy version of the consent text that is shown with the download action.
/// It is bumped whenever what the user agrees to changes.
const String embeddingPolicyVersion = 'local-embedding-v1';

/// Raised when indexing is attempted without a stored consent row.
///
/// Indexing refuses instead of embedding: the archive's text may only be read
/// into vectors after the user explicitly approved this local model.
class EmbeddingConsentRequired implements Exception {
  const EmbeddingConsentRequired();

  @override
  String toString() =>
      'EmbeddingConsentRequired($embeddingProviderId/$embeddingPolicyVersion)';
}

/// Reads and records the consent for local embedding, in the existing
/// `ai_consents` table.
///
/// The row is metadata only: provider, policy version, a content-free scope
/// summary, the time and the archive counts at that moment. No message text is
/// stored here, and the summary states that nothing leaves the device.
class EmbeddingConsent {
  const EmbeddingConsent(this._database);

  final AppDatabase _database;

  /// The scope sentence shown next to the download action and stored with the
  /// approval: the model is local and inference sends nothing.
  static const String scopeSummary =
      'Local semantic search: the int8 ONNX model minilm-multilingual-l12-q '
      'is downloaded to this device and every embedding is computed here. '
      'Nothing is sent to any server.';

  /// True when an approval for this provider and policy version exists.
  Future<bool> isGranted() async {
    final rows = await _database
        .customSelect(
          '''
SELECT 1 AS granted
FROM ai_consents
WHERE provider_id = ? AND policy_version = ?
LIMIT 1
''',
          variables: [
            Variable<String>(embeddingProviderId),
            Variable<String>(embeddingPolicyVersion),
          ],
        )
        .get();
    return rows.isNotEmpty;
  }

  /// Number of events the indexer would embed right now: the set shown in the
  /// consent row and in the status line.
  Future<int> countEmbeddableEvents() async {
    final row = await _database.customSelect('''
SELECT COUNT(*) AS n
FROM events
WHERE text_content IS NOT NULL AND length(trim(text_content)) > 0
''').getSingle();
    return row.read<int>('n');
  }

  /// Records one explicit approval.
  ///
  /// [eventCount] is the number of messages the model would read; [byteCount]
  /// is always zero for local inference, because zero bytes leave the device.
  Future<AiConsentRecord> grant({
    required DateTime grantedAt,
    required int eventCount,
    int byteCount = 0,
  }) async {
    final record = AiConsentRecord(
      providerId: embeddingProviderId,
      policyVersion: embeddingPolicyVersion,
      scopeSummary: scopeSummary,
      grantedAt: grantedAt.toUtc(),
      eventCount: eventCount < 0 ? 0 : eventCount,
      byteCount: byteCount < 0 ? 0 : byteCount,
    );
    final id = await AiConsentRepository(_database).insert(record);
    return AiConsentRecord(
      id: id,
      providerId: record.providerId,
      policyVersion: record.policyVersion,
      scopeSummary: record.scopeSummary,
      grantedAt: record.grantedAt,
      eventCount: record.eventCount,
      byteCount: record.byteCount,
    );
  }

  /// Grants only when no matching row exists.
  ///
  /// Used by the explicit "build the index" action: tapping it approves local
  /// embedding, but an approval the user already gave is not duplicated in the
  /// consent log.
  Future<void> ensureGranted({required DateTime grantedAt}) async {
    if (await isGranted()) return;
    await grant(
      grantedAt: grantedAt,
      eventCount: await countEmbeddableEvents(),
    );
  }
}
