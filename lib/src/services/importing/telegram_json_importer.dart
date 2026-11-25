import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../core/errors/import_report.dart';
import 'facebook_json_importer.dart';

/// Stable sender used when a Telegram export omits `from` (saved messages and
/// channels). Never null, so a missing sender cannot crash the write path.
const String telegramUnknownSender = 'unknown';

/// Allowlisted metadata keys kept for a Telegram message. Only names and type
/// labels are stored; media bytes are never read.
const String telegramAttachmentKey = 'attachment';
const String telegramMimeKey = 'mime_type';
const String telegramReplyKey = 'reply_to';

/// One normal Telegram message from a `result.json` export.
///
/// `service` records are counted on [TelegramChat.serviceCount], never added
/// here, so every element of [TelegramChat.messages] is real message content.
class TelegramMessage {
  const TelegramMessage({
    required this.id,
    required this.timestamp,
    required this.sender,
    required this.text,
    this.attachmentName,
    this.mimeType,
    this.isService = false,
    this.replyToId,
  });

  final int id;
  final DateTime timestamp;
  final String sender;
  final String text;
  final String? attachmentName;
  final String? mimeType;
  final bool isService;
  final int? replyToId;
}

/// One Telegram chat decoded from a `result.json` export.
class TelegramChat {
  const TelegramChat({
    this.title,
    this.type,
    this.messages = const [],
    this.serviceCount = 0,
    this.skipped = 0,
  });

  final String? title;
  final String? type;
  final List<TelegramMessage> messages;

  /// `type: "service"` entries: system events, not messages.
  final int serviceCount;

  /// Entries that were not usable (bad id/timestamp or not an object).
  final int skipped;
}

class TelegramImportException implements CodedException {
  const TelegramImportException(this.code, this.message);

  @override
  final String code;
  final String message;

  @override
  String toString() => 'TelegramImportException($code): $message';
}

/// Pure-Dart parser for Telegram Desktop's `Export chat history → JSON`.
///
/// Tolerant by design: a wrong shape, a missing key or an empty `messages`
/// list yields an empty [TelegramChat] instead of throwing.
class TelegramJsonImporter {
  const TelegramJsonImporter();

  TelegramChat parseBytes(Uint8List bytes) =>
      parse(utf8.decode(bytes, allowMalformed: true));

  TelegramChat parse(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      return const TelegramChat();
    }
    if (decoded is! Map<String, dynamic>) return const TelegramChat();

    final title = decoded['name'] is String ? decoded['name'] as String : null;
    final type = decoded['type'] is String ? decoded['type'] as String : null;
    final raw = decoded['messages'];
    if (raw is! List) return TelegramChat(title: title, type: type);

    final messages = <TelegramMessage>[];
    var serviceCount = 0;
    var skipped = 0;
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) {
        skipped++;
        continue;
      }
      if (entry['type'] == 'service') {
        serviceCount++;
        continue;
      }
      final timestamp = _timestampOf(entry);
      final id = _intOf(entry['id']);
      if (timestamp == null || id == null) {
        skipped++;
        continue;
      }
      messages.add(
        TelegramMessage(
          id: id,
          timestamp: timestamp,
          sender: _senderOf(entry),
          text: _flattenText(entry['text']),
          attachmentName: _attachmentNameOf(entry),
          mimeType: _stringOf(entry['mime_type']),
          replyToId: _intOf(entry['reply_to_message_id']),
        ),
      );
    }
    return TelegramChat(
      title: title,
      type: type,
      messages: List.unmodifiable(messages),
      serviceCount: serviceCount,
      skipped: skipped,
    );
  }

  /// Converts parsed messages into the app's existing normalized record, so the
  /// coordinator's `events`/`people`/`conversations` write path is reused as-is.
  List<FacebookRecord> toRecords(
    TelegramChat chat, {
    String sourcePath = 'result.json',
  }) {
    final records = <FacebookRecord>[];
    for (var index = 0; index < chat.messages.length; index++) {
      final message = chat.messages[index];
      final metadata = <String, String>{
        if (message.attachmentName != null)
          telegramAttachmentKey: message.attachmentName!,
        if (message.mimeType != null) telegramMimeKey: message.mimeType!,
        if (message.replyToId != null)
          telegramReplyKey: message.replyToId.toString(),
      };
      records.add(
        FacebookRecord(
          eventType: 'message',
          sourcePath: sourcePath,
          sourceLocator: '$sourcePath#/messages/$index',
          conversationKey: chat.title ?? 'telegram-chat',
          conversationTitle: chat.title,
          senderName: message.sender,
          text: message.text,
          timestampRaw: (message.timestamp.millisecondsSinceEpoch ~/ 1000)
              .toString(),
          timestampUtc: message.timestamp,
          metadata: metadata.isEmpty ? null : Map.unmodifiable(metadata),
        ),
      );
    }
    return records;
  }

  /// Cheap content sniff used by the picker path to choose this importer.
  static bool looksLikeTelegramSource(
    Uint8List bytes, {
    String? name,
  }) {
    if (looksLikeTelegram(bytes)) return true;
    if ((name ?? '').toLowerCase().endsWith('.json')) return false;
    // A Telegram ZIP carries a top-level `result.json`. `archive` only reads
    // entry names here; no entry is extracted.
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      for (final file in archive.files) {
        if (file.isFile && file.name.split('/').last.toLowerCase() ==
            'result.json') {
          return true;
        }
      }
    } on Object {
      // Not a readable ZIP: let the Facebook path report it.
    }
    return false;
  }

  static bool looksLikeTelegram(Uint8List bytes) {
    final length = bytes.length < 65536 ? bytes.length : 65536;
    final text = utf8.decode(bytes.sublist(0, length), allowMalformed: true);
    return text.contains('"date_unixtime"') || text.contains('"from_id"');
  }

  static String? _stringOf(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static int? _intOf(Object? value) => switch (value) {
    int() => value,
    String() => int.tryParse(value),
    _ => null,
  };

  static String _senderOf(Map<String, dynamic> entry) =>
      _stringOf(entry['from']) ?? telegramUnknownSender;

  static String? _attachmentNameOf(Map<String, dynamic> entry) {
    for (final key in const ['photo', 'file', 'thumbnail']) {
      final name = _stringOf(entry[key]);
      if (name != null) return name;
    }
    return null;
  }

  /// Prefers `date_unixtime` (string epoch seconds, UTC); falls back to `date`.
  static DateTime? _timestampOf(Map<String, dynamic> entry) {
    final seconds = _intOf(entry['date_unixtime']);
    if (seconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    }
    final date = entry['date'];
    if (date is! String || date.isEmpty) return null;
    final hasZone = date.endsWith('Z') ||
        RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(date);
    return DateTime.tryParse(hasZone ? date : '${date}Z')?.toUtc();
  }

  /// Flattens a Telegram `text` value: a plain string, or an ordered list of
  /// strings and entity maps. Entity styling is ignored; only `text` is kept.
  static String _flattenText(Object? value) {
    final buffer = StringBuffer();
    void write(Object? part) {
      if (part is String) {
        buffer.write(part);
      } else if (part is List) {
        for (final item in part) {
          write(item);
        }
      } else if (part is Map) {
        write(part['text']);
      }
    }

    write(value);
    return buffer.toString();
  }
}
