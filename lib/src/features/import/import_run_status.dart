import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/errors/import_error_catalog.dart';
import '../../core/l10n/app_strings.dart';
import '../../services/importing/import_coordinator.dart';
import '../../services/importing/import_text_normalizer.dart';
import 'import_controller.dart';

/// How many per-record skip details the summary renders before it collapses
/// the rest into one "and N more" line.
const int _maxShownSkipWarnings = 5;

/// The content-free parts of an [importRecordSkippedCode] warning.
///
/// The warning is built by the importer from a path, a registered field and a
/// bound; it never carries a value from the archive. A warning that does not
/// match the shape stays unparsed and is rendered with the generic line.
class _ImportSkipWarning {
  const _ImportSkipWarning({
    required this.file,
    required this.field,
    required this.bound,
  });

  final String file;
  final String field;
  final String bound;

  static final RegExp _pattern = RegExp(
    '^${RegExp.escape(importRecordSkippedCode)} '
    r'file=(.+) field=(\S+) bound=(\S+)$',
  );

  static _ImportSkipWarning? tryParse(String warning) {
    final match = _pattern.firstMatch(warning);
    if (match == null) return null;
    return _ImportSkipWarning(
      file: match.group(1)!,
      field: match.group(2)!,
      bound: match.group(3)!,
    );
  }
}

class ImportRunProgress extends StatelessWidget {
  const ImportRunProgress({
    required this.state,
    required this.strings,
    required this.onCancel,
    super.key,
  });

  final ImportRunState state;
  final AppStrings strings;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final progress = state.progress;
    final total = progress?.filesTotal ?? 0;
    final done = progress?.filesDone ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: total > 0 ? (done / total).clamp(0.0, 1.0) : null,
        ),
        const SizedBox(height: 8),
        Text(
          strings.importProgress
              .replaceAll('{done}', '$done')
              .replaceAll('{total}', '$total'),
        ),
        Text(
          strings.importRecordsWritten.replaceAll(
            '{count}',
            '${progress?.recordsWritten ?? 0}',
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.cancel_outlined),
            label: Text(strings.importCancel),
          ),
        ),
      ],
    );
  }
}

class ImportOutcomeSummary extends StatelessWidget {
  const ImportOutcomeSummary({
    required this.outcome,
    required this.strings,
    super.key,
  });

  final ImportOutcome outcome;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) => ImportRunStatusBanner(
    message: [
      strings.importResultTitle,
      '${strings.importEvents}: ${outcome.events}',
      '${strings.importPeople}: ${outcome.people}',
      '${strings.importConversations}: ${outcome.conversations}',
      '${strings.importAttachments}: ${outcome.attachments}',
      '${strings.importSkippedRecords}: ${outcome.skippedRecords}',
      if (outcome.reusedExistingImport) strings.importReusedExisting,
    ].join(' · '),
    detail: outcome.warnings.isEmpty
        ? null
        : _SkipWarnings(warnings: outcome.warnings, strings: strings),
    color: TmColors.successTint,
    icon: Icons.check_circle_outline,
  );
}

/// Renders the skip warnings of a completed import.
///
/// Details are grouped by file and capped at [_maxShownSkipWarnings], so a
/// pathological archive cannot turn the result into an unbounded dump. Only
/// the file, field and violated bound are shown; an unparseable warning falls
/// back to one generic line instead of being echoed.
class _SkipWarnings extends StatelessWidget {
  const _SkipWarnings({required this.warnings, required this.strings});

  final List<String> warnings;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final parsed = <_ImportSkipWarning>[];
    var unparsed = 0;
    for (final warning in warnings) {
      final detail = _ImportSkipWarning.tryParse(warning);
      if (detail == null) {
        unparsed++;
      } else {
        parsed.add(detail);
      }
    }
    if (parsed.isEmpty && unparsed == 0) return const SizedBox.shrink();

