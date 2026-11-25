import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;

import '../../data/database/app_database.dart';
import '../../data/repositories/ai_consent_repository.dart';
import '../../domain/models/ai_consent.dart';
import 'ai_provider.dart';

/// Builds the bounded evidence bundle for a consent screen and gates dispatch.
///
/// No AI provider is configured in this version: [dispatch] checks consent,
/// records it, and then throws [UnimplementedError] without constructing any
/// HTTP client. Nothing in this library imports a network library.
class AiGateway {
  AiGateway({
    required this.database,
    AiConsentRepository? consentRepository,
    this.maxEvents = 20,
    this.maxTotalChars = 4000,
  }) : consentRepository = consentRepository ?? AiConsentRepository(database);

  final AppDatabase database;
  final AiConsentRepository consentRepository;

  /// Upper bound on selected events in one request.
  final int maxEvents;

  /// Upper bound on the total excerpt characters in one request.
  final int maxTotalChars;

  /// Builds the exact payload a consent screen would show.
  ///
  /// Only events that exist, have text and carry an archive-relative locator
  /// are considered. Selection stops at [maxEvents] events and [maxTotalChars]
  /// characters, so the bundle is bounded before it is ever described.
  Future<AiConsentRequest> prepareRequest({
    required AiProvider provider,
    required String model,
    required Iterable<int> eventIds,
  }) async {
    if (maxEvents < 1 || maxTotalChars < 1) {
      throw ArgumentError('AI evidence limits must be positive.');
    }

    final selectedIds = eventIds.take(maxEvents).toList();
    final rows = selectedIds.isEmpty
        ? const <Event>[]
        : await (database.select(database.events)
                ..where((event) => event.id.isIn(selectedIds))
                ..orderBy([(event) => OrderingTerm.asc(event.id)]))
              .get();
    final byId = {for (final row in rows) row.id: row};

    final ids = <int>[];
    final locators = <String>[];
    final excerpts = <String>[];
    var chars = 0;
    var bytes = 0;

    // Walk the caller's order so the bundle is explainable, skipping anything
    // whose locator could reveal a host path.
    for (final id in selectedIds) {
      final row = byId[id];
      if (row == null) continue;
      final text = row.textContent;
      if (text == null || text.isEmpty) continue;
      final locator = row.sourceLocator;
      if (!_isRelativeLocator(locator)) continue;
      if (chars + text.length > maxTotalChars && excerpts.isNotEmpty) break;
      if (text.length > maxTotalChars && excerpts.isEmpty) break;
      if (ids.length >= maxEvents) break;

      ids.add(id);
      locators.add(locator);
      excerpts.add(text);
      chars += text.length;
      bytes += utf8.encode(text).length;
    }

    return AiConsentRequest(
      providerId: provider.id,
      providerDisplayName: provider.displayName,
      model: model,
      policyVersion: provider.policyVersion,
      eventIds: List.unmodifiable(ids),
      sourceLocators: List.unmodifiable(locators),
      excerpts: List.unmodifiable(excerpts),
      byteCount: bytes,
      scopeSummary:
          'events:${ids.length}; chars:$chars; bytes:$bytes; model:$model',
    );
  }

  /// Dispatches a prepared request, but only with an explicit matching grant.
  ///
  /// The grant is recorded in `ai_consents` (metadata only, no excerpts) and
  /// then the call stops: this version has no provider client, so no network
  /// request is made.
  Future<void> dispatch({
    required AiConsentRequest request,
    AiConsentGrant? consent,
  }) async {
    if (consent == null ||
        consent.providerId != request.providerId ||
        consent.policyVersion != request.policyVersion) {
      throw const ConsentRequired();
    }

    await consentRepository.insert(
      AiConsentRecord(
        providerId: request.providerId,
        policyVersion: request.policyVersion,
        // Counts and model only: the summary never contains an excerpt.
        scopeSummary: request.scopeSummary,
        grantedAt: DateTime.now().toUtc(),
        eventCount: request.eventIds.length,
        byteCount: request.byteCount,
      ),
    );

    throw UnimplementedError(
      'AI dispatch is not implemented: no provider client exists and no '
      'network request is made.',
    );
  }
}

/// Whether [locator] is an archive-relative source locator.
///
/// Absolute paths, Windows drive paths, traversal segments and overlong values
/// are refused, so a host path can never reach a consent payload.
bool _isRelativeLocator(String locator) {
  if (locator.isEmpty || locator.length > 2048) return false;
  if (locator.startsWith('/') || locator.startsWith(r'\')) return false;
  if (RegExp(r'^[A-Za-z]:').hasMatch(locator)) return false;
  if (locator.split(RegExp(r'[/\\]')).any((segment) => segment == '..')) {
    return false;
  }
  return true;
}
