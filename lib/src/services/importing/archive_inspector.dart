import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/errors/import_report.dart';
import 'zip_random_access.dart';

/// Limits applied to an untrusted export archive before any import occurs.
///
/// This first implementation reads the compressed ZIP into memory (bounded by
/// [maxArchiveBytes]) and inspects it on a worker isolate. When JSON collection
/// is requested, selected JSON entries are also decompressed in memory within a
/// separate budget. Entry-expanded sizes are metadata, not verified extraction
/// sizes. No entries are extracted to disk.
/// A real Facebook export with media routinely carries tens of thousands of
/// entries (one per photo/video), so the entry ceilings are sized for a real
/// archive rather than the small fixture. [maxArchiveBytes] stays bounded
/// because the compressed ZIP is read into memory in one piece: an archive
/// bigger than that must be extracted first and imported by folder, which
/// streams file by file.
class ArchiveInspectionLimits {
  const ArchiveInspectionLimits({
    this.maxArchiveBytes = 600 * 1024 * 1024,
    this.maxEntries = 250_000,
    this.maxEntryBytes = 512 * 1024 * 1024,
    this.maxTotalExpandedBytes = 8 * 1024 * 1024 * 1024,
    this.maxPathLength = 1024,
  });

  final int maxArchiveBytes;
  final int maxEntries;
  final int maxEntryBytes;
  final int maxTotalExpandedBytes;
  final int maxPathLength;
}

class ArchiveInspection {
  const ArchiveInspection({
    required this.entries,
    required this.totalExpandedBytes,
    required this.jsonFiles,
    required this.mediaFiles,
    required this.ignoredFiles,
    required this.warnings,
  });

  final int entries;
  final int totalExpandedBytes;
  final int jsonFiles;
  final int mediaFiles;
  final int ignoredFiles;
  final List<String> warnings;

  bool get hasWarnings => warnings.isNotEmpty;
}

class ArchiveInspectionException implements CodedException {
  const ArchiveInspectionException(this.code, this.message);

  @override
  final String code;
  final String message;

  @override
  String toString() => 'ArchiveInspectionException($code): $message';
}

class InspectedJsonFile {
  const InspectedJsonFile({required this.path, required this.bytes});

  final String path;
  final Uint8List bytes;
}

/// Metadata of one entry that survived validation, kept for reporting.
///
/// It holds no content: the path is archive-relative and validation already
/// rejected absolute paths, traversal and links.
class InspectedArchiveEntry {
  const InspectedArchiveEntry({
    required this.relativePath,
    required this.size,
    required this.isDirectory,
    required this.isMedia,
  });

  final String relativePath;
  final int size;
  final bool isDirectory;
  final bool isMedia;
}

/// What the importer may know about one media entry: its byte length and,
/// when it was small enough to read inside the hashing budget, the SHA-256 of
/// its bytes. The bytes themselves are not retained or copied anywhere.
class ArchiveEntryDigest {
  const ArchiveEntryDigest({required this.sizeBytes, required this.sha256});

  final int sizeBytes;

  /// Hex SHA-256 of the entry bytes, or null when the entry exceeded the
  /// per-entry or total hashing budget.
  final String? sha256;
}

class ArchiveScan {
  const ArchiveScan({
    required this.inspection,
    required this.jsonFiles,
    this.entries = const [],
  });

  final ArchiveInspection inspection;
  final List<InspectedJsonFile> jsonFiles;

  /// Every validated non-directory entry, in archive order, for coverage
  /// reporting. Entries rejected during validation never appear here.
  final List<InspectedArchiveEntry> entries;
}

/// Reads metadata from a ZIP without extracting files or exposing their text.
class ArchiveInspector {
  const ArchiveInspector({this.limits = const ArchiveInspectionLimits()});

  final ArchiveInspectionLimits limits;

  /// Hashes the requested archive entries without extracting them.
  ///
  /// Only entries named in [entryPaths] are considered, and only after the
  /// same path validation an entry must pass. An entry larger than
  /// [maxEntryHashBytes], or one that would exceed [maxTotalHashBytes], is
  /// reported with its byte length and a null hash instead of being read, so
  /// an oversized media file never materializes in memory. Paths that are not
  /// present in the archive are absent from the result.
  Future<Map<String, ArchiveEntryDigest>> hashEntries(
    File file,
    Iterable<String> entryPaths, {
    int maxEntryHashBytes = 8 * 1024 * 1024,
    int maxTotalHashBytes = 64 * 1024 * 1024,
  }) {
    final paths = entryPaths.toSet();
    if (paths.isEmpty) return Future.value(const {});
    if (maxEntryHashBytes < 0 || maxTotalHashBytes < 0) {
      throw ArgumentError('Hash byte limits must not be negative.');
    }
    final inspectionLimits = limits;
    return Isolate.run(
      () => _hashEntries(
        file.path,
        paths,
        inspectionLimits,
        maxEntryHashBytes,
        maxTotalHashBytes,
      ),
    );
  }

