/// Repairs text that an export stored in a broken encoding.
///
/// Facebook's archive is written by several pipelines and more than one hands
/// back a string that is really UTF-8 bytes read as Latin-1: the reader shows
/// `Ø£Ù‡Ù„Ø§Ù‹` where the message said `أهلاً`. Another leaves numeric HTML
/// entities (`&#1587;`), literal `\u0633` escapes or JSON-escaped slashes
/// (`\/`) in `content`, `title` and `name`. All four are recoverable from the
/// decoded string alone.
///
/// Every rule is one-way and conservative: a replacement is only returned for
/// evidence the string itself carries - a candidate that decodes to Arabic, or
/// the UTF-8 lead-and-continuation pairing correct single-byte text never holds
/// (a document encoded twice) - so text that is already correct is never folded
/// or damaged.
library;

import 'dart:convert';

/// Repaired text, or `null` when the input needs no repair.
///
/// `null` is the common answer: correct Arabic, English, paths, fingerprints and
/// ids all return it, and the caller keeps the original string.
String? repairExportedText(String input) {
  if (input.isEmpty) return null;

  // The rules stack, and one value can be damaged more than once: a document
  // that was encoded twice needs a second round. Each round only counts when
  // it changes the value, and the loop is bounded so a pathological string
  // cannot spin. Correct Arabic leaves the loop after one no-op round.
  var value = input;
  for (var round = 0; round < _maxRepairRounds; round++) {
    final next = _repairOnce(value);
    if (next == null) break;
    value = next;
  }
  return value == input ? null : value;
}

/// Rounds of repair attempted before giving up. Two layers of double encoding
/// is the worst seen in a real export; the extra round costs nothing because a
/// repaired value short-circuits every rule.
const int _maxRepairRounds = 3;

/// Every rule applied once, in order. Returns null when nothing changed.
String? _repairOnce(String input) {
  // One value can be mojibake *and* carry an entity, so each pass feeds the
  // next instead of the first match winning.
  var value = _fromMojibake(input) ?? input;
  value = _fromHtmlEntities(value) ?? value;
  value = _fromEscapedUnicode(value) ?? value;
  value = _fromEscapedSlashes(value) ?? value;
  return value == input ? null : value;
}

/// `U+0600..U+06FF`: the Arabic block. Covers every letter, diacritic and the
/// Arabic comma the archive uses, and nothing an export writes in Latin-1.
bool _hasArabic(String value) =>
    value.runes.any((rune) => rune >= 0x600 && rune <= 0x6FF);

/// One UTF-8 sequence decoded as Latin-1 lands entirely in `U+0080..U+00FF`, so
/// a string holding a rune above `U+00FF` is not pure mojibake and is left alone.
String? _fromMojibake(String value) {
  if (!value.runes.every((rune) => rune <= 0xFF)) return null;
  if (!value.runes.any((rune) => rune >= 0x80)) return null;

  // `latin1.encode` rejects code points above 0xFF, which the guard above rules
  // out, so the round trip is exact.
  String decoded;
  try {
    decoded = utf8.decode(latin1.encode(value), allowMalformed: false);
  } on FormatException {
    return null;
  }
  if (decoded == value) return null;
  // Accept the decode when it recovers Arabic, or when the result is itself
  // still plainly mis-decoded UTF-8 - the signature of a document that was
  // encoded twice. The caller loops, so that next layer is finished there;
  // text that is merely accented Latin-1 never matches either condition.
  if (!_hasArabic(decoded) && !_looksLikeMojibake(decoded)) return null;
  return decoded;
}

/// True when [value] holds a UTF-8 lead byte followed by a continuation byte.
///
/// That pairing cannot occur in text read correctly from a single-byte encoding,
/// so it is the evidence that a further round of mojibake repair is real work
/// and not a guess.
bool _looksLikeMojibake(String value) {
  final runes = value.runes.toList(growable: false);
  for (var i = 0; i + 1 < runes.length; i++) {
    if (runes[i] >= 0xC2 &&
        runes[i] <= 0xF4 &&
        runes[i + 1] >= 0x80 &&
        runes[i + 1] <= 0xBF) {
      return true;
    }
  }
  return false;
}

final RegExp _numericEntity = RegExp(r'&#(?:[xX]([0-9a-fA-F]+)|([0-9]+));');
final RegExp _namedEntity = RegExp(r'&(amp|lt|gt|quot|apos|nbsp|#039);');

String? _fromHtmlEntities(String value) {
  if (!value.contains('&')) return null;
  var changed = false;
  final out = value
      .replaceAllMapped(_numericEntity, (match) {
        final hex = match.group(1);
        final parsed = hex != null
            ? int.tryParse(hex, radix: 16)
            : int.tryParse(match.group(2)!);
        if (parsed == null || parsed > 0x10FFFF) return match.group(0)!;
        changed = true;
        return String.fromCharCode(parsed);
      })
      .replaceAllMapped(_namedEntity, (match) {
        changed = true;
        return switch (match.group(1)!) {
          'amp' => '&',
          'lt' => '<',
          'gt' => '>',
          'quot' => '"',
          'apos' || '#039' => "'",
          'nbsp' => ' ',
          _ => match.group(0)!,
        };
      });
  return changed ? out : null;
}

final RegExp _escapedUnicode = RegExp(r'\\u([0-9a-fA-F]{4})');

String? _fromEscapedUnicode(String value) {
  if (!value.contains(r'\u')) return null;
  var changed = false;
  final out = value.replaceAllMapped(_escapedUnicode, (match) {
    final code = int.tryParse(match.group(1)!, radix: 16);
    if (code == null) return match.group(0)!;
    changed = true;
    return String.fromCharCode(code);
  });
  if (!changed || !_hasArabic(out)) return null;
  return out;
}

/// `\/` is how JSON escapes a slash. A file that was encoded twice, or a string
/// the export kept JSON-escaped, carries the escape through to the reader; the
/// slash itself is the only thing it can mean, so the rewrite is one-way and
/// content-preserving.
String? _fromEscapedSlashes(String value) {
  if (!value.contains(r'\/')) return null;
  return value.replaceAll(r'\/', '/');
}
