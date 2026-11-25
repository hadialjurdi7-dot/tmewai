import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/workspace_provider.dart';
import '../../core/errors/import_report.dart';
import '../../features/analytics/analytics_controller.dart';
import '../../features/home/home_controller.dart';
import '../../features/media/media_controller.dart';
import '../../features/messages/messages_controller.dart';
import '../../features/overview/overview_controller.dart';
import '../../features/people/person_controller.dart';
import '../../features/search/search_controller.dart';
import '../../services/importing/import_coordinator.dart';
import '../../services/importing/import_progress.dart';
import '../../services/importing/telegram_json_importer.dart';

final importCoordinatorProvider = FutureProvider<ImportCoordinator>((
  ref,
) async {
  final workspace = await ref.watch(workspaceProvider.future);
  final coordinator = ImportCoordinator(database: workspace.database);
  ref.onDispose(() => unawaited(coordinator.dispose()));
  return coordinator;
});

/// Same writer and schema as Facebook, with `instagram` on imported rows.
final instagramImportCoordinatorProvider = FutureProvider<ImportCoordinator>((
  ref,
) async {
  final workspace = await ref.watch(workspaceProvider.future);
  final coordinator = ImportCoordinator(
    database: workspace.database,
    platform: 'instagram',
  );
  ref.onDispose(() => unawaited(coordinator.dispose()));
  return coordinator;
});

class ImportRunState {
  const ImportRunState({
    this.running = false,
    this.progress,
    this.outcome,
    this.errorCode,
    this.cancelled = false,
  });

  final bool running;
  final ImportProgress? progress;
  final ImportOutcome? outcome;
  final String? errorCode;
  final bool cancelled;

  ImportRunState copyWith({
    bool? running,
    ImportProgress? progress,
    ImportOutcome? outcome,
    String? errorCode,
    bool? cancelled,
    bool clearProgress = false,
    bool clearOutcome = false,
    bool clearError = false,
  }) => ImportRunState(
    running: running ?? this.running,
    progress: clearProgress ? null : (progress ?? this.progress),
    outcome: clearOutcome ? null : (outcome ?? this.outcome),
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
    cancelled: cancelled ?? this.cancelled,
  );
}

class ImportRunController extends Notifier<ImportRunState> {
  CancelToken? _cancelToken;

  @override
  ImportRunState build() => const ImportRunState();

  /// Imports a ZIP the browser picker handed over as bytes.
  Future<void> runBytes(Uint8List bytes, {String label = 'upload.zip'}) =>
      _run(sourcePath: '', archiveBytes: bytes, label: label);

  Future<void> run(String sourcePath) async =>
      _run(sourcePath: sourcePath, archiveBytes: null, label: sourcePath);

  /// Explicit Telegram entry points, for a picker that already knows the format.
  Future<void> runTelegramBytes(Uint8List bytes, {String label = 'result.json'}) =>
      _run(
        sourcePath: '',
        archiveBytes: bytes,
        label: label,
        forceTelegram: true,
      );

  Future<void> runTelegram(String sourcePath) => _run(
    sourcePath: sourcePath,
    archiveBytes: null,
    label: sourcePath,
    forceTelegram: true,
  );

  /// Imports a WhatsApp `.txt` chat export, or a ZIP carrying its chat logs.
  Future<void> runWhatsApp(String sourcePath) => _run(
    sourcePath: sourcePath,
    archiveBytes: null,
    label: sourcePath,
    whatsapp: true,
  );

  Future<void> runWhatsAppBytes(
    Uint8List bytes, {
    String label = 'chat.txt',
  }) => _run(
    sourcePath: '',
    archiveBytes: bytes,
    label: label,
    whatsapp: true,
  );

  /// Instagram DM export picked explicitly; skips platform detection.
  Future<void> runInstagram(String sourcePath) => _run(
    sourcePath: sourcePath,
    archiveBytes: null,
    label: sourcePath,
    forceInstagram: true,
  );

  Future<void> runInstagramBytes(
    Uint8List bytes, {
    String label = 'instagram.zip',
  }) => _run(
    sourcePath: '',
    archiveBytes: bytes,
    label: label,
    forceInstagram: true,
  );

