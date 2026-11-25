import 'dart:convert';

/// Allowlisted metadata key holding the filename a WhatsApp message quoted in
/// `<attached: …>`. The media bytes are never read or stored here.
const String whatsappAttachmentMetadataKey = 'attached_file';

/// One parsed chat line that carries a sender.
class WhatsAppMessage {
  const WhatsAppMessage({
    required this.timestamp,
    required this.sender,
    required this.text,
    this.timestampRaw,
    this.attachmentName,
    this.isSystem = false,
  });

  /// Wall-clock time as written in the export. WhatsApp exports carry no UTC
  /// offset, so this is deliberately not converted to UTC.
  final DateTime timestamp;

  /// The date/time prefix exactly as it appeared, for provenance.
  final String? timestampRaw;
  final String sender;
  final String text;

  /// Filename quoted in `<attached: filename>`, when the line carried one.
  final String? attachmentName;

  /// System notifications are never returned in [WhatsAppChat.messages].
  final bool isSystem;
}

/// The typed result of parsing one WhatsApp chat export.
class WhatsAppChat {
  const WhatsAppChat({
    this.messages = const [],
    this.systemLines = 0,
    this.skipped = 0,
  });

  final List<WhatsAppMessage> messages;

  /// Timestamped lines with no sender (encryption notice, joins, subject/icon
  /// changes). Counted, never stored as messages.
  final int systemLines;

  /// Lines whose shape this parser does not recognize. Never thrown on.
  final int skipped;
}

/// Pure-Dart parser for WhatsApp "Export chat" `.txt` files.
///
/// No plugins, no file access, no network: it only reads the strings handed to
/// it. Unknown line shapes are counted in [WhatsAppChat.skipped].
class WhatsAppTxtImporter {
  const WhatsAppTxtImporter();

  WhatsAppChat parse(String content) => parseLines(_split(content));

  /// Decodes export bytes (UTF-8, tolerant of a broken trailing character).
  WhatsAppChat parseBytes(List<int> bytes) =>
      parse(utf8.decode(bytes, allowMalformed: true));

  WhatsAppChat parseLines(List<String> lines) {
    final drafts = <_Draft>[];
    _Draft? current;
    var systemLines = 0;
    var skipped = 0;

    for (final line in lines) {
      final text = line.replaceAll('\uFEFF', '').trim();
      if (text.isEmpty) continue;

      final header = _header(text);
      if (header != null) {
        final person = _senderAndText(rest: header.rest);
        if (person == null) {
          // A recognized timestamp with no "Sender:" is a system notice.
          systemLines++;
          current = null;
          continue;
        }
        final draft = _Draft(
          timestamp: header.timestamp,
          timestampRaw: header.raw,
          sender: person.sender,
          text: person.text,
          attachmentName: person.attachmentName,
        );
        drafts.add(draft);
        current = draft;
      } else if (current != null) {
        // Continuation line: it belongs to the previous message, verbatim.
        final attachment = _attachmentNameOf(text);
        current.text = '${current.text}\n$text';
        current.attachmentName ??= attachment;
      } else {
        skipped++;
      }
    }

    return WhatsAppChat(
      messages: List.unmodifiable([
        for (final draft in drafts)
          WhatsAppMessage(
            timestamp: draft.timestamp,
            timestampRaw: draft.timestampRaw,
            sender: draft.sender,
            text: draft.text,
            attachmentName: draft.attachmentName,
          ),
      ]),
      systemLines: systemLines,
      skipped: skipped,
    );
  }

  List<String> _split(String content) =>
      content.split(RegExp(r'\r\n|\n|\r'));

