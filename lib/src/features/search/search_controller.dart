import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/workspace_provider.dart';
import '../../data/repositories/event_search_repository.dart';
import '../../services/embeddings/embedding_consent.dart';
import '../../services/embeddings/embedding_indexer.dart';
import '../../services/embeddings/embedding_model.dart';
import '../../services/embeddings/model_installer.dart';
import '../../services/embeddings/onnx_model_factory.dart';
import 'search_service.dart';

/// The deterministic double, kept for tests and for the debug switch.
///
/// It exists only in debug builds and only when explicitly requested, so a
/// normal run never fills the database with vectors that carry no meaning.
/// `flutter run --dart-define=TMEWAI_FAKE_EMBEDDINGS=true` exercises the whole
/// pipeline without the 135 MB model and without ONNX.
const bool fakeSemanticEmbeddingsEnabled =
    kDebugMode && bool.fromEnvironment('TMEWAI_FAKE_EMBEDDINGS');

/// Where the model is installed, or null when this platform has no installer.
///
/// Null is a normal state (the browser build): the screen shows no semantic
/// controls at all instead of offering an action that cannot work. A failing
/// path provider is caught for the same reason — search must still work.
final semanticModelInstallerProvider =
    FutureProvider<SemanticModelInstaller?>((ref) async {
      try {
        final installer = await createDefaultModelInstaller();
        return installer.isSupported ? installer : null;
      } on Object {
        return null;
      }
    });

/// The two model files, only when both are present at their verified size and
/// recorded hashes. Null means "no semantic model" and nothing else.
final semanticModelFilesProvider = FutureProvider<ModelFiles?>((ref) async {
  final installer = await ref.watch(semanticModelInstallerProvider.future);
  if (installer == null) return null;
  try {
    return await installer.verifiedFiles();
  } on Object {
    // A damaged model directory is not an error screen: the model is simply not
    // available and search stays lexical until the user installs it again.
    return null;
  }
});

/// The approval record consulted by the indexer.
final semanticConsentProvider = FutureProvider<EmbeddingConsent>((ref) async {
  final workspace = await ref.watch(workspaceProvider.future);
  return EmbeddingConsent(workspace.database);
});

/// The real local model, built only from verified files.
///
/// Building it is cheap: the ONNX session and the tokenizer are loaded on the
/// first embed, so a search screen rebuild does not pay for either.
final onnxEmbeddingModelProvider = FutureProvider<EmbeddingModel?>((
  ref,
) async {
  final files = await ref.watch(semanticModelFilesProvider.future);
  if (files == null) return null;
  final model = createOnnxEmbeddingModel(files);
  if (model == null) return null;
  ref.onDispose(() => unawaited(model.close()));
  return model;
});

/// The model available to this build. Tests override this provider directly;
/// otherwise the debug double wins when requested, and the downloaded ONNX
/// model is used only when both files verify.
final semanticEmbeddingModelProvider = Provider<EmbeddingModel?>((ref) {
  if (fakeSemanticEmbeddingsEnabled) return const HashMapEmbedder();
  return ref.watch(onnxEmbeddingModelProvider).asData?.value;
});

/// Search data source. The default opens the local workspace database; tests
/// override this with an in-memory database.
final searchRepositoryProvider = FutureProvider<EventSearchRepository>((
  ref,
) async {
  final workspace = await ref.watch(workspaceProvider.future);
  return EventSearchRepository(workspace.database);
});

/// Search read model used by this screen: page rows, provenance and the total.
/// It shares the workspace database but not the repository provider, because
/// other screens use that provider and do not need these joined reads.
final searchServiceProvider = FutureProvider<SearchService>((ref) async {
  final workspace = await ref.watch(workspaceProvider.future);
  return SearchService(
    workspace.database,
    embeddingModel: ref.watch(semanticEmbeddingModelProvider),
  );
});

/// Builds vectors only when a local model is available. Null means the phase-1
/// fake was not enabled, so the screen shows no semantic controls at all.
final semanticIndexerProvider = FutureProvider<EmbeddingIndexer?>((ref) async {
  final model = ref.watch(semanticEmbeddingModelProvider);
  if (model == null) return null;
  final workspace = await ref.watch(workspaceProvider.future);
  final indexer = EmbeddingIndexer(workspace.database, model);
  ref.onDispose(indexer.dispose);
  return indexer;
});

/// Coverage of the current model's index, for the one-line search status.
final semanticIndexStatusProvider = FutureProvider<EmbeddingIndexStatus>((
  ref,
) async {
  final indexer = await ref.watch(semanticIndexerProvider.future);
  if (indexer == null) return const EmbeddingIndexStatus.unavailable();
  return indexer.status();
});