  Future<void> _run({
    required String sourcePath,
    required Uint8List? archiveBytes,
    required String label,
    bool forceTelegram = false,
    bool whatsapp = false,
    bool forceInstagram = false,
  }) async {
    if (state.running) return;
    final token = CancelToken();
    _cancelToken = token;
    state = const ImportRunState(running: true);

    StreamSubscription<ImportProgress>? subscription;
    try {
      final coordinatorProvider =
          forceInstagram || label.toLowerCase().contains('instagram')
          ? instagramImportCoordinatorProvider
          : importCoordinatorProvider;
      final coordinator = await ref.read(coordinatorProvider.future);
      subscription = coordinator.progress.listen((progress) {
        state = state.copyWith(progress: progress);
      });
      final useTelegram =
          forceTelegram ||
          await _looksTelegram(sourcePath, archiveBytes, label);
      final result = useTelegram
          ? await coordinator.importTelegramSource(
              sourcePath,
              archiveBytes: archiveBytes,
              cancelToken: token,
            )
          : whatsapp
          ? (archiveBytes != null
                ? await coordinator.importWhatsAppTextBytes(
                    archiveBytes,
                    cancelToken: token,
                  )
                : await coordinator.importWhatsAppText(
                    sourcePath,
                    cancelToken: token,
                  ))
          : await coordinator.importSource(
              sourcePath,
              archiveBytes: archiveBytes,
              cancelToken: token,
            );
      if (result is ImportOutcome) {
        _refreshArchiveScreens();
        state = state.copyWith(
          running: false,
          progress: ImportProgress(
            phase: ImportPhase.completed,
            filesDone: result.sourceFiles,
            filesTotal: result.sourceFiles,
            recordsWritten: result.events,
          ),
          outcome: result,
        );
        // Started after the outcome is published and never awaited: embedding
        // the new rows must not delay or fail the import result.
        unawaited(_indexSemanticAfterImport());
      } else {
        state = state.copyWith(
          running: false,
          cancelled: result is ImportCancelled,
        );
      }
    } on CodedException catch (error) {
      state = state.copyWith(running: false, errorCode: error.code);
    } on Object {
      state = state.copyWith(running: false, errorCode: 'unknown_error');
    } finally {
      await subscription?.cancel();
      _cancelToken = null;
    }
  }

  /// Picks the importer without re-reading a large archive: bytes already in
  /// memory are sniffed, a JSON path reads only its first 64 KB, and a ZIP on
  /// disk stays on the Facebook path unless the caller names Telegram.
  Future<bool> _looksTelegram(
    String sourcePath,
    Uint8List? archiveBytes,
    String label,
  ) async {
    if (archiveBytes != null) {
      return TelegramJsonImporter.looksLikeTelegramSource(
        archiveBytes,
        name: label,
      );
    }
    if (sourcePath.toLowerCase().endsWith('.json') &&
        File(sourcePath).existsSync()) {
      final file = File(sourcePath);
      final length = file.lengthSync();
      final bytes = Uint8List.fromList(
        await file.openRead(0, length < 65536 ? length : 65536).first,
      );
      return TelegramJsonImporter.looksLikeTelegram(bytes);
    }
    return false;
  }

  void cancel() => _cancelToken?.cancel();

  void reset() => state = const ImportRunState();

  /// Embeds the rows this import added, when local embedding was already
  /// approved and the model is installed.
  ///
  /// This is the only place import touches semantic search, and it only runs
  /// after the archive is committed. It never grants consent itself: without a
  /// stored approval it does nothing. A missing model, a failed session or a
  /// closed workspace leaves the import result and lexical search untouched.
  Future<void> _indexSemanticAfterImport() async {
    try {
      final consent = await ref.read(semanticConsentProvider.future);
      if (!await consent.isGranted()) return;
      final indexer = await ref.read(semanticIndexerProvider.future);
      if (indexer == null) return;
      final progress = ref.read(semanticIndexProgressProvider.notifier);
      final subscription = indexer.progress.listen(progress.report);
      try {
        await indexer.indexPending();
      } finally {
        await subscription.cancel();
        progress.report(null);
      }
      ref.invalidate(semanticIndexStatusProvider);
      ref.invalidate(semanticSearchStatusProvider);
    } on Object {
      // Optional layer only; the archive is already imported.
    }
  }

  void _refreshArchiveScreens() {
    ref.read(messagesSelectionProvider.notifier).reset();
    ref.read(mediaYearProvider.notifier).select(null);
    ref.read(personSelectionProvider.notifier).reset();
    ref.read(analyticsYearProvider.notifier).select(null);
    ref.invalidate(homeSnapshotProvider);
    ref.invalidate(messagesSnapshotProvider);
    ref.invalidate(mediaSnapshotProvider);
    ref.invalidate(personSnapshotProvider);
    ref.invalidate(analyticsSnapshotProvider);
    ref.invalidate(overviewStatsProvider);
  }
}

final importRunProvider = NotifierProvider<ImportRunController, ImportRunState>(
  ImportRunController.new,
);
