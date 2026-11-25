import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Random-access ZIP reader: it never loads the whole archive.
///
/// The previous path read the entire compressed ZIP into memory, so a real
/// Facebook export (800 MB and up) was rejected by a size ceiling. This reader
/// touches only the End Of Central Directory record, the central directory
/// itself, and — on request — the compressed bytes of one entry at a time.
/// Media entries are never read at all; the importer only ever decompresses
/// JSON, and each of those is bounded by the caller's per-file budget.
class ZipArchiveEntry {
  const ZipArchiveEntry({
    required this.name,
    required this.method,
    required this.flags,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localHeaderOffset,
    required this.externalAttributes,
  });

  final String name;

  /// 0 = stored, 8 = deflate. Anything else is refused rather than guessed.
  final int method;

  /// General-purpose bit flags. Bit 0 marks traditional PKWARE encryption.
  final int flags;

  final int compressedSize;
  final int uncompressedSize;
  final int localHeaderOffset;

  /// Unix mode lives in the high 16 bits when the archive was made on Unix.
  final int externalAttributes;

  bool get isDirectory => name.endsWith('/');

  bool get isEncrypted => (flags & 0x1) != 0;

  /// `S_IFLNK` — a stored symlink, which must never be treated as a file.
  bool get isSymbolicLink => ((externalAttributes >> 16) & 0xF000) == 0xA000;
}

class ZipFormatException implements Exception {
  const ZipFormatException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ZipFormatException($code): $message';
}

class ZipRandomAccessArchive {
  ZipRandomAccessArchive._(this._file, this._handle, this.entries);

  final File _file;
  final RandomAccessFile _handle;
  final List<ZipArchiveEntry> entries;

  // ponytail: the central directory is read whole. A 1M-entry archive needs
  // ~100 MB for it; stream it if anyone ships an archive that big.
  static const int _maxCentralDirectoryBytes = 128 * 1024 * 1024;

  static ZipRandomAccessArchive open(File file) {
    final length = file.lengthSync();
    if (length <= 0) {
      throw const ZipFormatException('archive_empty', 'The file is empty.');
    }
    final handle = file.openSync();
    try {
      final entries = _readCentralDirectory(handle, length);
      return ZipRandomAccessArchive._(file, handle, entries);
    } on Object {
      handle.closeSync();
      rethrow;
    }
  }

  /// Decompresses one entry, refusing to produce more than [maxBytes].
  Uint8List readEntry(ZipArchiveEntry entry, {required int maxBytes}) {
    if (entry.isEncrypted) {
      throw const ZipFormatException(
        'archive_encrypted',
        'The archive is password protected.',
      );
    }
    if (entry.uncompressedSize > maxBytes) {
      throw ZipFormatException(
        'json_file_size_limit',
        'An entry expands to ${entry.uncompressedSize} bytes, over the '
        '$maxBytes-byte read limit.',
      );
    }

    final compressed = _readRange(_dataOffset(entry), entry.compressedSize);

    final Uint8List decoded;
    switch (entry.method) {
      case 0:
        decoded = compressed;
      case 8:
        try {
          decoded = Uint8List.fromList(ZLibDecoder(raw: true).convert(compressed));
        } on Object {
          throw const ZipFormatException(
            'archive_corrupt',
            'An archive entry did not decompress.',
          );
        }
      default:
        // Only stored and deflate exist in a Facebook export; anything else
        // (deflate64, bzip2, zstd) is reported as an unsupported archive.
        throw ZipFormatException(
          'archive_invalid',
          'An entry uses unsupported compression method ${entry.method}.',
        );
    }

    if (decoded.length != entry.uncompressedSize) {
      throw const ZipFormatException(
        'archive_corrupt',
        'An archive entry did not match its declared size.',
      );
    }
    return decoded;
  }

  void close() => _handle.closeSync();