/// Live rows done / planned for the run in flight, or null when idle.
///
/// The status line consumes it so a long first index shows real progress
/// instead of an indefinite spinner.
class SemanticIndexProgressController extends Notifier<EmbeddingIndexProgress?> {
  @override
  EmbeddingIndexProgress? build() => null;

  void report(EmbeddingIndexProgress? progress) => state = progress;
}

final semanticIndexProgressProvider =
    NotifierProvider<SemanticIndexProgressController, EmbeddingIndexProgress?>(
      SemanticIndexProgressController.new,
    );

/// The one-line semantic state the search screen renders.
///
/// Three honest states are possible and each is derived from local facts only:
/// the model is missing, the model is ready but has no vectors yet, or the
/// index covers [indexed] of [total] messages.
class SemanticSearchStatus {
  const SemanticSearchStatus({
    required this.supported,
    required this.modelInstalled,
    required this.consentGranted,
    required this.indexed,
    required this.total,
    this.progress,
  });

  /// False on platforms without a model installer; the screen shows nothing.
  final bool supported;

  final bool modelInstalled;
  final bool consentGranted;
  final int indexed;
  final int total;

  /// Set while a run is in flight.
  final EmbeddingIndexProgress? progress;

  bool get hasText => total > 0;

  bool get canIndex => modelInstalled && total > 0 && indexed < total;

  bool get isPartial => indexed > 0 && indexed < total;

  bool get isComplete => total > 0 && indexed >= total;
}

final semanticSearchStatusProvider = FutureProvider<SemanticSearchStatus>((
  ref,
) async {
  final installer = await ref.watch(semanticModelInstallerProvider.future);
  if (installer == null) {
    return const SemanticSearchStatus(
      supported: false,
      modelInstalled: false,
      consentGranted: false,
      indexed: 0,
      total: 0,
    );
  }
  final files = await ref.watch(semanticModelFilesProvider.future);
  final consent = await ref.watch(semanticConsentProvider.future);
  final status = await ref.watch(semanticIndexStatusProvider.future);
  return SemanticSearchStatus(
    supported: true,
    modelInstalled: files != null,
    consentGranted: await consent.isGranted(),
    indexed: status.indexed,
    total: status.total,
    progress: ref.watch(semanticIndexProgressProvider),
  );
});

/// Progress and last failure of the explicit model download.
class SemanticSetupState {
  const SemanticSetupState({
    this.downloading = false,
    this.received = 0,
    this.total = 0,
    this.failed = false,
  });

  final bool downloading;
  final int received;
  final int total;
  final bool failed;

  /// 0..1 for the file currently being fetched, or null when the server did
  /// not declare a length.
  double? get fraction => total > 0 ? received / total : null;
}

/// Downloads and verifies the model after one explicit tap.
///
/// The tap is the consent: the `ai_consents` row is written before the first
/// byte is fetched, so no download and no embedding can ever happen without a
/// stored approval. A failure leaves the app on lexical search and reports a
/// plain flag; there is no retry loop and no background polling.
class SemanticSetupController extends Notifier<SemanticSetupState> {
  @override
  SemanticSetupState build() => const SemanticSetupState();

  Future<void> downloadModel() async {
    if (state.downloading) return;
    state = const SemanticSetupState(downloading: true);
    try {
      final workspace = await ref.read(workspaceProvider.future);
      final installer = await ref.read(semanticModelInstallerProvider.future);
      if (installer == null) {
        state = const SemanticSetupState(failed: true);
        return;
      }
      await EmbeddingConsent(
        workspace.database,
      ).ensureGranted(grantedAt: DateTime.now());
      final result = await installer.install(
        onProgress: (file, received, total) {
          state = SemanticSetupState(
            downloading: true,
            received: received,
            total: total,
          );
        },
      );
      state = result.installed
          ? const SemanticSetupState()
          : const SemanticSetupState(failed: true);
      if (result.installed) {
        ref.invalidate(semanticModelFilesProvider);
        ref.invalidate(semanticIndexStatusProvider);
        ref.invalidate(semanticSearchStatusProvider);
      }
    } on Object {
      state = const SemanticSetupState(failed: true);
    }
  }
}

final semanticSetupProvider =
    NotifierProvider<SemanticSetupController, SemanticSetupState>(
      SemanticSetupController.new,
    );

/// Whether the shell is showing the search screen instead of the overview.
class _SearchOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final searchOpenProvider = NotifierProvider<_SearchOpenNotifier, bool>(
  _SearchOpenNotifier.new,
);

/// Event types the filter offers, in display order.
const List<String> searchEventTypes = [
  'message',
  'comment',
  'reaction',
  'post',
];

/// Everything the search screen shows.
class SearchState {
  const SearchState({
    this.query = '',
    this.from,
    this.to,
    this.eventType,
    this.results = const [],
    this.totalHits = 0,
    this.loading = false,
    this.failed = false,
    this.hasSearched = false,
    this.mode = SearchMode.lexical,
    this.indexingSemantic = false,
  });

