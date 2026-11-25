import 'dart:convert';

import 'import_text_repair.dart';

/// One Instagram DM thread, normalized from a `message_*.json` export file.
class InstagramThread {
  const InstagramThread({
    this.title,
    this.participants = const [],
    this.messages = const [],
    this.skipped = 0,
  });

  final String? title;
  final List<String> participants;
  final List<InstagramMessage> messages;

  /// Entries that could not be normalized (bad shape or timestamp).
  final int skipped;
}

/// One message of an Instagram DM thread.
class InstagramMessage {
  const InstagramMessage({
    required this.timestamp,
    required this.sender,
    this.text = '',
    this.attachments = const [],
    this.link,
    this.isSystem = false,
    this.reactions = const [],
  });

  /// UTC instant from the export's epoch-millisecond `timestamp_ms`.
  final DateTime timestamp;
  final String sender;
  final String text;
  final List<String> attachments;
  final String? link;
  final bool isSystem;

  /// Reaction tokens, repaired from Meta's mojibake when needed.
  ///
  /// Kept out of [text]: a reaction is metadata, not something the sender
  /// wrote in the message body.
  final List<String> reactions;
}

/// Repairs Instagram's double-encoded text.
///
/// `repairExportedText` already handles the Arabic round trip plus entities and
/// escapes. Instagram also double-encodes emoji in reactions, so the latin1 ->
/// utf8 round trip is attempted here with a looser "valid text" test: any
/// successful decode that changes the value and contains no replacement
/// character is kept. Already-correct text either cannot be encoded as latin1
/// or fails the decode, so it comes back untouched.
String repairInstagramMojibake(String value) {
  final roundTripped = _roundTripUtf8(value) ?? value;
  return repairExportedText(roundTripped) ?? roundTripped;
}

String? _roundTripUtf8(String value) {
  if (value.isEmpty) return null;
  final runes = value.runes.toList(growable: false);
  if (!runes.every((rune) => rune <= 0xFF) ||
      !runes.any((rune) => rune >= 0x80)) {
    return null;
  }
  try {
    final decoded = utf8.decode(latin1.encode(value));
    if (decoded == value || decoded.contains('\uFFFD')) return null;
    return decoded;
  } on FormatException {
    return null;
  }
}

const int _minEpochMillis = -62135596800000;
const int _maxEpochMillis = 253402300799999;
const Set<String> _attachmentFields = {
  'photos',
  'videos',
  'audio_files',
  'files',
};

/// Parses one Instagram thread JSON document. Never throws: an empty,
/// malformed or unknown-shape document yields an empty thread.
InstagramThread parseThreadJson(String json) {
  Object? decoded;
  try {
    decoded = jsonDecode(json);
  } on Object {
    return const InstagramThread(skipped: 1);
  }
  if (decoded is! Map<String, dynamic>) return const InstagramThread();

  final title = decoded['title'];
  final participants = <String>[];
  final rawParticipants = decoded['participants'];
  if (rawParticipants is List) {
    for (final item in rawParticipants) {
      final name = item is Map<String, dynamic> ? item['name'] : null;
      if (name is! String || name.trim().isEmpty) continue;
      participants.add(repairInstagramMojibake(name));
    }
  }

  final messages = <InstagramMessage>[];
  var skipped = 0;
  final rawMessages = decoded['messages'];
  if (rawMessages is List) {
    for (final item in rawMessages) {
      final message = _messageOf(item);
      if (message == null) {
        skipped++;
      } else {
        messages.add(message);
      }
    }
  } else if (rawMessages != null) {
    skipped = 1;
  }

  return InstagramThread(
    title: title is String && title.isNotEmpty
        ? repairInstagramMojibake(title)
        : null,
    participants: List.unmodifiable(participants),
    messages: List.unmodifiable(messages),
    skipped: skipped,
  );
}

InstagramMessage? _messageOf(Object? item) {
  if (item is! Map<String, dynamic>) return null;
  final timestamp = item['timestamp_ms'];
  final sender = item['sender_name'];
  if (timestamp is! int ||
      timestamp < _minEpochMillis ||
      timestamp > _maxEpochMillis ||
      sender is! String ||
      sender.trim().isEmpty) {
    return null;
  }

  final content = item['content'];
  final attachments = <String>[];
  for (final field in _attachmentFields) {
    final list = item[field];
    if (list is! List) continue;
    for (final entry in list) {
      final uri = entry is Map<String, dynamic> ? entry['uri'] : entry;
      if (uri is! String || uri.isEmpty || uri.length > 1024) continue;
      attachments.add(uri);
    }
  }

  final share = item['share'];
  final link = share is Map<String, dynamic> ? share['link'] : null;

  final reactions = <String>[];
  final rawReactions = item['reactions'];
  if (rawReactions is List) {
    for (final reaction in rawReactions) {
      final token = reaction is Map<String, dynamic>
          ? reaction['reaction']
          : null;
      if (token is! String || token.isEmpty || token.length > 64) continue;
      reactions.add(repairInstagramMojibake(token));
    }
  }

  final type = item['type'];
  return InstagramMessage(
    timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true),
    sender: repairInstagramMojibake(sender),
    text: content is String ? repairInstagramMojibake(content) : '',
    attachments: List.unmodifiable(attachments),
    link: link is String ? link : null,
    isSystem: item['is_system'] == true ||
        type == 'system' ||
        type == 'system_update',
    reactions: List.unmodifiable(reactions),
  );
}

/// Parses every `(path, content)` of an already-read Instagram inbox.
///
/// Pure over its input: no file IO, no media bytes. Malformed files contribute
/// an empty thread with `skipped == 1` rather than stopping the batch.
List<InstagramThread> parseInboxDirectory(
  List<(String path, String content)> files,
) => [for (final file in files) parseThreadJson(file.$2)];