  Future<ArchiveInspection> inspect(File file) {
    final inspectionLimits = limits;
    return _inBackground(
      () => _scanArchive(
        file.path,
        inspectionLimits,
        collectJson: false,
        maxJsonBytes: 0,
        maxJsonFileBytes: 0,
        jsonPathPattern: null,
      ).inspection,
    );
  }

  /// Inspects a ZIP that is already in memory (the browser picker's shape).
  Future<ArchiveInspection> inspectBytes(Uint8List bytes) {
    final inspectionLimits = limits;
    return _inBackground(
      () => _scanArchiveBytes(
        bytes,
        inspectionLimits,
        collectJson: false,
        maxJsonBytes: 0,
        maxJsonFileBytes: 0,
        jsonPathPattern: null,
      ).inspection,
    );
  }

  /// Reads JSON entries of an in-memory ZIP, with the same budgets as
  /// [scanJsonFiles].
  Future<ArchiveScan> scanJsonBytes(
    Uint8List bytes, {
    int maxJsonBytes = 64 * 1024 * 1024,
    int maxJsonFileBytes = 8 * 1024 * 1024,
    String? jsonPathPattern,
  }) {
    if (maxJsonBytes < 0 || maxJsonFileBytes < 0) {
      throw ArgumentError('JSON byte limits must not be negative.');
    }
    final inspectionLimits = limits;
    return _inBackground(
      () => _scanArchiveBytes(
        bytes,
        inspectionLimits,
        collectJson: true,
        maxJsonBytes: maxJsonBytes,
        maxJsonFileBytes: maxJsonFileBytes,
        jsonPathPattern: jsonPathPattern,
      ),
    );
  }

  /// Reads JSON entries after validating the archive, with a separate aggregate
  /// payload budget so callers never need to extract the archive to disk.
  Future<ArchiveScan> scanJsonFiles(
    File file, {
    int maxJsonBytes = 64 * 1024 * 1024,
    int maxJsonFileBytes = 8 * 1024 * 1024,
    String? jsonPathPattern,
  }) {
    if (maxJsonBytes < 0 || maxJsonFileBytes < 0) {
      throw ArgumentError('JSON byte limits must not be negative.');
    }
    final inspectionLimits = limits;
    return _inBackground(
      () => _scanArchive(
        file.path,
        inspectionLimits,
        collectJson: true,
        maxJsonBytes: maxJsonBytes,
        maxJsonFileBytes: maxJsonFileBytes,
        jsonPathPattern: jsonPathPattern,
      ),
    );
  }
}

/// Runs CPU work off the UI thread where the platform allows it.
///
/// `Isolate.run` is unsupported in the browser build, and the work there is
/// already bounded by the same limits, so it runs inline instead of failing.
Future<T> _inBackground<T>(T Function() work) =>
    kIsWeb ? Future<T>.value(work()) : Isolate.run(work);

