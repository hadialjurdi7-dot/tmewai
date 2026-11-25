import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import 'settings_controller.dart';

/// Confirmation word the user must type before the workspace is deleted.
const String settingsDeleteWord = 'DELETE';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final deletion = ref.watch(settingsControllerProvider);

    if (deletion.deleted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_forever_outlined, size: 40),
              const SizedBox(height: 12),
              Text(
                strings.settingsDeleted,
                key: const Key('settings-deleted-state'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                strings.settingsDeletedBody,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF667085)),
              ),
            ],
          ),
        ),
      );
    }

    final info = ref.watch(settingsInfoProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(36, 30, 36, 48),
      children: [
        Text(
          strings.settingsTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          strings.settingsSubtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF536273)),
        ),
        const SizedBox(height: 20),
        _LanguageCard(strings: strings),
        const SizedBox(height: 12),
        info.when(
          loading: () => Text(strings.settingsLoading),
          error: (_, _) => Text(strings.settingsFailed),
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.settingsWorkspacePath,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      // An absolute path is read left to right even in Arabic.
                      Text(
                        value.path,
                        key: const Key('settings-workspace-path'),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${strings.settingsWorkspaceSize}: '
                        '${_formatBytes(value.sizeBytes)}',
                        key: const Key('settings-workspace-size'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.settingsRemove,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.settingsRemoveBody,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.settingsRemoveHint,
                        key: const Key('settings-delete-hint'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF98A2B3),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('settings-delete-button'),
                        style: OutlinedButton.styleFrom(
                          // Comfortable pointer target for a destructive action.
                          minimumSize: const Size(44, 44),
                        ),
                        onPressed: deletion.busy
                            ? null
                            : () => _confirmAndDelete(context, ref, strings),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(strings.settingsRemoveButton),
                      ),
                      if (deletion.failed) ...[
                        const SizedBox(height: 8),
                        Text(
                          strings.settingsFailed,
                          style: const TextStyle(color: Color(0xFFB42318)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.settingsConsents,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if (value.consents.isEmpty)
                        Text(
                          strings.settingsConsentsEmpty,
                          key: const Key('settings-consents-empty'),
                        )
                      else
                        for (final consent in value.consents)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${consent.providerId} · '
                              '${consent.policyVersion} · '
                              '${_formatDate(consent.grantedAt)}',
                              key: Key('settings-consent-${consent.id}'),
                              // Provider ids, versions and UTC stamps stay LTR.
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _DeleteDialog(strings: strings),
    );
    if (confirmed != true) return;
    await ref.read(settingsControllerProvider.notifier).deleteWorkspace();
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String _formatDate(DateTime value) {
    final utc = value.toUtc();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${utc.year}-${two(utc.month)}-${two(utc.day)} '
        '${two(utc.hour)}:${two(utc.minute)} UTC';
  }
}

/// Language switch: the choice applies to the whole app and is stored with
/// the local workspace.
class _LanguageCard extends ConsumerWidget {
  const _LanguageCard({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appLocaleModeProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.settingsLanguage,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              strings.settingsLanguageHint,
              style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SegmentedButton<AppLocaleMode>(
                key: const Key('settings-language-toggle'),
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(64, 44)),
                ),
                segments: [
                  ButtonSegment(
                    value: AppLocaleMode.system,
                    label: Text(strings.settingsLanguageSystem),
                  ),
                  ButtonSegment(
                    value: AppLocaleMode.en,
                    label: Text(strings.settingsLanguageEnglish),
                  ),
                  ButtonSegment(
                    value: AppLocaleMode.ar,
                    label: Text(strings.settingsLanguageArabic),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (selection) => ref
                    .read(appLocaleModeProvider.notifier)
                    .select(selection.first),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.strings});

  final AppStrings strings;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _controller = TextEditingController();
  bool _matches = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.strings.settingsConfirmTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.strings.settingsConfirmBody),
          const SizedBox(height: 12),
          TextField(
            key: const Key('settings-delete-confirm-field'),
            controller: _controller,
            decoration: InputDecoration(
              labelText: widget.strings.settingsConfirmLabel,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => setState(
              () => _matches = value.trim() == settingsDeleteWord,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(widget.strings.settingsCancel),
        ),
        FilledButton(
          key: const Key('settings-delete-confirm-button'),
          onPressed: _matches ? () => Navigator.of(context).pop(true) : null,
          child: Text(widget.strings.settingsRemoveButton),
        ),
      ],
    );
  }
}
