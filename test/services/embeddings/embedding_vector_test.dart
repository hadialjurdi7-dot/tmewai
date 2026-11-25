import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/services/embeddings/embedding_vector.dart';

void main() {
  test('little-endian float32 bytes round-trip bit-exactly', () {
    final values = Float32List.fromList(<double>[
      0.0,
      1.0,
      -1.0,
      0.1,
      -3.5,
      3.4028234663852886e+38,
    ]);

    final bytes = encodeFloat32Vector(values);
    final decoded = decodeFloat32Vector(bytes, dim: values.length);

    expect(bytes, hasLength(values.length * 4));
    expect(decoded, orderedEquals(values));
    // Re-encoding the decoded values must reproduce the same bytes, including
    // the exact float32 representation of 0.1 rather than its float64 form.
    expect(encodeFloat32Vector(decoded), orderedEquals(bytes));
  });

  test('writes the fixed little-endian representation of 1.0', () {
    final bytes = encodeFloat32Vector(Float32List.fromList([1.0]));

    expect(bytes, orderedEquals(<int>[0x00, 0x00, 0x80, 0x3F]));
  });

  test('rejects a blob whose length does not match the declared dimension', () {
    expect(
      () => decodeFloat32Vector(Uint8List(12), dim: 4),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => decodeFloat32Vector(Uint8List(16), dim: 3),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => decodeFloat32Vector(Uint8List(0), dim: 0),
      throwsA(isA<ArgumentError>()),
    );
  });
}
