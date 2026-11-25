import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/services/importing/import_text_repair.dart';

/// Real mojibake, produced the way the archive produces it: UTF-8 bytes read
/// back as Latin-1. Written as a helper so the assertion cannot drift from the
/// definition.
String mojibake(String arabic) => latin1.decode(utf8.encode(arabic));

void main() {
  test('repairs UTF-8 text that was read as Latin-1', () {
    expect(repairExportedText(mojibake('أهلاً بك')), 'أهلاً بك');
    expect(repairExportedText(mojibake('شو الطبخة اليوم؟')), 'شو الطبخة اليوم؟');
    // Mixed text and punctuation survive the round trip unchanged.
    expect(repairExportedText(mojibake('حسام: تمام، منشوفك بكرا 10:30')),
        'حسام: تمام، منشوفك بكرا 10:30');
  });

  test('repairs numeric HTML entities', () {
    expect(repairExportedText('&#1587;&#1604;&#1575;&#1605;'), 'سلام');
    expect(repairExportedText('&#x633;&#x644;&#x627;&#x645;'), 'سلام');
  });

  test('repairs literal backslash-u escapes', () {
    expect(repairExportedText(r'\u0633\u0644\u0627\u0645'), 'سلام');
  });

  test('unescapes JSON-escaped slashes', () {
    expect(repairExportedText(r'a\/b'), 'a/b');
    expect(repairExportedText('plain/path'), isNull);
  });

  test('leaves correct text alone', () {
    expect(repairExportedText('أهلاً بك'), isNull);
    expect(repairExportedText('hello world'), isNull);
    expect(repairExportedText('messages/inbox/message_1.json#3'), isNull);
    expect(repairExportedText('sha256:abc123'), isNull);
    expect(repairExportedText(''), isNull);
    // Latin-1-only text that never decodes to Arabic must not be rewritten.
    expect(repairExportedText('café'), isNull);
    expect(repairExportedText('naïve façade'), isNull);
  });

  test('repairs the text the browser writes into a proxy column', () {
    // A single quote and an entity in the same value: both rules apply in one
    // pass, and neither touches the already-correct Arabic.
    final broken = '${mojibake('ما في شي')} &amp; &#1587;';
    final repaired = repairExportedText(broken);
    expect(repaired, startsWith('ما في شي'));
    expect(repaired, contains('&'));
    expect(repaired, contains('س'));
  });
}