  /// Matches the three export header shapes. 12h is tried first: the AM/PM
  /// suffix is what distinguishes a US MM/DD export from Android's DD/MM.
  ({DateTime timestamp, String raw, String rest})? _header(String line) {
    final bracket = _bracketHeader.firstMatch(line);
    if (bracket != null) {
      final time = _dateTime(
        day: int.parse(bracket.group(1)!),
        month: int.parse(bracket.group(2)!),
        year: int.parse(bracket.group(3)!),
        hour: int.parse(bracket.group(4)!),
        minute: int.parse(bracket.group(5)!),
        second: int.tryParse(bracket.group(6) ?? '0') ?? 0,
        is24Hour: true,
      );
      if (time == null) return null;
      final raw = '[${bracket.group(1)}/${bracket.group(2)}/${bracket.group(3)}, '
          '${bracket.group(4)}:${bracket.group(5)}'
          '${bracket.group(6) == null ? '' : ':${bracket.group(6)}'}]';
      return (timestamp: time, raw: raw, rest: bracket.group(7)!);
    }

    final twelve = _twelveHourHeader.firstMatch(line);
    if (twelve != null) {
      final time = _dateTime(
        day: int.parse(twelve.group(2)!),
        month: int.parse(twelve.group(1)!),
        year: int.parse(twelve.group(3)!),
        hour: int.parse(twelve.group(4)!),
        minute: int.parse(twelve.group(5)!),
        second: 0,
        is24Hour: false,
        isPm: twelve.group(6)!.toLowerCase() == 'pm',
      );
      if (time == null) return null;
      final raw = '${twelve.group(1)}/${twelve.group(2)}/${twelve.group(3)}, '
          '${twelve.group(4)}:${twelve.group(5)} ${twelve.group(6)}';
      return (timestamp: time, raw: raw, rest: twelve.group(7)!);
    }

    final twentyFour = _twentyFourHourHeader.firstMatch(line);
    if (twentyFour != null) {
      final time = _dateTime(
        day: int.parse(twentyFour.group(1)!),
        month: int.parse(twentyFour.group(2)!),
        year: int.parse(twentyFour.group(3)!),
        hour: int.parse(twentyFour.group(4)!),
        minute: int.parse(twentyFour.group(5)!),
        second: 0,
        is24Hour: true,
      );
      if (time == null) return null;
      final raw = '${twentyFour.group(1)}/${twentyFour.group(2)}/'
          '${twentyFour.group(3)}, '
          '${twentyFour.group(4)}:${twentyFour.group(5)}';
      return (
        timestamp: time,
        raw: raw,
        rest: twentyFour.group(6)!,
      );
    }
    return null;
  }

  ({String sender, String text, String? attachmentName})? _senderAndText({
    required String rest,
  }) {
    final colon = rest.indexOf(':');
    if (colon <= 0) return null;
    final sender = rest.substring(0, colon).trim();
    if (sender.isEmpty) return null;
    final text = rest.substring(colon + 1).trim();
    return (
      sender: sender,
      text: text,
      attachmentName: _attachmentNameOf(text),
    );
  }

  String? _attachmentNameOf(String text) {
    final match = _attachedPattern.firstMatch(text);
    if (match == null) return null;
    final name = match.group(1)!.trim().replaceAll('\u200e', '');
    return name.isEmpty ? null : name;
  }

  DateTime? _dateTime({
    required int day,
    required int month,
    required int year,
    required int hour,
    required int minute,
    required int second,
    required bool is24Hour,
    bool isPm = false,
  }) {
    final fullYear = year < 100 ? 2000 + year : year;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    if (minute > 59 || second > 59) return null;
    final h = is24Hour
        ? hour
        : hour % 12 + (isPm ? 12 : 0);
    if (h > 23) return null;
    try {
      return DateTime(fullYear, month, day, h, minute, second);
    } on RangeError {
      return null;
    }
  }

  static final RegExp _bracketHeader = RegExp(
    r'^\[(\d{1,2})/(\d{1,2})/(\d{2,4}),\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\]\s*(.*)$',
  );
  static final RegExp _twelveHourHeader = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{2,4}),\s*(\d{1,2}):(\d{2})\s*([AaPp][Mm])\s*-\s*(.*)$',
  );
  static final RegExp _twentyFourHourHeader = RegExp(
    r'^(\d{1,2})/(\d{1,2})/(\d{2,4}),\s*(\d{1,2}):(\d{2})\s*-\s*(.*)$',
  );
  static final RegExp _attachedPattern = RegExp(
    r'<attached:\s*([^>]+)>',
    caseSensitive: false,
  );
}

class _Draft {
  _Draft({
    required this.timestamp,
    required this.timestampRaw,
    required this.sender,
    required this.text,
    required this.attachmentName,
  });

  final DateTime timestamp;
  final String? timestampRaw;
  final String sender;
  String text;
  String? attachmentName;
}
