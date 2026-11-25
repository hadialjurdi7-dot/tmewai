import 'dart:typed_data';

/// Serializes [vector] as little-endian float32 bytes.
///
/// The byte order is fixed rather than taken from the host so a database file
/// written on a little-endian Windows machine stays readable by a build on any
/// other architecture. This is the only place vectors become bytes.
Uint8List encodeFloat32Vector(Float32List vector) {
  final bytes = Uint8List(vector.length * 4);
  final data = ByteData.sublistView(bytes);
  for (var index = 0; index < vector.length; index++) {
    data.setFloat32(index * 4, vector[index], Endian.little);
  }
  return bytes;
}

/// Reads little-endian float32 [bytes] back into a vector of exactly [dim]
/// values.
///
/// A blob whose length is not `dim * 4` is rejected instead of being padded or
/// truncated: a short vector would otherwise be silently compared against only
/// the first part of a query and produce meaningless scores.
Float32List decodeFloat32Vector(Uint8List bytes, {required int dim}) {
  if (dim <= 0) {
    throw ArgumentError.value(dim, 'dim', 'must be positive');
  }
  final expectedLength = dim * 4;
  if (bytes.length != expectedLength) {
    throw FormatException(
      'Expected $expectedLength bytes for a $dim-dimensional float32 vector, '
      'got ${bytes.length}.',
    );
  }
  final data = ByteData.sublistView(bytes);
  final vector = Float32List(dim);
  for (var index = 0; index < dim; index++) {
    vector[index] = data.getFloat32(index * 4, Endian.little);
  }
  return vector;
}
