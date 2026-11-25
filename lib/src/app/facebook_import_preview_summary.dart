import 'package:flutter/material.dart';
import 'package:personal_data_agent/src/core/errors/import_error_catalog.dart';
import 'package:personal_data_agent/src/services/importing/facebook_json_importer.dart';
import 'package:personal_data_agent/src/services/importing/import_coverage_report.dart';

class FacebookImportPreviewSummary extends StatelessWidget {
  const FacebookImportPreviewSummary({
    required this.preview,
    required this.isRtl,
    super.key,
  });

  final FacebookImportPreview preview;
  final bool isRtl;

  @override
  Widget build(BuildContext context) {
    final sample = preview.records.take(5).toList(growable: false);
    return Card(
      color: const Color(0xFFF6F8FA),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRtl ? 'معاينة الرسائل — لم تُحفظ' : 'Message preview — not saved',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(isRtl
                ? 'معاينة محلية فقط لملفات رسائل Facebook JSON المتوافقة. لا تُكتب أي بيانات إلى القرص.'
                : 'Local-only preview of supported Facebook messages JSON files. No records are written to disk.'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _CountChip(
                  label: isRtl ? 'الرسائل' : 'Messages',
                  count: preview.records.length,
                ),
                _CountChip(
                  label: isRtl ? 'الملفات المدعومة' : 'Supported files',
                  count: preview.supportedFiles,
                ),
                _CountChip(
                  label: isRtl ? 'ملفات JSON غير مدعومة' : 'Unsupported JSON',
                  count: preview.unsupportedJsonFiles,
                ),
                if (preview.knownNotImportedJsonFiles > 0)
                  _CountChip(
                    label: isRtl
                        ? 'ملفات معروفة لم تُستورد'
                        : 'Known, not imported',
                    count: preview.knownNotImportedJsonFiles,
                  ),
                _CountChip(
                  label: isRtl ? 'سجلات متجاوزة' : 'Skipped records',
                  count: preview.skippedRecords,
                ),
              ],
            ),
            if (preview.warnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                isRtl
                    ? 'تحذيرات تغطية: ${preview.warnings.map((code) => _warningText(code, isRtl)).join('، ')}'
                    : 'Coverage warnings: ${preview.warnings.map((code) => _warningText(code, isRtl)).join(', ')}',
                style: const TextStyle(color: Color(0xFF8A5A12)),
              ),
            ],
            ..._categoryRows(preview.coverage, isRtl, context),
            // Naming the skipped files turns "something is unsupported" into a
            // fixable report: a renamed export file shows up here by name.
            ..._unsupportedPaths(preview, isRtl, context),
            if (sample.isNotEmpty) ...[
              const Divider(height: 24),
              Text(isRtl ? 'عينة محلية' : 'Local sample',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              for (final record in sample)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    record.senderName ?? (isRtl ? 'مرسل غير معروف' : 'Unknown sender'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    // A typed payload is the record's label when it has no body
                    // of its own, so no sample row reads as an empty record.
                    record.text ??
                        record.payloadLabel(isRtl: isRtl) ??
                        (isRtl ? 'لا يوجد نص' : 'No text content'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: record.timestampUtc == null
                      ? null
                      : Text(
                          record.timestampUtc!.toIso8601String(),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                ),
              if (preview.records.length > sample.length)
                Text(isRtl
                    ? 'المعروض ${sample.length} من ${preview.records.length} سجلًا.'
                    : 'Showing ${sample.length} of ${preview.records.length} records.'),
            ],
          ],
        ),
      ),
    );
  }
}

/// Plain-language text for a coverage warning code.
///
/// Codes the catalog does not know stay as codes rather than inventing a
/// meaning.
String _warningText(String code, bool isRtl) {
  final entry = ImportErrorCatalog.byCode(code);
  if (entry == null) return code;
  return isRtl ? entry.messageAr : entry.messageEn;
}

/// One row per documented export root that the archive actually contains.
///
/// The row states what the folder is, how many files it holds and how many
/// records came out of it, so an unmodelled folder reads as "known, not
/// imported yet" instead of disappearing into an "unsupported" total.
List<Widget> _categoryRows(
  ImportCoverageReport coverage,
  bool isRtl,
  BuildContext context,
) {
  final rows = coverage.categories;
  if (rows.isEmpty) return const [];
  return [
    const Divider(height: 24),
    Text(
      isRtl ? 'تغطية مجلدات الأرشيف' : 'Archive folder coverage',
      style: const TextStyle(fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 6),
    for (final row in rows)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${row.category.label.inLocale(isRtl: isRtl)} — '
              '${isRtl ? '${row.files} ملفاً' : '${row.files} files'} · '
              '${isRtl ? '${row.recordsParsed} سجلاً' : '${row.recordsParsed} records'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              row.category.description.inLocale(isRtl: isRtl),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (row.knownNotImportedFiles > 0)
              Text(
                isRtl
                    ? 'منها ${row.knownNotImportedFiles} ملفاً معروفاً لم يُستورد بعد.'
                    : '${row.knownNotImportedFiles} known files are not imported yet.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: const Color(0xFF8A5A12)),
              ),
          ],
        ),
      ),
  ];
}

/// Names the files whose records the importer could not read.
///
/// Without this the screen only counts them, and a renamed export file is
/// indistinguishable from a corrupt one.
List<Widget> _unsupportedPaths(
  FacebookImportPreview preview,
  bool isRtl,
  BuildContext context,
) {
  final skipped = preview.files
      .where((file) => file.status == FacebookPreviewFileStatus.unsupported)
      .map((file) => file.path)
      .toList(growable: false);
  if (skipped.isEmpty) return const [];
  const shown = 5;
  final lines = skipped.take(shown).map((path) => '- $path').join('\n');
  final more = skipped.length > shown ? '\n+${skipped.length - shown} …' : '';
  return [
    const SizedBox(height: 10),
    Text(
      '${isRtl ? 'ملفات لم تُقرأ' : 'Files not read'} (${skipped.length}):'
      '\n$lines$more',
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: const Color(0xFF8A5A12)),
    ),
  ];
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $count'));
  }
}