/// Scans a ZIP on disk without loading it.
///
/// The whole-file read that produced the old `archive_size_limit` refusal is
/// gone: a real export (800 MB and up) is read through the central directory,
/// and only the JSON entries the importer needs are ever decompressed. The
/// in-memory ceilings stay in [_scanArchiveBytes] for the browser picker, which
/// has no file to seek in.
ArchiveScan _scanArchive(
  String filePath,
  ArchiveInspectionLimits limits, {
  required bool collectJson,
  required int maxJsonBytes,
  required int maxJsonFileBytes,
  required String? jsonPathPattern,
}) {
  final RegExp? jsonPathMatcher;
  try {
    jsonPathMatcher = jsonPathPattern == null
        ? null
        : RegExp(jsonPathPattern, caseSensitive: false);
  } on FormatException {
    throw const ArchiveInspectionException(
      'invalid_json_path_filter',
      'The requested supported-file filter is invalid.',
    );
  }

  final ZipRandomAccessArchive archive;
  try {
    archive = ZipRandomAccessArchive.open(File(filePath));
  } on ZipFormatException catch (error) {
    throw ArchiveInspectionException(error.code, error.message);
  } on FileSystemException {
    throw const ArchiveInspectionException(
      'archive_unreadable',
      'The selected archive could not be opened.',
    );
  }

  try {
    if (archive.entries.length > limits.maxEntries) {
      throw const ArchiveInspectionException(
        'entry_count_limit',
        'The archive contains more entries than the configured limit.',
      );
    }

    final inspectedEntries = <InspectedArchiveEntry>[];
    final jsonFiles = <InspectedJsonFile>[];
    final seenNames = <String>{};
    final warnings = <String>[];
    var expanded = 0;
    var jsonFileCount = 0;
    var mediaFiles = 0;
    var ignoredFiles = 0;
    var collectedJsonBytes = 0;

    for (final entry in archive.entries) {
      if (entry.isSymbolicLink) {
        throw const ArchiveInspectionException(
          'symbolic_link_rejected',
          'Archives containing symbolic links are not supported.',
        );
      }
      final normalized = _validateName(entry.name, limits);
      if (entry.isDirectory) continue;
      if (!seenNames.add(normalized.toLowerCase())) {
        throw const ArchiveInspectionException(
          'duplicate_entry',
          'The archive contains duplicate or ambiguous file paths.',
        );
      }
      if (entry.isEncrypted) {
        throw const ArchiveInspectionException(
          'archive_encrypted',
          'The archive is password protected.',
        );
      }

      final size = entry.uncompressedSize;
      if (size < 0 || size > limits.maxEntryBytes) {
        throw const ArchiveInspectionException(
          'entry_size_limit',
          'An archive entry exceeds the configured per-file size limit.',
        );
      }
      expanded += size;
      if (expanded > limits.maxTotalExpandedBytes) {
        throw const ArchiveInspectionException(
          'expanded_size_limit',
          'The archive exceeds the configured total expanded-size limit.',
        );
      }

      final lower = normalized.toLowerCase();
      inspectedEntries.add(
        InspectedArchiveEntry(
          relativePath: normalized,
          size: size,
          isDirectory: false,
          isMedia: _isMedia(lower),
        ),
      );

      // A custom path pattern widens which entries are payloads (WhatsApp
      // chats are .txt); the default stays .json for Facebook.
      final isPayload = jsonPathMatcher != null
          ? jsonPathMatcher.hasMatch(normalized)
          : lower.endsWith('.json');
      if (isPayload) {
        jsonFileCount++;
        if (collectJson) {
          if (size > maxJsonFileBytes) {
            throw const ArchiveInspectionException(
              'json_file_size_limit',
              'A supported JSON file exceeds the configured per-file read limit.',
            );
          }
          if (size > maxJsonBytes || collectedJsonBytes + size > maxJsonBytes) {
            throw const ArchiveInspectionException(
              'json_payload_size_limit',
              'Supported JSON files exceed the configured import-read limit.',
            );
          }
          final Uint8List bytes;
          try {
            bytes = archive.readEntry(entry, maxBytes: maxJsonFileBytes);
          } on ZipFormatException catch (error) {
            throw ArchiveInspectionException(error.code, error.message);
          }
          collectedJsonBytes += bytes.length;
          jsonFiles.add(InspectedJsonFile(path: normalized, bytes: bytes));
        }
      } else if (_isMedia(lower)) {
        mediaFiles++;
      } else {
        ignoredFiles++;
      }
    }

    if (jsonFileCount == 0) warnings.add('no_json_files');
    if (ignoredFiles > 0) warnings.add('unsupported_files_present');

    return ArchiveScan(
      inspection: ArchiveInspection(
        entries: archive.entries.length,
        totalExpandedBytes: expanded,
        jsonFiles: jsonFileCount,
        mediaFiles: mediaFiles,
        ignoredFiles: ignoredFiles,
        warnings: List.unmodifiable(warnings),
      ),
      jsonFiles: List.unmodifiable(jsonFiles),
      entries: List.unmodifiable(inspectedEntries),
    );
  } finally {
    archive.close();
  }
}

