/// Reciprocal Rank Fusion constant from the task notes.
///
/// The exact value matters less than using the same one for every list: it
/// dampens the difference between adjacent ranks so a document that both
/// retrievers like outranks one that a single retriever put first.
const int rrfK = 60;

/// One document after fusion, with the score that determined its position.
class FusedSearchRank {
  const FusedSearchRank({required this.eventId, required this.score});

  final int eventId;
  final double score;
}

/// Fuses ranked event-id lists without comparing their native scores.
///
/// `score = Σ 1 / (k + rank)` with a one-based rank, exactly as specified.
/// Lexical bm25 values and cosine similarities live on different scales, so
/// adding or normalizing them would be arbitrary; ranks are the common
/// language. A document missing from one list still receives the contribution
/// from the list it appears in.
///
/// [timestamps] is the tie-breaker, not part of the score. When two documents
/// have identical fusion scores, dated rows come before undated ones and newer
/// dates come first, matching the lexical path's ordering promise. The final
/// id comparison keeps the result deterministic for ties on the same date.
List<FusedSearchRank> fuseRankings(
  List<List<int>> rankings, {
  int k = rrfK,
  Map<int, DateTime?> timestamps = const {},
}) {
  if (k < 1) {
    throw ArgumentError.value(k, 'k', 'must be positive');
  }
  final scores = <int, double>{};
  for (final ranking in rankings) {
    for (var index = 0; index < ranking.length; index++) {
      final eventId = ranking[index];
      scores[eventId] = (scores[eventId] ?? 0.0) + 1.0 / (k + index + 1);
    }
  }

  final fused = [
    for (final entry in scores.entries)
      FusedSearchRank(eventId: entry.key, score: entry.value),
  ];
  fused.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    final aDate = timestamps[a.eventId];
    final bDate = timestamps[b.eventId];
    if (aDate == null && bDate != null) return 1;
    if (aDate != null && bDate == null) return -1;
    if (aDate != null && bDate != null) {
      final byDate = bDate.compareTo(aDate);
      if (byDate != 0) return byDate;
    }
    return a.eventId.compareTo(b.eventId);
  });
  return fused;
}