  final String query;
  final DateTime? from;
  final DateTime? to;
  final String? eventType;
  final List<SearchResultRow> results;

  /// Every match, including rows beyond the loaded page.
  final int totalHits;
  final bool loading;

  /// True when the last search threw; the message is a fixed string, never the
  /// exception text.
  final bool failed;

  final bool hasSearched;

  /// Which retriever produced [results]; the UI labels hybrid pages.
  final SearchMode mode;

  /// True while the explicit indexing action is running.
  final bool indexingSemantic;

  bool get hasFilters => from != null || to != null || eventType != null;

  SearchState copyWith({
    String? query,
    DateTime? from,
    DateTime? to,
    String? eventType,
    List<SearchResultRow>? results,
    int? totalHits,
    bool? loading,
    bool? failed,
    bool? hasSearched,
    SearchMode? mode,
    bool? indexingSemantic,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearEventType = false,
  }) => SearchState(
    query: query ?? this.query,
    from: clearFrom ? null : (from ?? this.from),
    to: clearTo ? null : (to ?? this.to),
    eventType: clearEventType ? null : (eventType ?? this.eventType),
    results: results ?? this.results,
    totalHits: totalHits ?? this.totalHits,
    loading: loading ?? this.loading,
    failed: failed ?? this.failed,
    hasSearched: hasSearched ?? this.hasSearched,
    mode: mode ?? this.mode,
    indexingSemantic: indexingSemantic ?? this.indexingSemantic,
  );
}

/// Runs searches through [EventSearchRepository] and exposes loading, results
/// and a safe failure flag. Contains no SQL: the repository owns the query.
class SearchController extends Notifier<SearchState> {
  int _generation = 0;

  @override
  SearchState build() => const SearchState();

  void setQuery(String query) {
    state = state.copyWith(query: query);
    run();
  }

  void setFrom(DateTime? from) {
    state = from == null
        ? state.copyWith(clearFrom: true)
        : state.copyWith(from: from);
    run();
  }

  void setTo(DateTime? to) {
    state = to == null ? state.copyWith(clearTo: true) : state.copyWith(to: to);
    run();
  }

  void setEventType(String? eventType) {
    state = eventType == null
        ? state.copyWith(clearEventType: true)
        : state.copyWith(eventType: eventType);
    run();
  }

  void clearFilters() {
    state = state.copyWith(
      clearFrom: true,
      clearTo: true,
      clearEventType: true,
    );
    run();
  }

  Future<void> run() async {
    final generation = ++_generation;
    final request = state;
    state = state.copyWith(loading: true, failed: false);
    try {
      final service = await ref.read(searchServiceProvider.future);
      final outcome = await service.search(
        request.query,
        from: request.from,
        to: request.to?.add(const Duration(days: 1)),
        eventType: request.eventType,
      );
      if (generation != _generation) return;
      state = state.copyWith(
        loading: false,
        results: outcome.rows,
        totalHits: outcome.totalHits,
        hasSearched: true,
        mode: outcome.mode,
      );
    } on Object {
      if (generation != _generation) return;
      // No exception text, no file content: a fixed failure state.
      state = state.copyWith(
        loading: false,
        failed: true,
        results: const [],
        totalHits: 0,
        hasSearched: true,
      );
    }
  }

  /// Runs the explicit indexing action, then refreshes the page so a newly
  /// partial index is used immediately.
  ///
  /// The tap also records the local-embedding consent when no approval exists
  /// yet: the user asked for this index in so many words, and the row is
  /// written before the indexer reads any text. A failure leaves the lexical
  /// page untouched — the semantic layer is an optional improvement, never a
  /// prerequisite for searching.
  Future<void> indexSemantic() async {
    if (state.indexingSemantic) return;
    state = state.copyWith(indexingSemantic: true);
    final progress = ref.read(semanticIndexProgressProvider.notifier);
    try {
      final indexer = await ref.read(semanticIndexerProvider.future);
      if (indexer == null) return;
      await indexer.consent.ensureGranted(grantedAt: DateTime.now());
      final subscription = indexer.progress.listen(progress.report);
      try {
        await indexer.indexPending();
      } finally {
        await subscription.cancel();
      }
      ref.invalidate(semanticIndexStatusProvider);
      ref.invalidate(semanticSearchStatusProvider);
      await run();
    } on Object {
      // Keep the existing results; no exception text reaches the screen.
    } finally {
      progress.report(null);
      state = state.copyWith(indexingSemantic: false);
    }
  }
}

final searchControllerProvider =
    NotifierProvider<SearchController, SearchState>(SearchController.new);