/// Scans an archive that is already in memory.
///
/// The browser build has no file system, so the picker hands over bytes; the
/// native path reads the file and lands here too, keeping one validator.
ArchiveScan _scanArchiveBytes(
  Uint8List archiveBytes,
  ArchiveInspectionLimits limits, {
  required bool collectJson,
  required int maxJsonBytes,
  required int maxJsonFileBytes,
  required String? jsonPathPattern,
}) {
  final compressedLength = archiveBytes.length;
  if (compressedLength <= 0) {
    throw const ArchiveInspectionException(
      'archive_empty',
      'The selected file is empty.',
    );
  }
  if (compressedLength > limits.maxArchiveBytes) {
    throw ArchiveInspectionException(
      'archive_size_limit',
      'The archive is $compressedLength bytes, over the configured '
      '${limits.maxArchiveBytes}-byte compressed-size limit.',
    );
  }

  // The archive package decodes some non-ZIP inputs into an empty archive
  // instead of throwing, so confirm the End Of Central Directory record that
  // every intact ZIP must contain before trusting a successful decode.
  if (!_hasZipEndOfCentralDirectory(archiveBytes)) {
    throw const ArchiveInspectionException(
      'archive_invalid',
      'The selected file is not a supported, intact ZIP archive.',
    );
  }

  late final Archive archive;
  ArchiveInspectionException? callbackError;
  final seenNames = <String>{};
  var callbackEntries = 0;
  try {
    // The archive package wraps callback exceptions. Capture safe validation
    // failures and rethrow them after decoding so callers retain the error code.
    archive = ZipDecoder().decodeBytes(
      archiveBytes,
      callback: (entry) {
        if (callbackError != null) return;
        try {
          callbackEntries++;
          if (callbackEntries > limits.maxEntries) {
            throw const ArchiveInspectionException(
              'entry_count_limit',
              'The archive contains more entries than the configured limit.',
            );
          }
          if (entry.isSymbolicLink) {
            throw const ArchiveInspectionException(
              'symbolic_link_rejected',
              'Archives containing symbolic links are not supported.',
            );
          }
          if (entry.size < 0 || entry.size > limits.maxEntryBytes) {
            throw const ArchiveInspectionException(
              'entry_size_limit',
              'An archive entry exceeds the configured per-file size limit.',
            );
          }
          final normalized = _validateEntry(entry, limits);
          if (!seenNames.add(normalized.toLowerCase())) {
            throw const ArchiveInspectionException(
              'duplicate_entry',
              'The archive contains duplicate or ambiguous file paths.',
            );
          }
        } on ArchiveInspectionException catch (error) {
          callbackError = error;
        }
      },
    );
  } on Object {
    if (callbackError != null) throw callbackError!;
    throw const ArchiveInspectionException(
      'archive_invalid',
      'The selected file is not a supported, intact ZIP archive.',
    );
  }
  if (callbackError != null) throw callbackError!;

  if (archive.length > limits.maxEntries) {
    throw const ArchiveInspectionException(
      'entry_count_limit',
      'The archive contains more entries than the configured limit.',
    );
  }

  final inspectedEntries = <InspectedArchiveEntry>[];
  var expanded = 0;
  var jsonFileCount = 0;
  var mediaFiles = 0;
  var ignoredFiles = 0;
  final jsonFiles = <InspectedJsonFile>[];
  late final RegExp? jsonPathMatcher;
  try {
    jsonPathMatcher = jsonPathPattern == null
        ? null
        : RegExp(jsonPathPattern, caseSensitive: false);
  } on FormatException {
    throw const ArchiveInspectionException(
      'invalid_json_path_filter',
      'The requested supported-file filter is invalid.',
    );
  }
  var collectedJsonBytes = 0;
  final warnings = <String>[];

  for (final entry in archive) {
    final normalized = _validateEntry(entry, limits);
    if (entry.isSymbolicLink) {
      throw const ArchiveInspectionException(
        'symbolic_link_rejected',
        'Archives containing symbolic links are not supported.',
      );
    }
    if (entry.isDirectory) continue;
    inspectedEntries.add(
      InspectedArchiveEntry(
        relativePath: normalized,
        size: entry.size,
        isDirectory: false,
        isMedia: _isMedia(normalized.toLowerCase()),
      ),
    );

    final size = entry.size;
    if (size < 0 || size > limits.maxEntryBytes) {
      throw const ArchiveInspectionException(
        'entry_size_limit',
        'An archive entry exceeds the configured per-file size limit.',
      );
    }
    expanded += size;
    if (expanded > limits.maxTotalExpandedBytes) {
      throw const ArchiveInspectionException(
        'expanded_size_limit',
        'The archive exceeds the configured total expanded-size limit.',
      );
    }

    final lower = normalized.toLowerCase();
    // A custom path pattern widens which entries are payloads (WhatsApp chats
    // are .txt); the default stays .json for Facebook.
    final isPayload = jsonPathMatcher != null
        ? jsonPathMatcher.hasMatch(normalized)
        : lower.endsWith('.json');
    if (isPayload) {
      jsonFileCount++;
      if (collectJson) {
        if (size > maxJsonFileBytes) {
          throw const ArchiveInspectionException(
            'json_file_size_limit',
            'A supported JSON file exceeds the configured per-file read limit.',
          );
        }
        if (size > maxJsonBytes || collectedJsonBytes + size > maxJsonBytes) {
          throw const ArchiveInspectionException(
            'json_payload_size_limit',
            'Supported JSON files exceed the configured import-read limit.',
          );
        }
        final bytes = entry.readBytes();
        if (bytes == null || bytes.length != size) {
          throw const ArchiveInspectionException(
            'archive_corrupt',
            'An archive entry did not match its declared size.',
          );
        }
        collectedJsonBytes += bytes.length;
        jsonFiles.add(InspectedJsonFile(path: normalized, bytes: bytes));
      }
    } else if (_isMedia(normalized.toLowerCase())) {
      mediaFiles++;
    } else {
      ignoredFiles++;
    }
  }

  if (jsonFileCount == 0) {
    warnings.add('no_json_files');
  }
  if (ignoredFiles > 0) {
    warnings.add('unsupported_files_present');
  }

  return ArchiveScan(
    inspection: ArchiveInspection(
      entries: archive.length,
      totalExpandedBytes: expanded,
      jsonFiles: jsonFileCount,
      mediaFiles: mediaFiles,
      ignoredFiles: ignoredFiles,
      warnings: List.unmodifiable(warnings),
    ),
    jsonFiles: List.unmodifiable(jsonFiles),
    entries: List.unmodifiable(inspectedEntries),
  );
}

