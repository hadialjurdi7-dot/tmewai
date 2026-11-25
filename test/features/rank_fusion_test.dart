import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/features/search/rank_fusion.dart';

void main() {
  test('a document ranked first in both lists wins', () {
    final fused = fuseRankings([
      [1, 2, 3],
      [1, 4, 5],
    ]);

    expect(fused.first.eventId, 1);
    expect(fused.first.score, closeTo(2 / (rrfK + 1), 1e-12));
    expect(fused.map((rank) => rank.eventId), containsAll([2, 3, 4, 5]));
  });

  test('a document absent from one list still scores from the other', () {
    final fused = fuseRankings([
      [1, 2],
      [1],
    ]);

    final onlyLexical = fused.singleWhere((rank) => rank.eventId == 2);
    expect(onlyLexical.score, closeTo(1 / (rrfK + 2), 1e-12));
    expect(fused.first.eventId, 1);
  });

  test('a document present in both lists outranks one in a single list', () {
    final fused = fuseRankings([
      [1, 2],
      [2],
    ]);

    expect(fused.first.eventId, 2);
    expect(fused[1].eventId, 1);
  });

  test('equal scores fall back to the lexical date ordering', () {
    final fused = fuseRankings(
      [
        [1],
        [2],
      ],
      timestamps: {1: DateTime.utc(2024, 1, 1), 2: DateTime.utc(2026, 1, 1)},
    );

    expect(fused.map((rank) => rank.eventId), [2, 1]);
  });

  test('rejects a non-positive k', () {
    expect(
      () => fuseRankings([
        [1],
      ], k: 0),
      throwsA(isA<ArgumentError>()),
    );
  });
}
