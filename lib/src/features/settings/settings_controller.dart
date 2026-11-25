import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/workspace_provider.dart';
import '../../data/repositories/ai_consent_repository.dart';
import '../../domain/models/ai_consent.dart';
import '../messages/messages_controller.dart';

/// Everything the settings screen shows about the local workspace.
class SettingsInfo {
  const SettingsInfo({
    required this.path,
    required this.sizeBytes,
    required this.consents,
  });

  /// Absolute workspace path, shown only to the local user.
  final String path;

  /// Bytes on disk, computed without following links.
  final int sizeBytes;

  /// Consent metadata only: provider, policy version, timestamp, sizes.
  final List<AiConsentRecord> consents;
}

final settingsInfoProvider = FutureProvider<SettingsInfo>((ref) async {
  final workspace = await ref.watch(workspaceProvider.future);
  final size = await workspace.workspaceSizeBytes();
  final consents = workspace.isOpen
      ? await AiConsentRepository(workspace.database).findAll()
      : const <AiConsentRecord>[];
  return SettingsInfo(
    path: workspace.workspaceDirectory?.path ?? '',
    sizeBytes: size,
    consents: consents,
  );
});

class SettingsState {
  const SettingsState({
    this.busy = false,
    this.deleted = false,
    this.failed = false,
  });

  final bool busy;

  /// True once the workspace was deleted and its database handle closed.
  final bool deleted;

  /// True when deletion failed; the shown message is fixed.
  final bool failed;
}

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() => const SettingsState();

  /// Deletes the workspace through the existing safe service.
  ///
  /// The service closes the database first and refuses an unsafe target, so on
  /// success no database handle is left open.
  Future<bool> deleteWorkspace() async {
    if (state.busy) return false;
    state = const SettingsState(busy: true);
    try {
      final workspace = await ref.read(workspaceProvider.future);
      await workspace.deleteWorkspace();
      ref.read(messagesSelectionProvider.notifier).reset();
      ref.read(workspaceDeletedProvider.notifier).markDeleted();
      state = const SettingsState(deleted: true);
      return true;
    } on Object {
      state = const SettingsState(failed: true);
      return false;
    }
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

class _SettingsOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final settingsOpenProvider = NotifierProvider<_SettingsOpenNotifier, bool>(
  _SettingsOpenNotifier.new,
);