/// A ZIP ends with an End Of Central Directory record, optionally followed by
/// a comment of at most 65535 bytes. The record's absence means the bytes are
/// not a complete ZIP even when a lenient decoder yields an empty archive.
bool _hasZipEndOfCentralDirectory(List<int> bytes) {
  const recordSize = 22;
  const maxComment = 0xffff;
  final earliest = bytes.length - recordSize - maxComment;
  final start = earliest < 0 ? 0 : earliest;
  for (var i = bytes.length - recordSize; i >= start; i--) {
    if (bytes[i] == 0x50 &&
        bytes[i + 1] == 0x4b &&
        bytes[i + 2] == 0x05 &&
        bytes[i + 3] == 0x06) {
      return true;
    }
  }
  return false;
}

String _validateEntry(ArchiveFile entry, ArchiveInspectionLimits limits) =>
    _validateName(entry.name, limits);

String _validateName(String original, ArchiveInspectionLimits limits) {
  final rejection = _pathRejection(original, limits.maxPathLength);
  if (rejection != null) {
    throw ArchiveInspectionException(rejection, _rejectionMessage(rejection));
  }

  // Case-fold paths for duplicate detection. Unicode normalization is a
  // separate importer concern and is not claimed here. Whitespace around a
  // path segment is normalized to prevent equivalent-looking source paths.
  return _normalizePath(original);
}

/// Normalizes a path quoted by export content for archive lookup, or returns
/// null when that path would escape the archive.
///
/// It applies the same guard archive entries pass, so a media reference in a
/// JSON file can never name a location outside the archive.
String? normalizeArchiveRelativePath(String path, {int maxPathLength = 1024}) {
  if (_pathRejection(path, maxPathLength) != null) return null;
  return _normalizePath(path);
}

String _normalizePath(String path) => path
    .replaceAll(String.fromCharCode(92), '/')
    .split('/')
    .map((segment) => segment.trim())
    .join('/');

/// The safe code for why [path] is unusable inside an archive, or null when it
/// is safe. Only the code is ever surfaced: never the path itself.
String? _pathRejection(String path, int maxPathLength) {
  if (path.isEmpty || path.length > maxPathLength) {
    return 'invalid_entry_path';
  }
  if (path.contains(String.fromCharCode(0))) {
    return 'invalid_entry_path';
  }

  final normalized = path.replaceAll(String.fromCharCode(92), '/');
  if (normalized.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(normalized)) {
    return 'absolute_entry_path';
  }

  final segments = normalized.split('/');
  if (segments.any((segment) => segment == '..' || segment == '.')) {
    return 'path_traversal';
  }
  if (segments.asMap().entries.any(
    (item) => item.value.isEmpty && item.key != segments.length - 1,
  )) {
    return 'invalid_entry_path';
  }
  return null;
}

String _rejectionMessage(String code) => switch (code) {
  'absolute_entry_path' => 'The archive contains an absolute file path.',
  'path_traversal' => 'The archive contains a path traversal entry.',
  _ => 'The archive contains an invalid entry path.',
};

/// Hashes the requested entries in memory. Entries over a budget are reported
/// with their declared size and no hash, without being decompressed.
Map<String, ArchiveEntryDigest> _hashEntries(
  String filePath,
  Set<String> entryPaths,
  ArchiveInspectionLimits limits,
  int maxEntryHashBytes,
  int maxTotalHashBytes,
) {
  final ZipRandomAccessArchive archive;
  try {
    archive = ZipRandomAccessArchive.open(File(filePath));
  } on ZipFormatException catch (error) {
    throw ArchiveInspectionException(error.code, error.message);
  }

  try {
    final digests = <String, ArchiveEntryDigest>{};
    var hashedBytes = 0;
    for (final entry in archive.entries) {
      if (entry.isDirectory || entry.isSymbolicLink || entry.isEncrypted) {
        continue;
      }
      final rejection = _pathRejection(entry.name, limits.maxPathLength);
      if (rejection != null) continue;
      final normalized = _normalizePath(entry.name);
      if (!entryPaths.contains(normalized)) continue;

      final size = entry.uncompressedSize;
      if (size < 0 ||
          size > maxEntryHashBytes ||
          hashedBytes + size > maxTotalHashBytes) {
        digests[normalized] = ArchiveEntryDigest(sizeBytes: size, sha256: null);
        continue;
      }

      final Uint8List content;
      try {
        content = archive.readEntry(entry, maxBytes: maxEntryHashBytes);
      } on ZipFormatException catch (error) {
        throw ArchiveInspectionException(error.code, error.message);
      }
      hashedBytes += content.length;
      digests[normalized] = ArchiveEntryDigest(
        sizeBytes: content.length,
        sha256: sha256.convert(content).toString(),
      );
    }
    return digests;
  } finally {
    archive.close();
  }
}

bool _isMedia(String path) {
  const extensions = <String>{
    '.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.avif',
    '.mp4', '.mov', '.m4v', '.webm', '.avi', '.mp3', '.m4a', '.wav',
    '.ogg', '.opus', '.aac',
  };
  final dot = path.lastIndexOf('.');
  if (dot < 0) return false;
  return extensions.contains(path.substring(dot));
}

