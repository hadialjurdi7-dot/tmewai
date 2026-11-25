import 'dart:convert';

import '../../domain/models/event_record.dart';
import 'archive_inspector.dart';
import 'facebook_json_importer.dart';
import 'import_coverage_report.dart';
import 'whatsapp_txt_importer.dart';

/// Stored provenance for this format. There is no source-format enum in the
/// codebase: `platform`/`format` are plain strings on every import row.
const String whatsappPlatform = 'whatsapp';
const String whatsappTxtFormat = 'txt';

/// Turns parsed chats into the same normalized preview the Facebook importer
/// produces, so the coordinator writes both through one transaction and one
/// events/attachments schema. No new column or migration is needed.
class WhatsAppImportAdapter {
  const WhatsAppImportAdapter({this.parser = const WhatsAppTxtImporter()});

  final WhatsAppTxtImporter parser;

  /// [chats] maps an archive-relative file path to its decoded text.
  FacebookImportPreview preview(Map<String, String> chats) {
    final entries = <InspectedArchiveEntry>[];
    final files = <FacebookPreviewFile>[];
    final records = <FacebookRecord>[];
    final outcomes = <ImportFileOutcome>[];
    var skipped = 0;
    var bytes = 0;

    for (final chat in chats.entries) {
      final path = chat.key;
      final length = utf8.encode(chat.value).length;
      bytes += length;
      entries.add(
        InspectedArchiveEntry(
          relativePath: path,
          size: length,
          isDirectory: false,
          isMedia: false,
        ),
      );

      final parsed = parser.parse(chat.value);
      final title = path.split('/').last.replaceFirst(RegExp(r'\.txt$', caseSensitive: false), '');
      for (var index = 0; index < parsed.messages.length; index++) {
        final message = parsed.messages[index];
        records.add(
          FacebookRecord(
            eventType: 'message',
            sourcePath: path,
            sourceLocator: '$path#$index',
            conversationKey: path,
            conversationTitle: title.isEmpty ? null : title,
            senderName: message.sender,
            text: message.text,
            timestampRaw: message.timestampRaw,
            // WhatsApp states a wall-clock time, never an offset: store it as
            // local and say so, instead of pretending it is a UTC instant.
            timestampUtc: message.timestamp,
            timezoneStatus: TimezoneStatus.localTime,
            metadata: message.attachmentName == null
                ? null
                : {whatsappAttachmentMetadataKey: message.attachmentName!},
          ),
        );
      }
      skipped += parsed.skipped;
      files.add(
        FacebookPreviewFile(
          path: path,
          status: FacebookPreviewFileStatus.parsed,
          recordsParsed: parsed.messages.length,
          recordsSkipped: parsed.skipped,
        ),
      );
      outcomes.add(
        ImportFileOutcome(
          path: path,
          reason: ImportCoverageReason.supported,
          recordsParsed: parsed.messages.length,
          recordsSkipped: parsed.skipped,
        ),
      );
    }

    final inspection = ArchiveInspection(
      entries: entries.length,
      totalExpandedBytes: bytes,
      jsonFiles: 0,
      mediaFiles: 0,
      ignoredFiles: 0,
      warnings: const [],
    );
    final scan = ArchiveScan(
      inspection: inspection,
      jsonFiles: const [],
      entries: List.unmodifiable(entries),
    );
    final unmodifiableFiles = List<FacebookPreviewFile>.unmodifiable(files);
    return FacebookImportPreview(
      archiveInspection: inspection,
      scan: scan,
      records: List.unmodifiable(records),
      files: unmodifiableFiles,
      coverage: ImportCoverageReport.fromScan(
        scan,
        outcomes: List.unmodifiable(outcomes),
      ),
      supportedFiles: files.length,
      unsupportedJsonFiles: 0,
      knownNotImportedJsonFiles: 0,
      skippedRecords: skipped,
      warnings: const [],
    );
  }
}