  /// Byte offset of an entry's payload: past the local header, its name and
  /// its extra field. The central directory is authoritative for the lengths,
  /// so a data-descriptor entry resolves the same way.
  int _dataOffset(ZipArchiveEntry entry) {
    final header = _readRange(entry.localHeaderOffset, 30);
    if (_u32(header, 0) != 0x04034b50) {
      throw const ZipFormatException(
        'archive_corrupt',
        'An entry header is missing.',
      );
    }
    final nameLength = _u16(header, 26);
    final extraLength = _u16(header, 28);
    return entry.localHeaderOffset + 30 + nameLength + extraLength;
  }

  Uint8List _readRange(int offset, int length) {
    if (length < 0) {
      throw const ZipFormatException('archive_corrupt', 'Negative entry size.');
    }
    if (length == 0) return Uint8List(0);
    _handle.setPositionSync(offset);
    final bytes = _handle.readSync(length);
    if (bytes.length != length) {
      throw const ZipFormatException(
        'archive_corrupt',
        'The archive ends before its declared data.',
      );
    }
    return bytes;
  }

  static List<ZipArchiveEntry> _readCentralDirectory(
    RandomAccessFile handle,
    int fileLength,
  ) {
    final tailLength = fileLength < 66560 ? fileLength : 66560;
    final tailStart = fileLength - tailLength;
    handle.setPositionSync(tailStart);
    final tail = handle.readSync(tailLength);

    var eocd = -1;
    for (var i = tail.length - 22; i >= 0; i--) {
      if (_u32(tail, i) == 0x06054b50) {
        eocd = i;
        break;
      }
    }
    if (eocd < 0) {
      throw const ZipFormatException(
        'archive_invalid',
        'The file is not a complete ZIP archive.',
      );
    }

    var entryCount = _u16(tail, eocd + 10);
    var directoryBytes = _u32(tail, eocd + 12);
    var directoryOffset = _u32(tail, eocd + 16);

    // ZIP64 moves the real numbers into a separate record that the locator
    // points at, immediately before the classic EOCD.
    final zip64 = _findZip64End(tail, eocd, tailStart);
    if (zip64 != null) {
      final record = _readAt(handle, zip64.$1, zip64.$2);
      entryCount = _u64(record, 32);
      directoryBytes = _u64(record, 40);
      directoryOffset = _u64(record, 48);
    }

    if (directoryBytes <= 0 || directoryBytes > _maxCentralDirectoryBytes) {
      throw const ZipFormatException(
        'archive_invalid',
        'The archive directory is empty or implausibly large.',
      );
    }
    if (directoryOffset < 0 ||
        directoryOffset + directoryBytes > fileLength) {
      throw const ZipFormatException(
        'archive_corrupt',
        'The archive directory points outside the file.',
      );
    }

    final directory = _readAt(handle, directoryOffset, directoryBytes);
    final entries = <ZipArchiveEntry>[];
    var offset = 0;
    for (var i = 0; i < entryCount; i++) {
      if (offset + 46 > directory.length || _u32(directory, offset) != 0x02014b50) {
        throw const ZipFormatException(
          'archive_corrupt',
          'The archive directory is truncated.',
        );
      }
      final flags = _u16(directory, offset + 8);
      final method = _u16(directory, offset + 10);
      var compressedSize = _u32(directory, offset + 20);
      var uncompressedSize = _u32(directory, offset + 24);
      final nameLength = _u16(directory, offset + 28);
      final extraLength = _u16(directory, offset + 30);
      final commentLength = _u16(directory, offset + 32);
      final externalAttributes = _u32(directory, offset + 38);
      var localHeaderOffset = _u32(directory, offset + 42);

      final nameStart = offset + 46;
      final nameEnd = nameStart + nameLength;
      final extraEnd = nameEnd + extraLength;
      final next = extraEnd + commentLength;
      if (next > directory.length) {
        throw const ZipFormatException(
          'archive_corrupt',
          'The archive directory is truncated.',
        );
      }
      final name = _decodeName(directory, nameStart, nameLength, flags);

      if (compressedSize == 0xFFFFFFFF ||
          uncompressedSize == 0xFFFFFFFF ||
          localHeaderOffset == 0xFFFFFFFF) {
        final zip64Extra = _findZip64Extra(directory, nameEnd, extraLength);
        if (zip64Extra == null) {
          throw const ZipFormatException(
            'archive_invalid',
            'A large entry is missing its ZIP64 record.',
          );
        }
        var cursor = zip64Extra.$1;
        final end = zip64Extra.$2;
        if (uncompressedSize == 0xFFFFFFFF && cursor + 8 <= end) {
          uncompressedSize = _u64(directory, cursor);
          cursor += 8;
        }
        if (compressedSize == 0xFFFFFFFF && cursor + 8 <= end) {
          compressedSize = _u64(directory, cursor);
          cursor += 8;
        }
        if (localHeaderOffset == 0xFFFFFFFF && cursor + 8 <= end) {
          localHeaderOffset = _u64(directory, cursor);
        }
      }

      entries.add(
        ZipArchiveEntry(
          name: name,
          method: method,
          flags: flags,
          compressedSize: compressedSize,
          uncompressedSize: uncompressedSize,
          localHeaderOffset: localHeaderOffset,
          externalAttributes: externalAttributes,
        ),
      );
      offset = next;
    }
    return entries;
  }