    final shown = parsed.take(_maxShownSkipWarnings);
    final hidden = parsed.length - shown.length;
    final byFile = <String, List<_ImportSkipWarning>>{};
    for (final detail in shown) {
      byFile.putIfAbsent(detail.file, () => []).add(detail);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.importWarningsTitle,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          for (final group in byFile.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${strings.importWarningFile}: ${group.key}'),
            ),
            for (final detail in group.value)
              Text(
                '${strings.importWarningField}: ${detail.field} · '
                '${strings.importWarningBound}: '
                '${_boundLabel(detail.bound, strings)}',
              ),
          ],
          if (hidden > 0)
            Text(strings.importWarningMore.replaceAll('{count}', '$hidden')),
          if (unparsed > 0) Text(strings.importWarningGeneric),
        ],
      ),
    );
  }

  static String _boundLabel(String bound, AppStrings strings) =>
      switch (bound) {
        'minimum' => strings.importWarningBoundMinimum,
        'maximum' => strings.importWarningBoundMaximum,
        'write' => strings.importWarningBoundWrite,
        _ => bound,
      };
}

class ImportCancelledSummary extends StatelessWidget {
  const ImportCancelledSummary({required this.strings, super.key});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) => ImportRunStatusBanner(
    message: strings.importCancelledRolledBack,
    color: TmColors.successTint,
    icon: Icons.undo,
  );
}

class ImportRunErrorSummary extends StatelessWidget {
  const ImportRunErrorSummary({
    required this.code,
    required this.strings,
    required this.recordsWritten,
    super.key,
  });

  final String code;
  final AppStrings strings;
  final int recordsWritten;

  @override
  Widget build(BuildContext context) {
    final localizedCode = switch (code) {
      'archive_empty' => 'ArchiveEmpty',
      'archive_size_limit' => 'ArchiveSizeLimit',
      'folder_unreadable' => 'FolderUnreadable',
      'entry_count_limit' => 'EntryCountLimit',
      'entry_size_limit' => 'EntrySizeLimit',
      'json_file_size_limit' => 'JsonFileSizeLimit',
      'json_payload_size_limit' => 'JsonPayloadSizeLimit',
      'expanded_size_limit' => 'ExpandedSizeLimit',
      'invalid_entry_path' => 'InvalidEntryPath',
      'absolute_entry_path' => 'AbsoluteEntryPath',
      'path_traversal' => 'PathTraversal',
      'duplicate_entry' => 'DuplicateEntry',
      'symbolic_link_rejected' => 'SymbolicLinkRejected',
      'invalid_json_path_filter' => 'InvalidJsonPathFilter',
      'archive_corrupt' => 'ArchiveCorrupt',
      'archive_changed' => 'ArchiveChanged',
      'record_count_limit' => 'RecordCountLimit',
      'import_write_failed' => 'ImportWriteFailed',
      'no_supported_files_found' => 'NoSupportedFiles',
      'malformed_message_json' => 'MalformedMessageJson',
      'unsupported_message_json' => 'UnsupportedMessageJson',
      'malformed_comments_json' => 'MalformedCommentsJson',
      'unsupported_comments_json' => 'UnsupportedCommentsJson',
      'malformed_reactions_json' => 'MalformedReactionsJson',
      'unsupported_reactions_json' => 'UnsupportedReactionsJson',
      'malformed_posts_json' => 'MalformedPostsJson',
      'unsupported_posts_json' => 'UnsupportedPostsJson',
      _ => 'Unknown',
    };
    // A code the string table has no key for still has catalogue text, both
    // languages, so a specific write failure names itself on screen instead of
    // reading as "unknown".
    final catalogueEntry = ImportErrorCatalog.byCode(code);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final description = localizedCode == 'Unknown' && catalogueEntry != null
        ? (isRtl ? catalogueEntry.messageAr : catalogueEntry.messageEn)
        : strings.importErrorMessage(localizedCode);
    final savedMessage = recordsWritten > 0
        ? strings.importErrorRolledBack
        : strings.importErrorNothingSaved;
    return ImportRunStatusBanner(
      message: '${strings.importErrorTitle}: $description\n$savedMessage',
      color: const Color(0xFFFFF3F0),
      icon: Icons.error_outline,
    );
  }
}

class ImportRunStatusBanner extends StatelessWidget {
  const ImportRunStatusBanner({
    required this.message,
    required this.color,
    required this.icon,
    this.detail,
    super.key,
  });

  final String message;
  final Color color;
  final IconData icon;

  /// Optional additional content under the one-line status message.
  final Widget? detail;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('import-run-status'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(message), ?detail],
          ),
        ),
      ],
    ),
  );
}