/// Reads an export the user already extracted to a folder.
///
/// The folder is untrusted for exactly the same reasons an archive is, so it
/// passes the same checks: no symbolic links, no paths escaping the root, the
/// same entry, path-length and size limits, and no duplicate paths. Results use
/// the archive types (`ArchiveInspection`, `ArchiveScan`, `InspectedJsonFile`)
/// so nothing downstream needs to know which kind of source it received.
///
/// Reading a folder never loads the whole export into memory: each JSON file is
/// read on its own, against the same per-file and total budgets.
class FolderInspector {
  const FolderInspector({this.limits = const ArchiveInspectionLimits()});

  final ArchiveInspectionLimits limits;

  Future<ArchiveInspection> inspect(Directory folder) {
    final inspectionLimits = limits;
    return Isolate.run(
      () => _scanFolder(
        folder.path,
        inspectionLimits,
        collectJson: false,
        maxJsonBytes: 0,
        maxJsonFileBytes: 0,
        jsonPathPattern: null,
      ).inspection,
    );
  }

  Future<ArchiveScan> scanJsonFiles(
    Directory folder, {
    int maxJsonBytes = 64 * 1024 * 1024,
    int maxJsonFileBytes = 8 * 1024 * 1024,
    String? jsonPathPattern,
  }) {
    if (maxJsonBytes < 0 || maxJsonFileBytes < 0) {
      throw ArgumentError('JSON byte limits must not be negative.');
    }
    final inspectionLimits = limits;
    return Isolate.run(
      () => _scanFolder(
        folder.path,
        inspectionLimits,
        collectJson: true,
        maxJsonBytes: maxJsonBytes,
        maxJsonFileBytes: maxJsonFileBytes,
        jsonPathPattern: jsonPathPattern,
      ),
    );
  }

  Future<Map<String, ArchiveEntryDigest>> hashEntries(
    Directory folder,
    Iterable<String> entryPaths, {
    int maxEntryHashBytes = 8 * 1024 * 1024,
    int maxTotalHashBytes = 64 * 1024 * 1024,
  }) {
    final paths = entryPaths.toSet();
    if (paths.isEmpty) return Future.value(const {});
    if (maxEntryHashBytes < 0 || maxTotalHashBytes < 0) {
      throw ArgumentError('Hash byte limits must not be negative.');
    }
    final inspectionLimits = limits;
    return Isolate.run(
      () => _hashFolderEntries(
        folder.path,
        paths,
        inspectionLimits,
        maxEntryHashBytes,
        maxTotalHashBytes,
      ),
    );
  }
}

/// Walks [rootPath] down to its files, refusing anything unsafe on the way.
///
/// The walk is incremental rather than one recursive listing, and every
/// directory and file counts toward [ArchiveInspectionLimits.maxEntries], so an
/// enormous folder is rejected after a bounded amount of work instead of being
/// materialised first. Links are refused rather than followed, so a folder can
/// never point the scanner at content outside the export the user chose.
List<File> _walkFolder(String rootPath, ArchiveInspectionLimits limits) {
  final pending = <Directory>[Directory(rootPath)];
  final files = <File>[];
  var seen = 0;
  while (pending.isNotEmpty) {
    final directory = pending.removeLast();
    final List<FileSystemEntity> children;
    try {
      children = directory.listSync(followLinks: false);
    } on FileSystemException {
      throw const ArchiveInspectionException(
        'folder_unreadable',
        'The selected folder could not be read.',
      );
    }
    for (final child in children) {
      if (child is Link) {
        throw const ArchiveInspectionException(
          'symbolic_link_rejected',
          'Folders containing symbolic links are not supported.',
        );
      }
      seen++;
      if (seen > limits.maxEntries) {
        throw const ArchiveInspectionException(
          'entry_count_limit',
          'The folder contains more entries than the configured limit.',
        );
      }
      if (child is Directory) {
        pending.add(child);
      } else if (child is File) {
        files.add(child);
      }
    }
  }
  return files;
}

String _relativeFolderPath(String rootPath, String entityPath) {
  final root = rootPath.endsWith(Platform.pathSeparator)
      ? rootPath
      : '$rootPath${Platform.pathSeparator}';
  final relative = entityPath.startsWith(root)
      ? entityPath.substring(root.length)
      : entityPath;
  return relative.replaceAll(Platform.pathSeparator, '/');
}

