import '../../core/errors/import_report.dart';

/// A model provider the app could ask, described without any network client.
///
/// This interface only carries what a consent screen needs. Implementing it
/// does not grant access to anything and this layer never sends data.
abstract interface class AiProvider {
  /// Stable local identifier, e.g. `example_llm`.
  String get id;

  /// Name shown to the user.
  String get displayName;

  /// Where the provider documents its data retention.
  Uri get retentionPolicyUrl;

  /// A short, honest hint such as `paid per token`; never a promise.
  String get estimatedCostHint;

  /// Version of the retention policy the user is consenting to.
  String get policyVersion;
}

/// Exactly what would be sent to a provider, described before anything moves.
///
/// It carries selected event ids, the bounded excerpts, their relative source
/// locators and byte count, the model and the provider. Nothing here is sent
/// from this layer: this object is the consent payload.
class AiConsentRequest {
  const AiConsentRequest({
    required this.providerId,
    required this.providerDisplayName,
    required this.model,
    required this.policyVersion,
    required this.eventIds,
    required this.sourceLocators,
    required this.excerpts,
    required this.byteCount,
    required this.scopeSummary,
  });

  final String providerId;
  final String providerDisplayName;
  final String model;
  final String policyVersion;

  /// The events whose text is in [excerpts], in the same order.
  final List<int> eventIds;

  /// Archive-relative locators of [eventIds], in the same order. A locator
  /// that is absolute, escaping or overlong is never included.
  final List<String> sourceLocators;

  /// The exact bounded text that would be sent.
  final List<String> excerpts;

  /// UTF-8 bytes of [excerpts], computed locally.
  final int byteCount;

  /// Content-free summary suitable for storage: counts and model only, never
  /// an excerpt.
  final String scopeSummary;

  int get charCount =>
      excerpts.fold(0, (total, excerpt) => total + excerpt.length);
}

/// The user's explicit grant for one provider and policy version.
///
/// Created only after the user approves an [AiConsentRequest]; it holds no
/// excerpt text.
class AiConsentGrant {
  const AiConsentGrant({
    required this.providerId,
    required this.policyVersion,
    required this.scopeSummary,
  });

  final String providerId;
  final String policyVersion;
  final String scopeSummary;
}

/// Raised when dispatching is attempted without a matching explicit consent.
///
/// Its message is fixed and carries no request content.
class ConsentRequired implements CodedException {
  const ConsentRequired();

  @override
  String get code => 'consent_required';

  @override
  String toString() =>
      'ConsentRequired(consent_required): explicit consent is required.';
}
