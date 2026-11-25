/// Search-only Arabic spelling folds, shared by the indexed copy and query.
///
/// `unicode61 remove_diacritics 2` strips Latin marks but treats Arabic harakat
/// as separators. Folding these variants before tokenization keeps common
/// keyboard spellings searchable without changing the stored event text.
/// Empty replacements remove a rune; non-empty replacements fold it.
const Map<int, String> searchTextFolds = {
  0x064B: '', // fathatan
  0x064C: '', // dammatan
  0x064D: '', // kasratan
  0x064E: '', // fatha
  0x064F: '', // damma
  0x0650: '', // kasra
  0x0651: '', // shadda
  0x0652: '', // sukun
  0x0653: '', // maddah above
  0x0654: '', // hamza above
  0x0655: '', // hamza below
  0x0656: '', // subscript alef
  0x0657: '', // inverted damma
  0x0658: '', // mark noon ghunna
  0x0659: '', // zwarakay
  0x065A: '', // v above
  0x065B: '', // inverted small v
  0x065C: '', // dot below
  0x065D: '', // reversed damma
  0x065E: '', // fatha with two dots
  0x065F: '', // wavy hamza below
  0x0670: '', // superscript alef
  0x0623: '\u0627', // alef with hamza above -> alef
  0x0625: '\u0627', // alef with hamza below -> alef
  0x0622: '\u0627', // alef with madda -> alef
  0x0671: '\u0627', // alef wasla -> alef
  0x0649: '\u064A', // alef maqsura -> yaa
  0x0629: '\u0647', // taa marbuta -> haa
  0x0640: '', // tatweel
};

/// Applies [searchTextFolds] to [input], leaving all other text untouched.
/// Only the search index and query go through this; stored event text retains
/// the spelling present in the export.
String normalizeSearchText(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    buffer.write(searchTextFolds[rune] ?? String.fromCharCode(rune));
  }
  return buffer.toString();
}

/// SQL expression applying exactly [searchTextFolds] to [column], used by the
/// `event_search` triggers. The declaration is shared with the Dart normalizer
/// so the index and query cannot drift apart.
String searchTextSqlExpression(String column) {
  var expression = 'COALESCE($column, \'\')';
  for (final entry in searchTextFolds.entries) {
    expression =
        "replace($expression, '${String.fromCharCode(entry.key)}', "
        "'${entry.value}')";
  }
  return expression;
}