  /// `(offset, length)` of the ZIP64 end-of-central-directory record, or null.
  static (int, int)? _findZip64End(Uint8List tail, int eocd, int tailStart) {
    if (eocd < 20) return null;
    if (_u32(tail, eocd - 20) != 0x07064b50) return null;
    final recordOffset = _u64(tail, eocd - 20 + 8);
    if (recordOffset < 0 || recordOffset + 56 > tailStart + tail.length) {
      return null;
    }
    return (recordOffset, 56);
  }

  /// `(offset, end)` of the ZIP64 extended-information extra field, or null.
  static (int, int)? _findZip64Extra(
    Uint8List directory,
    int start,
    int length,
  ) {
    var offset = start;
    final end = start + length;
    while (offset + 4 <= end) {
      final id = _u16(directory, offset);
      final size = _u16(directory, offset + 2);
      final dataStart = offset + 4;
      final dataEnd = dataStart + size;
      if (dataEnd > end) return null;
      if (id == 0x0001) return (dataStart, dataEnd);
      offset = dataEnd;
    }
    return null;
  }

  static String _decodeName(
    Uint8List bytes,
    int start,
    int length,
    int flags,
  ) {
    final slice = Uint8List.sublistView(bytes, start, start + length);
    // Bit 11 declares UTF-8; otherwise the spec says CP437, but Facebook
    // exports are ASCII and CP437 is a superset for those bytes.
    if ((flags & 0x800) != 0) {
      return _latin1OrUtf8(slice, preferUtf8: true);
    }
    return _latin1OrUtf8(slice, preferUtf8: false);
  }

  static String _latin1OrUtf8(Uint8List bytes, {required bool preferUtf8}) {
    if (preferUtf8) {
      try {
        return const Utf8Decoder().convert(bytes);
      } on FormatException {
        // Fall through to the byte-preserving decode.
      }
    }
    return String.fromCharCodes(bytes);
  }

  static Uint8List _readAt(RandomAccessFile handle, int offset, int length) {
    handle.setPositionSync(offset);
    final bytes = handle.readSync(length);
    if (bytes.length != length) {
      throw const ZipFormatException(
        'archive_corrupt',
        'The archive ends before its declared data.',
      );
    }
    return bytes;
  }

  static int _u16(Uint8List bytes, int offset) =>
      ByteData.sublistView(bytes, offset, offset + 2).getUint16(0, Endian.little);

  static int _u32(Uint8List bytes, int offset) =>
      ByteData.sublistView(bytes, offset, offset + 4).getUint32(0, Endian.little);

  static int _u64(Uint8List bytes, int offset) =>
      ByteData.sublistView(bytes, offset, offset + 8).getUint64(0, Endian.little);
}

extension on ZipRandomAccessArchive {
  // Keeps the file reference meaningful for callers that log the source path.
  // ignore: unused_element
  String get path => _file.path;
}