ArchiveScan _scanFolder(
  String rootPath,
  ArchiveInspectionLimits limits, {
  required bool collectJson,
  required int maxJsonBytes,
  required int maxJsonFileBytes,
  required String? jsonPathPattern,
}) {
  final files = _walkFolder(rootPath, limits)
    ..sort((a, b) => _relativeFolderPath(rootPath, a.path)
        .compareTo(_relativeFolderPath(rootPath, b.path)));

  late final RegExp? jsonPathMatcher;
  try {
    jsonPathMatcher = jsonPathPattern == null
        ? null
        : RegExp(jsonPathPattern, caseSensitive: false);
  } on FormatException {
    throw const ArchiveInspectionException(
      'invalid_json_path_filter',
      'The requested supported-file filter is invalid.',
    );
  }

  final inspectedEntries = <InspectedArchiveEntry>[];
  final jsonFiles = <InspectedJsonFile>[];
  final seenNames = <String>{};
  final warnings = <String>[];
  var entryCount = 0;
  var expanded = 0;
  var jsonFileCount = 0;
  var mediaFiles = 0;
  var ignoredFiles = 0;
  var collectedJsonBytes = 0;

  for (final file in files) {
    final original = _relativeFolderPath(rootPath, file.path);
    final rejection = _pathRejection(original, limits.maxPathLength);
    if (rejection != null) {
      throw ArchiveInspectionException(rejection, _rejectionMessage(rejection));
    }
    final normalized = _normalizePath(original);
    if (!seenNames.add(normalized.toLowerCase())) {
      throw const ArchiveInspectionException(
        'duplicate_entry',
        'The folder contains duplicate or ambiguous file paths.',
      );
    }

    entryCount++;

    final int size;
    try {
      size = file.lengthSync();
    } on FileSystemException {
      throw const ArchiveInspectionException(
        'folder_unreadable',
        'A file in the selected folder could not be read.',
      );
    }
    // A folder is not a compressed container: nothing is decompressed, and each
    // file is streamed on its own, so the archive's expanded-size and per-file
    // ceilings do not apply here. Enforcing them rejected real exports that the
    // user had already unpacked - e.g. a folder holding large videos - with an
    // error that only made sense for a ZIP bomb.
    if (size < 0) {
      throw const ArchiveInspectionException(
        'folder_unreadable',
        'A file in the selected folder could not be read.',
      );
    }
    // Counted for the report only; no ceiling is enforced here (see above).
    expanded += size;

    final lower = normalized.toLowerCase();
    inspectedEntries.add(
      InspectedArchiveEntry(
        relativePath: normalized,
        size: size,
        isDirectory: false,
        isMedia: _isMedia(lower),
      ),
    );

    if (lower.endsWith('.json')) {
      jsonFileCount++;
      if (collectJson &&
          (jsonPathMatcher == null || jsonPathMatcher.hasMatch(normalized))) {
        if (size > maxJsonFileBytes) {
          throw const ArchiveInspectionException(
            'json_file_size_limit',
            'A supported JSON file exceeds the configured per-file read limit.',
          );
        }
        if (size > maxJsonBytes || collectedJsonBytes + size > maxJsonBytes) {
          throw const ArchiveInspectionException(
            'json_payload_size_limit',
            'Supported JSON files exceed the configured import-read limit.',
          );
        }
        final bytes = file.readAsBytesSync();
        if (bytes.length != size) {
          throw const ArchiveInspectionException(
            'archive_corrupt',
            'A file in the folder changed while it was being read.',
          );
        }
        collectedJsonBytes += bytes.length;
        jsonFiles.add(InspectedJsonFile(path: normalized, bytes: bytes));
      }
    } else if (_isMedia(lower)) {
      mediaFiles++;
    } else {
      ignoredFiles++;
    }
  }

  if (jsonFileCount == 0) warnings.add('no_json_files');
  if (ignoredFiles > 0) warnings.add('unsupported_files_present');

  return ArchiveScan(
    inspection: ArchiveInspection(
      entries: entryCount,
      totalExpandedBytes: expanded,
      jsonFiles: jsonFileCount,
      mediaFiles: mediaFiles,
      ignoredFiles: ignoredFiles,
      warnings: List.unmodifiable(warnings),
    ),
    jsonFiles: List.unmodifiable(jsonFiles),
    entries: List.unmodifiable(inspectedEntries),
  );
}

Map<String, ArchiveEntryDigest> _hashFolderEntries(
  String rootPath,
  Set<String> entryPaths,
  ArchiveInspectionLimits limits,
  int maxEntryHashBytes,
  int maxTotalHashBytes,
) {
  final digests = <String, ArchiveEntryDigest>{};
  var hashedBytes = 0;
  for (final entity in _walkFolder(rootPath, limits)) {
    final original = _relativeFolderPath(rootPath, entity.path);
    if (_pathRejection(original, limits.maxPathLength) != null) continue;
    final normalized = _normalizePath(original);
    if (!entryPaths.contains(normalized)) continue;

    final int size;
    try {
      size = entity.lengthSync();
    } on FileSystemException {
      continue;
    }
    if (size < 0 || size > maxEntryHashBytes || hashedBytes + size > maxTotalHashBytes) {
      digests[normalized] = ArchiveEntryDigest(sizeBytes: size, sha256: null);
      continue;
    }
    final bytes = entity.readAsBytesSync();
    if (bytes.length != size) {
      throw const ArchiveInspectionException(
        'archive_corrupt',
        'A file in the folder changed while it was being read.',
      );
    }
    hashedBytes += bytes.length;
    digests[normalized] = ArchiveEntryDigest(
      sizeBytes: bytes.length,
      sha256: sha256.convert(bytes).toString(),
    );
  }
  return digests;
}

