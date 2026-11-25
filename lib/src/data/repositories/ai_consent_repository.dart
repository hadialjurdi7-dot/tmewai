import 'package:drift/drift.dart';

import '../../domain/models/ai_consent.dart';
import '../database/app_database.dart';

/// Reads and writes the AI consent log.
///
/// Only consent metadata crosses this layer: provider, policy version, scope
/// summary, timestamp and sizes. Excerpt text is never passed here.
class AiConsentRepository {
  const AiConsentRepository(this._database);

  final AppDatabase _database;

  Future<int> insert(AiConsentRecord record) {
    return _database
        .into(_database.aiConsents)
        .insert(
          AiConsentsCompanion.insert(
            providerId: record.providerId,
            policyVersion: record.policyVersion,
            scopeSummary: record.scopeSummary,
            grantedAt: record.grantedAt.toUtc(),
            eventCount: record.eventCount,
            byteCount: record.byteCount,
          ),
        );
  }

  /// Every stored consent, newest first.
  Future<List<AiConsentRecord>> findAll() async {
    final rows = await (_database.select(
      _database.aiConsents,
    )..orderBy([(table) => OrderingTerm.desc(table.grantedAt)])).get();
    return [
      for (final row in rows)
        AiConsentRecord(
          id: row.id,
          providerId: row.providerId,
          policyVersion: row.policyVersion,
          scopeSummary: row.scopeSummary,
          grantedAt: row.grantedAt.toUtc(),
          eventCount: row.eventCount,
          byteCount: row.byteCount,
        ),
    ];
  }
}