/// One untrusted export on disk: a ZIP archive, or a folder the user already
/// extracted. Callers hand it a path and never branch on which kind it is.
class ExportInspector {
  const ExportInspector({this.limits = const ArchiveInspectionLimits()});

  final ArchiveInspectionLimits limits;

  /// A folder is the primary source: the export is already on disk and the app
  /// never has to hold a multi-hundred-megabyte archive in memory.
  static bool isFolder(String path) => FileSystemEntity.isDirectorySync(path);

  Future<ArchiveInspection> inspect(String path) => isFolder(path)
      ? FolderInspector(limits: limits).inspect(Directory(path))
      : ArchiveInspector(limits: limits).inspect(File(path));

  /// An in-memory ZIP is always an archive, never a folder, so it goes straight
  /// to the archive validator.
  Future<ArchiveInspection> inspectBytes(Uint8List bytes) =>
      ArchiveInspector(limits: limits).inspectBytes(bytes);

  Future<ArchiveScan> scanJsonBytes(
    Uint8List bytes, {
    int maxJsonBytes = 64 * 1024 * 1024,
    int maxJsonFileBytes = 8 * 1024 * 1024,
    String? jsonPathPattern,
  }) => ArchiveInspector(limits: limits).scanJsonBytes(
    bytes,
    maxJsonBytes: maxJsonBytes,
    maxJsonFileBytes: maxJsonFileBytes,
    jsonPathPattern: jsonPathPattern,
  );

  Future<ArchiveScan> scanJsonFiles(
    String path, {
    int maxJsonBytes = 64 * 1024 * 1024,
    int maxJsonFileBytes = 8 * 1024 * 1024,
    String? jsonPathPattern,
  }) => isFolder(path)
      ? FolderInspector(limits: limits).scanJsonFiles(
          Directory(path),
          maxJsonBytes: maxJsonBytes,
          maxJsonFileBytes: maxJsonFileBytes,
          jsonPathPattern: jsonPathPattern,
        )
      : ArchiveInspector(limits: limits).scanJsonFiles(
          File(path),
          maxJsonBytes: maxJsonBytes,
          maxJsonFileBytes: maxJsonFileBytes,
          jsonPathPattern: jsonPathPattern,
        );

  Future<Map<String, ArchiveEntryDigest>> hashEntries(
    String path,
    Iterable<String> entryPaths, {
    int maxEntryHashBytes = 8 * 1024 * 1024,
    int maxTotalHashBytes = 64 * 1024 * 1024,
  }) => isFolder(path)
      ? FolderInspector(limits: limits).hashEntries(
          Directory(path),
          entryPaths,
          maxEntryHashBytes: maxEntryHashBytes,
          maxTotalHashBytes: maxTotalHashBytes,
        )
      : ArchiveInspector(limits: limits).hashEntries(
          File(path),
          entryPaths,
          maxEntryHashBytes: maxEntryHashBytes,
          maxTotalHashBytes: maxTotalHashBytes,
        );
}


/// One line per file of [rootPath]: relative path, byte length, content digest.
///
/// This is what an import fingerprint is built from, so it hashes content and
/// not just sizes - a same-size edit must not look like an unchanged export.
/// Each file is read in fixed-size chunks, so a multi-gigabyte export never
/// lands in memory, and the walk stops at [ArchiveInspectionLimits.maxEntries].
List<String> folderFingerprintEntries(
  String rootPath,
  ArchiveInspectionLimits limits,
) {
  final files = _walkFolder(rootPath, limits)
    ..sort((a, b) => _relativeFolderPath(rootPath, a.path)
        .compareTo(_relativeFolderPath(rootPath, b.path)));
  return [
    for (final file in files)
      '${_relativeFolderPath(rootPath, file.path)}:${file.lengthSync()}'
          ':${_fileDigest(file)}',
  ];
}

/// SHA-256 of one file, read in 1 MiB chunks so memory stays bounded.
String _fileDigest(File file) {
  final output = _DigestSink();
  final input = sha256.startChunkedConversion(output);
  final handle = file.openSync();
  try {
    final buffer = Uint8List(1024 * 1024);
    while (true) {
      final read = handle.readIntoSync(buffer);
      if (read == 0) break;
      input.add(Uint8List.sublistView(buffer, 0, read));
    }
  } on FileSystemException {
    throw const ArchiveInspectionException(
      'folder_unreadable',
      'A file in the selected folder could not be read.',
    );
  } finally {
    handle.closeSync();
  }
  input.close();
  return output.value.toString();
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
