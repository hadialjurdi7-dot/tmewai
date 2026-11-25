import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/errors/import_report.dart';
import '../../core/l10n/import_categories.dart';
import '../../core/l10n/import_labels.dart';
import '../../domain/models/event_record.dart';
import 'archive_inspector.dart';
import 'import_coverage_report.dart';
import 'import_text_repair.dart';
import 'instagram_dm_importer.dart';

/// One normalized record read from a supported Facebook file.
///
/// Messages, comments, reactions and posts share this shape; [eventType] says
/// which one it is, so nothing downstream has to know where a record came
/// from.
class FacebookRecord {
  const FacebookRecord({
    required this.eventType,
    required this.sourcePath,
    required this.sourceLocator,
    required this.senderName,
    required this.text,
    required this.timestampRaw,
    required this.timestampUtc,
    this.timezoneStatus,
    this.conversationKey,
    this.conversationTitle,
    this.metadata,
  });

  /// `message`, `comment`, `reaction`, `post`, or a typed message payload such
  /// as `message_photo` / `message_link`. See [isMessageEventType].
  final String eventType;

  final String sourcePath;
  final String sourceLocator;

  /// The conversation this record belongs to. Null for records that are not
  /// part of a conversation, such as comments.
  final String? conversationKey;

  final String? conversationTitle;
  final String? senderName;
  final String? text;

  /// The timestamp exactly as exported, unparsed. Messages export Unix
  /// milliseconds in `timestamp_ms`; comments and reactions export Unix
  /// seconds in `timestamp`. No unit conversion is claimed beyond what is
  /// documented.
  final String? timestampRaw;

  final DateTime? timestampUtc;

  /// Overrides the UTC inference in the writer for exports whose wall-clock
  /// time is known to be local rather than UTC. Null keeps the default.
  final TimezoneStatus? timezoneStatus;

  /// Allowlisted metadata, already bounded by the importer: the `reaction`
  /// token, a post's attachment count and media type names, or a call's
  /// duration. Never the raw record and never media bytes.
  final Map<String, String>? metadata;

  /// The label of a record whose own text is empty, in [isRtl]'s language.
  ///
  /// Null for a text record: its text is the label then. A call includes the
  /// duration the export states, so "مكالمة — 42 ثانية" is evidence, not a
  /// decoration.
  String? payloadLabel({required bool isRtl}) => importEventLabel(
    eventType,
    isRtl: isRtl,
    callSeconds: int.tryParse(metadata?[callDurationMetadataKey] ?? ''),
  );
}

/// How one examined archive file was handled.
enum FacebookPreviewFileStatus {
  /// Read and parsed; its records are in [FacebookImportPreview.records].
  parsed,

  /// Matched the supported file shape but could not be used; the preview
  /// carries a safe [FacebookPreviewFile.errorCode] instead of the content.
  unsupported,

  /// Sits under a documented Facebook export root this importer does not model
  /// yet. It is not an unknown file: the report can name its category and say
  /// it was left for later.
  knownNotImported,
}

/// One archive entry the importer examined, for the coverage report.
class FacebookPreviewFile {
  const FacebookPreviewFile({
    required this.path,
    required this.status,
    this.errorCode,
    this.recordsParsed = 0,
    this.recordsSkipped = 0,
  });

  final String path;
  final FacebookPreviewFileStatus status;
  final String? errorCode;

  /// Records this file contributed, and records it refused.
  final int recordsParsed;
  final int recordsSkipped;
}

/// One media reference read from an export entry and resolved against the
/// archive.
///
/// Only metadata is kept: the archive-relative path, the media type, the
/// entry's byte length when it exists and, unless the entry was too large to
/// hash, its SHA-256. The media bytes are never copied out of the archive.
class FacebookAttachmentMetadata {
  const FacebookAttachmentMetadata({
    required this.sourceLocator,
    required this.relativePath,
    required this.mediaType,
    required this.sizeBytes,
    this.contentHash,
  });

  /// The record this attachment belongs to, so the event it becomes can be
  /// found without relying on row order.
  final String sourceLocator;

  final String relativePath;

  /// `image`, `video`, `audio` or `file`.
  final String mediaType;

  final int sizeBytes;
  final String? contentHash;

  FacebookAttachmentMetadata withHash(String? hash) =>
      FacebookAttachmentMetadata(
        sourceLocator: sourceLocator,
        relativePath: relativePath,
        mediaType: mediaType,
        sizeBytes: sizeBytes,
        contentHash: hash,
      );
}

class FacebookImportPreview {
  const FacebookImportPreview({
    required this.archiveInspection,
    required this.scan,
    required this.records,
    required this.files,
    required this.coverage,
    required this.supportedFiles,
    required this.unsupportedJsonFiles,
    required this.knownNotImportedJsonFiles,
    required this.skippedRecords,
    required this.warnings,
    this.attachments = const [],
  });

  final ArchiveInspection archiveInspection;

  /// The validated scan this preview was parsed from, for coverage reporting.
  final ArchiveScan scan;

  /// Normalized messages and comments, in archive order.
  final List<FacebookRecord> records;

  /// Every archive entry the importer examined, in archive order.
  final List<FacebookPreviewFile> files;

  /// The per-file coverage of this preview, including the category of every
  /// path under a documented export root.
  final ImportCoverageReport coverage;

  final int supportedFiles;

  /// JSON files that are genuinely unknown: no supported shape and no
  /// documented export root.
  final int unsupportedJsonFiles;

  /// JSON files under a documented export root that this importer does not
  /// model yet. Counted apart from [unsupportedJsonFiles] so neither number is
  /// misleading.
  final int knownNotImportedJsonFiles;

  final int skippedRecords;
  final List<String> warnings;

  /// Media references quoted by the parsed records, metadata only.
  final List<FacebookAttachmentMetadata> attachments;

  FacebookImportPreview copyWith({
    List<FacebookAttachmentMetadata>? attachments,
    List<String>? warnings,
  }) => FacebookImportPreview(
    archiveInspection: archiveInspection,
    scan: scan,
    records: records,
    files: files,
    coverage: coverage,
    supportedFiles: supportedFiles,
    unsupportedJsonFiles: unsupportedJsonFiles,
    knownNotImportedJsonFiles: knownNotImportedJsonFiles,
    skippedRecords: skippedRecords,
    warnings: List.unmodifiable(warnings ?? this.warnings),
    attachments: List.unmodifiable(attachments ?? this.attachments),
  );
}

/// Builds the coverage report for a preview, so the stored report and the
/// on-screen preview classify every file the same way.
ImportCoverageReport _coverageOf(
  ArchiveScan scan,
  List<FacebookPreviewFile> files,
) => ImportCoverageReport.fromScan(
  scan,
  outcomes: [
    for (final file in files)
      ImportFileOutcome(
        path: file.path,
        reason: switch (file.status) {
          FacebookPreviewFileStatus.parsed => ImportCoverageReason.supported,
          FacebookPreviewFileStatus.unsupported =>
            ImportCoverageReason.byCode(file.errorCode) ??
                ImportCoverageReason.unsupportedJsonShape,
          FacebookPreviewFileStatus.knownNotImported =>
            ImportCoverageReason.knownNotImported,
        },
        recordsParsed: file.recordsParsed,
        recordsSkipped: file.recordsSkipped,
      ),
  ],
);

class FacebookImportException implements CodedException {
  const FacebookImportException(this.code, this.message);

  @override
  final String code;
  final String message;

  @override
  String toString() => 'FacebookImportException($code): $message';
}

/// Reads the explicitly supported Facebook JSON shapes from a ZIP: message
/// files (`messages/inbox/.../message_1.json`), comment files
/// (`comments/comments.json`), reaction files (`likes_and_reactions/*.json`)
/// and post files (`posts/your_posts_1.json` and
/// `posts/your_posts__check_ins__photos_and_videos_1.json`).
/// This returns an in-memory preview only; it does not persist records.
// Facebook has shipped several layouts. The same file appears as
// `likes_and_reactions_1.json` at the export root in older exports and as
// `likes_and_reactions/likes_and_reactions.json` in newer ones, so every
// pattern matches on the file name and ignores which folder holds it.
// A message file is the default kind: `message_1.json`, `messages.json` and
// anything inside a `messages` folder all parse as messages, so no name pattern
// is needed for them.
const _commentFilePattern =
    r'(^|/)comments?(_[0-9]+)?\.json$'
    r'|(^|/)your_comments(_[0-9]+)?\.json$'
    r'|(^|/)comments/[^/]+\.json$';
const _reactionFilePattern =
    r'(^|/)likes_and_reactions(_[0-9]+)?\.json$'
    r'|(^|/)likes_and_reactions/[^/]+\.json$'
    r'|(^|/)reactions(_[0-9]+)?\.json$';
const _postFilePattern =
    r'(^|/)your_posts(_[0-9]+)?\.json$'
    r'|(^|/)your_posts__[^/]+\.json$'
    r'|(^|/)posts/your_posts[^/]*\.json$';
final _commentFileMatcher = RegExp(_commentFilePattern);
final _reactionFileMatcher = RegExp(_reactionFilePattern);
final _postFileMatcher = RegExp(_postFilePattern);

/// Longest reaction token kept. One reaction token is stored per event, in an
/// allowlisted metadata key, so the value needs a bound.
const int _maxReactionTokenLength = 64;

/// Safe reason codes for media references an import cannot use.
const String attachmentPathRejectedWarning = 'attachment_path_rejected';
const String attachmentMissingWarning = 'attachment_missing';
const String attachmentHashLimitWarning = 'attachment_hash_size_limit';
const String attachmentCountLimitWarning = 'attachment_count_limit';

/// Some files sit under a documented Facebook export root this importer does
/// not model yet. Their category is known; they were left for later, not
/// rejected as unknown.
const String knownFoldersNotImportedWarning = 'known_folders_not_imported';

/// Bounds on attachment metadata: the longest archive path kept, and how many
/// references one record may contribute.
const int _maxAttachmentPathLength = 1024;
const int _maxAttachmentsPerRecord = 100;

/// Export categories that carry a media reference, and the media type each
/// one proves. Message files group media by these keys.
const Map<String, String> _messageMediaFields = {
  'photos': 'image',
  'gifs': 'image',
  'videos': 'video',
  'audio_files': 'audio',
  'files': 'file',
};

const Set<String> _imageExtensions = {
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
  '.heic',
  '.avif',
};
const Set<String> _videoExtensions = {'.mp4', '.mov', '.m4v', '.webm', '.avi'};
const Set<String> _audioExtensions = {
  '.mp3',
  '.m4a',
  '.wav',
  '.ogg',
  '.opus',
  '.aac',
};

/// The media type an archive path's extension proves, or `file` when it proves
/// nothing.
String _mediaTypeForPath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0) return 'file';
  final extension = path.substring(dot).toLowerCase();
  if (_imageExtensions.contains(extension)) return 'image';
  if (_videoExtensions.contains(extension)) return 'video';
  if (_audioExtensions.contains(extension)) return 'audio';
  return 'file';
}

/// The allowlisted key a reaction token is stored under.
const String reactionMetadataKey = 'reaction';

/// The allowlisted metadata keys a post keeps: how many attachments it has,
/// and the distinct media type names of those attachments. Media bytes are
/// never read; the importer only sees the JSON index.
const String attachmentCountMetadataKey = 'attachments';
const String attachmentTypesMetadataKey = 'attachment_types';

/// The allowlisted key a call's stated duration (seconds) is stored under.
const String callDurationMetadataKey = 'call_duration';

/// Bounds on the people index built from the archive itself. A real export
/// states names in friends, profile and participant files; the index is capped
/// so an adversarial file cannot grow it without limit.
const int _maxIndexedNames = 100000;
const int _maxIndexedNameLength = 512;
const int _maxThreadParticipants = 256;

/// A thread's people, as the message file itself states them.
class _ThreadPeople {
  const _ThreadPeople({required this.names, this.title});

  final List<String> names;
  final String? title;

  static _ThreadPeople? from(Map<String, dynamic>? decoded) {
    if (decoded == null) return null;
    final raw = decoded['participants'];
    final names = <String>[];
    if (raw is List) {
      for (final item in raw.take(_maxThreadParticipants)) {
        final name = item is Map<String, dynamic> ? item['name'] : null;
        if (name is String &&
            name.trim().isNotEmpty &&
            name.length <= _maxIndexedNameLength) {
          names.add(_repairedText(name)!);
        }
      }
    }
    final title = decoded['title'];
    if (names.isEmpty && title is! String) return null;
    return _ThreadPeople(
      names: List.unmodifiable(names),
      title: title is String && title.length <= _maxIndexedNameLength
          ? _repairedText(title)
          : null,
    );
  }
}

/// Names the archive states about itself, collected in the same pass that
/// parses its records.
///
/// It never invents a name: it only remembers spellings that friends, profile
/// and participant files actually contain. Resolution is limited to matching
/// one of those spellings against the thread a message file belongs to.
class _PeopleIndex {
  final Set<String> _keys = <String>{};
  final Map<String, String> _displayByKey = <String, String>{};

  /// The archive owner's exported name, when a profile file states it.
  String? ownerName;

  int get length => _keys.length;

  void add(String? name) {
    if (name == null) return;
    final trimmed = (_repairedText(name) ?? name).trim();
    if (trimmed.isEmpty ||
        trimmed.length > _maxIndexedNameLength ||
        _keys.length >= _maxIndexedNames) {
      return;
    }
    final key = _nameKey(trimmed);
    if (key.isEmpty) return;
    _keys.add(key);
    _displayByKey.putIfAbsent(key, () => trimmed);
  }

  /// The spelling the archive uses for [name], when the index knows it.
  String? displayName(String name) => _displayByKey[_nameKey(name)];

  /// Reads the name-bearing parts of one decoded JSON file. Unknown shapes are
  /// ignored; this only feeds resolution and never changes a record.
  void absorb(String path, Object? decoded) {
    final lower = path.toLowerCase();

    if (lower.contains('friends') ||
        lower.contains('followers') ||
        lower.contains('following')) {
      _absorbPeopleList(decoded);
    }
    if (lower.contains('profile')) {
      ownerName ??= _repairedText(_profileNameOf(decoded));
      add(ownerName);
    }

    if (decoded is Map<String, dynamic>) {
      final participants = decoded['participants'];
      if (participants is List) {
        for (final item in participants.take(_maxThreadParticipants)) {
          if (item is Map<String, dynamic>) add(item['name'] as String?);
        }
      }
    }
  }

  void _absorbPeopleList(Object? decoded) {
    final list = switch (decoded) {
      List<dynamic> value => value,
      Map<String, dynamic> value => const [
        'friends_v2',
        'friends',
        'followers_v2',
        'followers',
        'following_v2',
        'following',
      ].map((key) => value[key]).whereType<List<dynamic>>().firstOrNull,
      _ => null,
    };
    if (list == null) return;
    for (final item in list.take(_maxIndexedNames)) {
      if (item is Map<String, dynamic>) {
        add(item['name'] as String?);
      } else if (item is String) {
        add(item);
      }
    }
  }

  String? _profileNameOf(Object? decoded) {
    if (decoded is! Map<String, dynamic>) return null;
    final profile = decoded['profile_v2'] ?? decoded['profile'];
    if (profile is Map<String, dynamic>) {
      final name = profile['name'];
      if (name is String) return name;
      if (name is Map<String, dynamic>) {
        final full = name['full_name'];
        if (full is String) return full;
      }
    }
    final name = decoded['name'];
    if (name is String) return name;
    if (name is Map<String, dynamic>) {
      final full = name['full_name'];
      if (full is String) return full;
    }
    return null;
  }
}

String _nameKey(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// [value] with any recoverable export encoding damage undone.
///
/// The repair rules live in `import_text_repair.dart`; correct text comes back
/// unchanged, so this is applied to every text field a record carries rather
/// than only to the ones a broken export is known to touch.
String? _repairedText(String? value) =>
    value == null ? null : repairExportedText(value) ?? value;

/// True when [segment] is a thread folder named after [name], with the export's
/// numeric thread id optionally appended (`Layla_100`, `Layla_Ahmad_100`).
bool _threadSegmentMatchesName(String segment, String name) {
  final key = _nameKey(name);
  if (key.isEmpty) return false;
  final slug = segment
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
  if (slug == key) return true;
  if (!slug.startsWith('$key ')) return false;
  return RegExp(r'^[0-9]+$').hasMatch(slug.substring(key.length + 1));
}

/// The sender a message file states for an entry that carries no
/// `sender_name`.
///
/// The participant list is the evidence; the thread title and folder name say
/// which participant the thread is named after. A group thread whose folder
/// matches nobody, or a file with no participants, stays unknown - this never
/// falls back to a name from an unrelated file.
String? _resolveSender({
  required String? rawSender,
  required _ThreadPeople? thread,
  required String filePath,
  required _PeopleIndex people,
}) {
  if (rawSender != null) return rawSender;
  if (thread == null || thread.names.isEmpty) return null;

  if (thread.title != null) {
    final titleKey = _nameKey(thread.title!);
    for (final name in thread.names) {
      if (_nameKey(name) == titleKey) return people.displayName(name) ?? name;
    }
  }

  final segments = filePath.split('/');
  final folder = segments.length >= 2 ? segments[segments.length - 2] : '';
  if (folder.isNotEmpty) {
    for (final name in thread.names) {
      if (_threadSegmentMatchesName(folder, name)) {
        return people.displayName(name) ?? name;
      }
    }
  }

  // One participant is unambiguous: the thread names only that person.
  if (thread.names.length == 1) {
    final only = thread.names.single;
    return people.displayName(only) ?? only;
  }
  return null;
}

/// Attachment kinds this importer can name. Anything else is left unnamed
/// rather than echoed from the export.
const Set<String> _attachmentKinds = {
  'media',
  'image',
  'video',
  'audio',
  'gif',
  'sticker',
  'external_context',
  'place',
  'event',
  'note',
  'link',
  'album',
  'poll',
};

/// The typed payload of a message whose own text is empty.
///
/// A record with an empty body is not an empty record: the export states what
/// it holds in typed fields. The first stated kind wins in the documented
/// order, and only a record with no payload at all becomes `message_empty` -
/// it is still written and counted, never dropped.
({String eventType, Map<String, String>? metadata})? _messagePayloadOf(
  Map<String, dynamic> entry,
  String? text,
) {
  if (text != null && text.trim().isNotEmpty) return null;

  // A deleted message wins: its payload, if any, is no longer the record.
  if (entry['unsent'] == true || entry['is_unsent'] == true) {
    return (eventType: messageDeletedEventType, metadata: null);
  }
  if (entry.containsKey('call_duration')) {
    final seconds = entry['call_duration'];
    return (
      eventType: messageCallEventType,
      metadata: seconds is int && seconds > 0
          ? {callDurationMetadataKey: '$seconds'}
          : null,
    );
  }
  if (entry['share'] is Map) {
    return (eventType: messageLinkEventType, metadata: null);
  }
  if (_hasItems(entry['photos'])) {
    return (eventType: messagePhotoEventType, metadata: null);
  }
  if (_hasItems(entry['videos'])) {
    return (eventType: messageVideoEventType, metadata: null);
  }
  if (_hasItems(entry['gifs'])) {
    return (eventType: messageGifEventType, metadata: null);
  }
  if (_hasItems(entry['audio_files'])) {
    return (eventType: messageAudioEventType, metadata: null);
  }
  if (_hasItems(entry['files'])) {
    return (eventType: messageFileEventType, metadata: null);
  }
  if (entry['sticker'] is Map) {
    return (eventType: messageStickerEventType, metadata: null);
  }
  if (entry['poll'] != null) {
    return (eventType: messagePollEventType, metadata: null);
  }
  if (entry['plan'] != null) {
    return (eventType: messagePlanEventType, metadata: null);
  }
  return (eventType: messageEmptyEventType, metadata: null);
}

bool _hasItems(Object? value) => value is List && value.isNotEmpty;

class FacebookJsonImporter {
  const FacebookJsonImporter({
    this.sourceInspector = const ExportInspector(),
    this.maxJsonBytes = 512 * 1024 * 1024,
    this.maxJsonFileBytes = 64 * 1024 * 1024,
    this.maxRecords = 1000000,
    this.maxAttachmentHashBytes = 8 * 1024 * 1024,
    this.maxAttachmentHashTotalBytes = 64 * 1024 * 1024,
  });

  /// Every JSON entry is read, and [_kindForPath] decides what it is.
  ///
  /// Filtering by file name here meant a rename between export versions made a
  /// file invisible - counted as "unsupported JSON" and never parsed at all.
  /// The JSON byte budgets are the real ceiling, not the name.
  static const supportedFilePattern = r'\.json$';

  final ExportInspector sourceInspector;

  // ponytail: the selected JSON entries are held together while parsing, so the
  // total budget is the peak-heap ceiling, not an archive-size limit. A single
  // long message thread is easily tens of MB. Upgrade path if a real export
  // overflows this: parse each entry as it is read instead of collecting first.
  final int maxJsonBytes;
  final int maxJsonFileBytes;
  final int maxRecords;

  /// Per-entry and total budgets for hashing referenced media. An entry over a
  /// budget is recorded as metadata only and never read.
  final int maxAttachmentHashBytes;
  final int maxAttachmentHashTotalBytes;

  /// Previews a ZIP archive. Kept so callers that hold a [File] stay readable.
  Future<FacebookImportPreview> preview(File archive) =>
      previewSource(archive.path);

  /// Previews a ZIP archive or an already-extracted folder, chosen by [path].
  /// Builds a preview from a ZIP that is already in memory.
  ///
  /// This is the browser path: there is no file to scan, so the picker hands
  /// the bytes over and the same parser runs. Media hashes are skipped here -
  /// a null content hash is already a supported state for an attachment - and
  /// the scan limits are unchanged.
  Future<FacebookImportPreview> previewArchiveBytes(Uint8List bytes) async {
    if (maxJsonBytes < 0 ||
        maxJsonFileBytes < 0 ||
        maxRecords < 1 ||
        maxAttachmentHashBytes < 0 ||
        maxAttachmentHashTotalBytes < 0) {
      throw ArgumentError('Import limits must be positive.');
    }
    final scan = await sourceInspector.scanJsonBytes(
      bytes,
      maxJsonBytes: maxJsonBytes,
      maxJsonFileBytes: maxJsonFileBytes,
      jsonPathPattern: supportedFilePattern,
    );
    return _parseInBackground(scan, maxRecords);
  }

  Future<FacebookImportPreview> previewSource(String path) async {
    if (maxJsonBytes < 0 ||
        maxJsonFileBytes < 0 ||
        maxRecords < 1 ||
        maxAttachmentHashBytes < 0 ||
        maxAttachmentHashTotalBytes < 0) {
      throw ArgumentError('Import limits must be positive.');
    }
    final scan = await sourceInspector.scanJsonFiles(
      path,
      maxJsonBytes: maxJsonBytes,
      maxJsonFileBytes: maxJsonFileBytes,
      jsonPathPattern: supportedFilePattern,
    );
    final parsed = await _parseInBackground(scan, maxRecords);
    if (parsed.attachments.isEmpty) return parsed;

    // Only entries inside the per-entry budget are hashed; the rest keep their
    // known length and a null hash, so an oversized media file is never read.
    final hashable = {
      for (final attachment in parsed.attachments)
        if (attachment.sizeBytes <= maxAttachmentHashBytes)
          attachment.relativePath,
    };
    final digests = await sourceInspector.hashEntries(
      path,
      hashable,
      maxEntryHashBytes: maxAttachmentHashBytes,
      maxTotalHashBytes: maxAttachmentHashTotalBytes,
    );

    final warnings = {...parsed.warnings};
    final attachments = <FacebookAttachmentMetadata>[];
    for (final attachment in parsed.attachments) {
      final digest = digests[attachment.relativePath];
      final unavailable =
          attachment.sizeBytes > maxAttachmentHashBytes ||
          digest == null ||
          digest.sha256 == null;
      if (unavailable) warnings.add(attachmentHashLimitWarning);
      attachments.add(attachment.withHash(unavailable ? null : digest.sha256));
    }
    return parsed.copyWith(
      attachments: attachments,
      warnings: warnings.toList(),
    );
  }
}

/// The supported file shapes, with their safe reason codes.
enum _FileKind {
  message(
    listKey: 'messages',
    eventType: 'message',
    malformedCode: 'malformed_message_json',
    unsupportedCode: 'unsupported_message_json',
    invalidRecordCode: 'invalid_message_record',
    invalidTimestampCode: 'invalid_message_timestamp',
  ),
  comment(
    listKey: 'comments',
    eventType: 'comment',
    malformedCode: 'malformed_comments_json',
    unsupportedCode: 'unsupported_comments_json',
    invalidRecordCode: 'invalid_comment_record',
    invalidTimestampCode: 'invalid_comment_timestamp',
  ),
  reaction(
    // Reaction files are either a top-level list or an object with this key.
    listKey: 'reactions',
    eventType: 'reaction',
    malformedCode: 'malformed_reactions_json',
    unsupportedCode: 'unsupported_reactions_json',
    invalidRecordCode: 'invalid_reaction_record',
    invalidTimestampCode: 'invalid_reaction_timestamp',
  ),
  post(
    // Post files are an object with a `posts` key in newer exports and a
    // top-level list in older ones.
    listKey: 'posts',
    eventType: 'post',
    malformedCode: 'malformed_posts_json',
    unsupportedCode: 'unsupported_posts_json',
    invalidRecordCode: 'invalid_post_record',
    invalidTimestampCode: 'invalid_post_timestamp',
  );

  const _FileKind({
    required this.listKey,
    required this.eventType,
    required this.malformedCode,
    required this.unsupportedCode,
    required this.invalidRecordCode,
    required this.invalidTimestampCode,
  });

  final String listKey;
  final String eventType;
  final String malformedCode;
  final String unsupportedCode;
  final String invalidRecordCode;
  final String invalidTimestampCode;
}

const int _minEpochMillis = -62135596800000;
const int _maxEpochMillis = 253402300799999;
const int _minEpochSeconds = -62135596800;
const int _maxEpochSeconds = 253402300799;

// Facebook exports differ per file. Message files carry `timestamp_ms` (Unix
// milliseconds) and a conversation; comment, reaction and post files carry
// `timestamp` (Unix seconds) and no conversation. A timestamp in the other
// unit is out of range and is reported instead of guessed.
int? _epochMillisOf(_FileKind kind, Object? rawTimestamp) {
  if (rawTimestamp is! int) return null;
  return switch (kind) {
    _FileKind.message =>
      rawTimestamp >= _minEpochMillis && rawTimestamp <= _maxEpochMillis
          ? rawTimestamp
          : null,
    _FileKind.comment || _FileKind.reaction || _FileKind.post =>
      rawTimestamp >= _minEpochSeconds && rawTimestamp <= _maxEpochSeconds
          ? rawTimestamp * 1000
          : null,
  };
}

/// Guesses the file kind from the records themselves.
///
/// Facebook has renamed these files between export versions (a root
/// `likes_and_reactions_1.json` became `likes_and_reactions/likes_and_reactions.json`),
/// but the record shape did not change. Used only when the name matches nothing,
/// so a rename costs coverage instead of the whole import.
///
/// ponytail: first-record heuristic. If a real export ever disagrees, read the
/// name's kind first - it still wins for every name this importer knows.
_FileKind? _sniffKind(Object? decoded) {
  final list = switch (decoded) {
    List<dynamic> value => value,
    Map<String, dynamic> value =>
      _listKeysFor(_FileKind.message)
          .followedBy(_listKeysFor(_FileKind.comment))
          .followedBy(_listKeysFor(_FileKind.reaction))
          .followedBy(_listKeysFor(_FileKind.post))
          .map((key) => value[key])
          .whereType<List<dynamic>>()
          .firstOrNull,
    _ => null,
  };
  if (list == null || list.isEmpty) return null;
  final first = list.first;
  if (first is! Map<String, dynamic>) return null;

  final data = first['data'];
  if (data is List<dynamic> && data.isNotEmpty) {
    final item = data.first;
    if (item is Map<String, dynamic>) {
      if (item.containsKey('reaction')) return _FileKind.reaction;
      if (item.containsKey('comment')) return _FileKind.comment;
      if (item.containsKey('post')) return _FileKind.post;
      if (item.containsKey('text')) return _FileKind.comment;
    }
  }
  if (first.containsKey('sender_name') || first.containsKey('content')) {
    return _FileKind.message;
  }
  if (first.containsKey('title')) return _FileKind.post;
  if (first.containsKey('reaction')) return _FileKind.reaction;
  return null;
}

_FileKind _kindForPath(String path) {
  if (_postFileMatcher.hasMatch(path)) return _FileKind.post;
  if (_reactionFileMatcher.hasMatch(path)) return _FileKind.reaction;
  if (_commentFileMatcher.hasMatch(path)) return _FileKind.comment;
  return _FileKind.message;
}

/// The record list of one supported file, or null when the shape is not the
/// supported one. Reaction and post files are a top-level list in older
/// exports and an object with their list key in newer ones.
List<dynamic>? _entryListOf(_FileKind kind, Object? decoded) {
  // Only a message file is always an object (`{"messages": [...]}`); comments,
  // reactions and posts are a top-level list in older exports and wrapped in a
  // list key in newer ones.
  if (kind != _FileKind.message) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      for (final key in _listKeysFor(kind)) {
        if (decoded[key] is List) return decoded[key] as List<dynamic>;
      }
    }
    return null;
  }
  if (decoded is Map<String, dynamic>) {
    for (final key in _listKeysFor(kind)) {
      if (decoded[key] is List) return decoded[key] as List<dynamic>;
    }
  }
  return null;
}

String _listKeyIn(_FileKind kind, Object? decoded) {
  if (decoded is Map<String, dynamic>) {
    for (final key in _listKeysFor(kind)) {
      if (decoded[key] is List) return key;
    }
  }
  return kind.listKey;
}

Iterable<String> _listKeysFor(_FileKind kind) => switch (kind) {
  _FileKind.comment => const ['comments_v2', 'comments'],
  _FileKind.reaction => const ['reactions_v2', 'reactions'],
  _ => [kind.listKey],
};

/// How many records one file can contribute, used for the record-count limit
/// before anything is parsed.
int _recordCountOf(_FileKind kind, List<dynamic> entries) {
  if (kind != _FileKind.reaction && kind != _FileKind.comment) {
    return entries.length;
  }
  var count = 0;
  for (final entry in entries) {
    if (entry is Map<String, dynamic> && entry['data'] is List) {
      count += (entry['data'] as List<dynamic>).length;
    } else {
      count++;
    }
  }
  return count;
}

/// Parses both flat legacy comments and the nested `comments_v2` Meta shape.
({int parsed, int skipped}) _parseComments({
  required List<FacebookRecord> records,
  required List<dynamic> entries,
  required String filePath,
  required String listKey,
  required Set<String> warnings,
}) {
  var parsed = 0;
  var skipped = 0;

  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    if (entry is! Map<String, dynamic>) {
      skipped++;
      warnings.add(_FileKind.comment.invalidRecordCode);
      continue;
    }

    final data = entry['data'];
    if (data is List) {
      for (var dataIndex = 0; dataIndex < data.length; dataIndex++) {
        final item = data[dataIndex];
        final comment = item is Map<String, dynamic> ? item['comment'] : null;
        if (comment is! Map<String, dynamic>) {
          skipped++;
          warnings.add(_FileKind.comment.invalidRecordCode);
          continue;
        }
        final timestamp = comment['timestamp'] ?? entry['timestamp'];
        final sourceLocator =
            '$filePath#/$listKey/$index/data/$dataIndex/comment';
        if (_appendComment(
          records: records,
          value: comment,
          rawTimestamp: timestamp,
          filePath: filePath,
          sourceLocator: sourceLocator,
          warnings: warnings,
        )) {
          parsed++;
        } else {
          skipped++;
        }
      }
    } else {
      final sourceLocator = '$filePath#/$listKey/$index';
      if (_appendComment(
        records: records,
        value: entry,
        rawTimestamp: entry['timestamp'],
        filePath: filePath,
        sourceLocator: sourceLocator,
        warnings: warnings,
      )) {
        parsed++;
      } else {
        skipped++;
      }
    }
  }
  return (parsed: parsed, skipped: skipped);
}

bool _appendComment({
  required List<FacebookRecord> records,
  required Map<String, dynamic> value,
  required Object? rawTimestamp,
  required String filePath,
  required String sourceLocator,
  required Set<String> warnings,
}) {
  final sender = value['author'];
  final text = value['comment'] ?? value['text'];
  if ((sender != null && sender is! String) ||
      (text != null && text is! String)) {
    warnings.add(_FileKind.comment.invalidRecordCode);
    return false;
  }

  final epochMillis = _epochMillisOf(_FileKind.comment, rawTimestamp);
  if (epochMillis == null && rawTimestamp != null) {
    warnings.add(_FileKind.comment.invalidTimestampCode);
  }
  records.add(
    FacebookRecord(
      eventType: _FileKind.comment.eventType,
      sourcePath: filePath,
      sourceLocator: sourceLocator,
      senderName: _repairedText(sender as String?),
      text: _repairedText(text as String?),
      timestampRaw: epochMillis == null ? null : '$rawTimestamp',
      timestampUtc: epochMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(epochMillis, isUtc: true),
    ),
  );
  return true;
}

/// Turns reaction entries into records: one record per reaction.
///
/// A reaction file entry is `{"timestamp": …, "data": [{"reaction":
/// {"reaction": "👍", "actor": "X"}}]}`. The reaction token is kept in the
/// allowlisted `reaction` metadata key and bounded by
/// [_maxReactionTokenLength]; the actor becomes the person. An entry whose data
/// or token is not usable is skipped and reported, never guessed.
({int parsed, int skipped}) _parseReactions({
  required List<FacebookRecord> records,
  required List<dynamic> entries,
  required String filePath,
  required String listKey,
  required Set<String> warnings,
}) {
  var parsed = 0;
  var skipped = 0;

  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    if (entry is! Map<String, dynamic> || entry['data'] is! List) {
      skipped++;
      warnings.add(_FileKind.reaction.invalidRecordCode);
      continue;
    }

    final data = entry['data'] as List<dynamic>;
    final rawTimestamp = entry['timestamp'];
    final epochMillis = _epochMillisOf(_FileKind.reaction, rawTimestamp);
    if (epochMillis == null && rawTimestamp != null) {
      warnings.add(_FileKind.reaction.invalidTimestampCode);
    }

    for (var dataIndex = 0; dataIndex < data.length; dataIndex++) {
      final item = data[dataIndex];
      final reaction = item is Map<String, dynamic> ? item['reaction'] : null;
      final token = reaction is Map<String, dynamic>
          ? reaction['reaction']
          : null;
      final actor = reaction is Map<String, dynamic> ? reaction['actor'] : null;

      if (token is! String ||
          token.isEmpty ||
          token.length > _maxReactionTokenLength ||
          (actor != null && actor is! String)) {
        skipped++;
        warnings.add(_FileKind.reaction.invalidRecordCode);
        continue;
      }

      records.add(
        FacebookRecord(
          eventType: _FileKind.reaction.eventType,
          sourcePath: filePath,
          sourceLocator: '$filePath#/$listKey/$index/data/$dataIndex',
          senderName: _repairedText(actor as String?),
          text: null,
          timestampRaw: epochMillis == null ? null : '$rawTimestamp',
          timestampUtc: epochMillis == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(epochMillis, isUtc: true),
          // Allowlisted metadata: one bounded reaction token, nothing else.
          metadata: {reactionMetadataKey: token},
        ),
      );
      parsed++;
    }
  }

  return (parsed: parsed, skipped: skipped);
}

/// The text of one post entry, or null when it carries none.
///
/// A post entry is `{"timestamp": …, "data": [{"post": "…"}],
/// "attachments": [...]}`. Every non-empty `post` value is joined in export
/// order; a photo-only post has no `post` value and its text stays null. A
/// data item that is not a map, or a `post` value that is not a string, makes
/// the entry unusable rather than guessed.
({String? text, bool valid}) _postTextOf(Object? data) {
  if (data == null) return (text: null, valid: true);
  if (data is! List) return (text: null, valid: false);
  final parts = <String>[];
  for (final item in data) {
    if (item is! Map<String, dynamic>) return (text: null, valid: false);
    final post = item['post'];
    if (post == null) continue;
    if (post is! String) return (text: null, valid: false);
    if (post.isNotEmpty) parts.add(post);
  }
  return (text: parts.isEmpty ? null : parts.join('\n'), valid: true);
}

/// How many attachments a post entry has, which allowlisted kind names they
/// use, and the media paths they quote. Only metadata is read: the media
/// itself is never opened or copied.
({
  int count,
  Set<String> types,
  List<({String path, String mediaType})> references,
})
_attachmentsOf(Object? attachments) {
  if (attachments is! List) {
    return (
      count: 0,
      types: const <String>{},
      references: const <({String path, String mediaType})>[],
    );
  }
  final types = <String>{};
  final references = <({String path, String mediaType})>[];
  for (final attachment in attachments) {
    if (attachment is! Map<String, dynamic>) continue;
    final data = attachment['data'];
    if (data is! List) continue;
    for (final item in data) {
      if (item is! Map<String, dynamic>) continue;
      for (final key in item.keys) {
        if (_attachmentKinds.contains(key)) types.add(key);
      }
      final media = item['media'];
      final uri = media is Map<String, dynamic> ? media['uri'] : null;
      if (uri is String) {
        references.add((path: uri, mediaType: _mediaTypeForPath(uri)));
      }
      for (final key in const ['image', 'video', 'audio']) {
        final typed = item[key];
        final typedUri = typed is Map<String, dynamic> ? typed['uri'] : null;
        if (typedUri is String) {
          references.add((path: typedUri, mediaType: key));
        }
      }
    }
  }
  return (count: attachments.length, types: types, references: references);
}

/// Resolves one media reference against the archive and keeps its metadata
/// when it is safe and backed by an entry.
///
/// A path that would escape the archive, or one that names no entry, is
/// reported with a content-free code instead of being stored.
void _collectAttachment({
  required List<FacebookAttachmentMetadata> attachments,
  required Map<String, InspectedArchiveEntry> entriesByPath,
  required Set<String> warnings,
  required String sourceLocator,
  required String sourcePath,
  required String rawPath,
  required String mediaType,
}) {
  final normalized = normalizeArchiveRelativePath(
    rawPath,
    maxPathLength: _maxAttachmentPathLength,
  );
  if (normalized == null) {
    warnings.add(attachmentPathRejectedWarning);
    return;
  }
  // Meta writes media URIs relative to the export's inner folder (e.g.
  // "messages/inbox/x/photos/1.jpg" inside "your_activity_across_facebook/"),
  // not to the archive root the scan is keyed by. Try every ancestor folder of
  // the JSON file that carries the reference before giving up.
  var entry = entriesByPath[normalized];
  if (entry == null) {
    final segments = sourcePath.split('/');
    for (var depth = 1; depth < segments.length && entry == null; depth++) {
      final prefix = segments.take(depth).join('/');
      entry = entriesByPath['$prefix/$normalized'];
    }
  }
  if (entry == null) {
    warnings.add(attachmentMissingWarning);
    return;
  }
  attachments.add(
    FacebookAttachmentMetadata(
      sourceLocator: sourceLocator,
      relativePath: entry.relativePath,
      mediaType: mediaType,
      sizeBytes: entry.size,
    ),
  );
}

/// Turns post file entries into one record per post: event_type `post`, no
/// conversation and no sender (the file holds the account's own posts), the
/// joined post text, and allowlisted metadata with the attachment count and
/// media type names only. Text bounds are enforced by the writer against the
/// schema, so a post past the ceiling costs only its own row. Each media
/// reference becomes attachment metadata, never media bytes.
({int parsed, int skipped}) _parsePosts({
  required List<FacebookRecord> records,
  required List<dynamic> entries,
  required String filePath,
  required Set<String> warnings,
  required List<FacebookAttachmentMetadata> attachments,
  required Map<String, InspectedArchiveEntry> entriesByPath,
}) {
  var parsed = 0;
  var skipped = 0;

  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    if (entry is! Map<String, dynamic>) {
      skipped++;
      warnings.add(_FileKind.post.invalidRecordCode);
      continue;
    }

    final text = _postTextOf(entry['data']);
    final attachmentInfo = _attachmentsOf(entry['attachments']);
    if (!text.valid ||
        (entry['attachments'] != null && entry['attachments'] is! List) ||
        // A post with neither text nor attachments has nothing to normalize.
        (text.text == null && attachmentInfo.count == 0)) {
      skipped++;
      warnings.add(_FileKind.post.invalidRecordCode);
      continue;
    }

    final rawTimestamp = entry['timestamp'];
    final epochMillis = _epochMillisOf(_FileKind.post, rawTimestamp);
    if (epochMillis == null && rawTimestamp != null) {
      warnings.add(_FileKind.post.invalidTimestampCode);
    }

    final sourceLocator = '$filePath#/posts/$index';
    var attachmentCount = 0;
    for (final reference in attachmentInfo.references) {
      if (attachmentCount++ >= _maxAttachmentsPerRecord) {
        warnings.add(attachmentCountLimitWarning);
        break;
      }
      _collectAttachment(
        attachments: attachments,
        entriesByPath: entriesByPath,
        warnings: warnings,
        sourceLocator: sourceLocator,
        sourcePath: filePath,
        rawPath: reference.path,
        mediaType: reference.mediaType,
      );
    }

    records.add(
      FacebookRecord(
        eventType: _FileKind.post.eventType,
        sourcePath: filePath,
        sourceLocator: sourceLocator,
        senderName: null,
        text: _repairedText(text.text),
        timestampRaw: epochMillis == null ? null : '$rawTimestamp',
        timestampUtc: epochMillis == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(epochMillis, isUtc: true),
        // Allowlisted metadata: counts and kind names, never media bytes.
        metadata: attachmentInfo.count == 0
            ? null
            : {
                attachmentCountMetadataKey: '${attachmentInfo.count}',
                if (attachmentInfo.types.isNotEmpty)
                  attachmentTypesMetadataKey:
                      (attachmentInfo.types.toList()..sort()).join(','),
              },
      ),
    );
    parsed++;
  }

  return (parsed: parsed, skipped: skipped);
}

FacebookImportPreview _parsePreview(ArchiveScan scan, int maxRecords) {
  final records = <FacebookRecord>[];
  final files = <FacebookPreviewFile>[];
  final warnings = <String>{};
  final attachments = <FacebookAttachmentMetadata>[];
  final entriesByPath = {
    for (final entry in scan.entries) entry.relativePath: entry,
  };
  final selectedJsonPaths = scan.jsonFiles.map((file) => file.path).toSet();
  final people = _PeopleIndex();
  var supportedFiles = 0;
  var unsupportedJsonFiles =
      scan.inspection.jsonFiles - selectedJsonPaths.length;
  var knownNotImportedJsonFiles = 0;
  var skippedRecords = 0;

  for (final file in scan.jsonFiles) {
    var kind = _kindForPath(file.path);

    dynamic decoded;
    try {
      decoded = _decodeArchiveJson(file.bytes);
    } on FormatException {
      unsupportedJsonFiles++;
      warnings.add(kind.malformedCode);
      files.add(
        FacebookPreviewFile(
          path: file.path,
          status: FacebookPreviewFileStatus.unsupported,
          errorCode: kind.malformedCode,
        ),
      );
      continue;
    }

    // Index every name the file states (friends, profile, participants)
    // before its records are resolved, so a thread can use its own evidence.
    people.absorb(file.path, decoded);

    var messages = _entryListOf(kind, decoded);
    if (messages == null) {
      final sniffed = _sniffKind(decoded);
      if (sniffed != null) {
        kind = sniffed;
        messages = _entryListOf(kind, decoded);
      }
    }
    if (messages == null) {
      // A folder Facebook itself names is known even when this importer has no
      // model for its contents yet. Only a genuinely unknown path is
      // "unsupported".
      final knownRoot = importCategoryForPath(file.path) != null;
      if (knownRoot) {
        knownNotImportedJsonFiles++;
      } else {
        unsupportedJsonFiles++;
      }
      warnings.add(kind.unsupportedCode);
      files.add(
        FacebookPreviewFile(
          path: file.path,
          status: knownRoot
              ? FacebookPreviewFileStatus.knownNotImported
              : FacebookPreviewFileStatus.unsupported,
          errorCode: kind.unsupportedCode,
        ),
      );
      continue;
    }

    if (records.length + _recordCountOf(kind, messages) > maxRecords) {
      throw const FacebookImportException(
        'record_count_limit',
        'The supported preview exceeds its configured record limit.',
      );
    }
    supportedFiles++;
    final fileIndex = files.length;
    var fileRecordsParsed = 0;
    var fileRecordsSkipped = 0;
    files.add(
      FacebookPreviewFile(
        path: file.path,
        status: FacebookPreviewFileStatus.parsed,
      ),
    );
    final title = decoded is Map<String, dynamic> && decoded['title'] is String
        ? _repairedText(decoded['title'] as String)
        : null;
    final parentPath = file.path.contains('/')
        ? file.path.substring(0, file.path.lastIndexOf('/'))
        : file.path;
    final thread = kind == _FileKind.message && decoded is Map<String, dynamic>
        ? _ThreadPeople.from(decoded)
        : null;

    if (kind == _FileKind.post) {
      final counts = _parsePosts(
        records: records,
        entries: messages,
        filePath: file.path,
        warnings: warnings,
        attachments: attachments,
        entriesByPath: entriesByPath,
      );
      fileRecordsParsed = counts.parsed;
      fileRecordsSkipped = counts.skipped;
      skippedRecords += counts.skipped;
      files[fileIndex] = FacebookPreviewFile(
        path: file.path,
        status: FacebookPreviewFileStatus.parsed,
        recordsParsed: fileRecordsParsed,
        recordsSkipped: fileRecordsSkipped,
      );
      continue;
    }

    if (kind == _FileKind.comment) {
      final counts = _parseComments(
        records: records,
        entries: messages,
        filePath: file.path,
        listKey: _listKeyIn(kind, decoded),
        warnings: warnings,
      );
      fileRecordsParsed = counts.parsed;
      fileRecordsSkipped = counts.skipped;
      skippedRecords += counts.skipped;
      files[fileIndex] = FacebookPreviewFile(
        path: file.path,
        status: FacebookPreviewFileStatus.parsed,
        recordsParsed: fileRecordsParsed,
        recordsSkipped: fileRecordsSkipped,
      );
      continue;
    }

    if (kind == _FileKind.reaction) {
      final counts = _parseReactions(
        records: records,
        entries: messages,
        filePath: file.path,
        listKey: _listKeyIn(kind, decoded),
        warnings: warnings,
      );
      fileRecordsParsed = counts.parsed;
      fileRecordsSkipped = counts.skipped;
      skippedRecords += counts.skipped;
      files[fileIndex] = FacebookPreviewFile(
        path: file.path,
        status: FacebookPreviewFileStatus.parsed,
        recordsParsed: fileRecordsParsed,
        recordsSkipped: fileRecordsSkipped,
      );
      continue;
    }

    for (var index = 0; index < messages.length; index++) {
      final value = messages[index];
      if (value is! Map<String, dynamic>) {
        skippedRecords++;
        fileRecordsSkipped++;
        warnings.add(kind.invalidRecordCode);
        continue;
      }

      final rawTimestamp =
          value[kind == _FileKind.comment ? 'timestamp' : 'timestamp_ms'];
      final sender = kind == _FileKind.comment
          ? value['author']
          : value['sender_name'];
      final text = kind == _FileKind.comment ? value['text'] : value['content'];
      if ((sender != null && sender is! String) ||
          (text != null && text is! String)) {
        skippedRecords++;
        fileRecordsSkipped++;
        warnings.add(kind.invalidRecordCode);
        continue;
      }

      final epochMillis = _epochMillisOf(kind, rawTimestamp);
      DateTime? timestampUtc;
      String? timestampRaw;
      if (epochMillis != null) {
        timestampRaw = (rawTimestamp as int).toString();
        timestampUtc = DateTime.fromMillisecondsSinceEpoch(
          epochMillis,
          isUtc: true,
        );
      } else if (rawTimestamp != null) {
        warnings.add(kind.invalidTimestampCode);
      }

      final sourceLocator = '${file.path}#/${_listKeyIn(kind, decoded)}/$index';
      // A record's evidence text is repaired here, before anything resolves a
      // name or matches a thread, so the preview and the stored row agree.
      final senderText = _repairedText(sender as String?);
      final bodyText = _repairedText(text as String?);
      final senderName = kind == _FileKind.message
          ? _resolveSender(
              rawSender: senderText,
              thread: thread,
              filePath: file.path,
              people: people,
            )
          : senderText;
      // An empty body is typed by what the export says it holds. Text stays
      // `message`; everything else gets its own stored event type.
      final payload = kind == _FileKind.message
          ? _messagePayloadOf(value, bodyText)
          : null;
      records.add(
        FacebookRecord(
          eventType: payload?.eventType ?? kind.eventType,
          sourcePath: file.path,
          sourceLocator: sourceLocator,
          conversationKey: kind == _FileKind.message ? parentPath : null,
          conversationTitle: kind == _FileKind.message ? title : null,
          senderName: senderName,
          text: bodyText,
          timestampRaw: timestampRaw,
          timestampUtc: timestampUtc,
          metadata: payload?.metadata ?? _reactionMetadataOf(value['reactions']),
        ),
      );
      fileRecordsParsed++;

      // Only message entries group media by category; comments and reactions
      // carry none in the supported shapes.
      if (kind == _FileKind.message) {
        var attachmentCount = 0;
        for (final reference in _messageMediaReferences(value)) {
          if (attachmentCount++ >= _maxAttachmentsPerRecord) {
            warnings.add(attachmentCountLimitWarning);
            break;
          }
          _collectAttachment(
            attachments: attachments,
            entriesByPath: entriesByPath,
            warnings: warnings,
            sourceLocator: sourceLocator,
            sourcePath: file.path,
            rawPath: reference.path,
            mediaType: reference.mediaType,
          );
        }
      }
    }

    files[fileIndex] = FacebookPreviewFile(
      path: file.path,
      status: FacebookPreviewFileStatus.parsed,
      recordsParsed: fileRecordsParsed,
      recordsSkipped: fileRecordsSkipped,
    );
  }

  if (selectedJsonPaths.isEmpty || supportedFiles == 0) {
    warnings.add('no_supported_files_found');
  }
  if (unsupportedJsonFiles > 0) warnings.add('unsupported_json_files_present');
  if (knownNotImportedJsonFiles > 0) {
    warnings.add(knownFoldersNotImportedWarning);
  }

  final unmodifiableFiles = List<FacebookPreviewFile>.unmodifiable(files);
  return FacebookImportPreview(
    archiveInspection: scan.inspection,
    scan: scan,
    records: List.unmodifiable(records),
    files: unmodifiableFiles,
    coverage: _coverageOf(scan, unmodifiableFiles),
    supportedFiles: supportedFiles,
    unsupportedJsonFiles: unsupportedJsonFiles,
    knownNotImportedJsonFiles: knownNotImportedJsonFiles,
    skippedRecords: skippedRecords,
    warnings: List.unmodifiable(warnings),
    attachments: List.unmodifiable(attachments),
  );
}

/// First usable reaction token of one message, repaired and bounded.
///
/// Instagram keeps reactions inside a message rather than in a separate export
/// file. Storing one token in the existing allowlisted `reaction` metadata key
/// keeps it visible without ever folding an emoji into the message body.
Map<String, String>? _reactionMetadataOf(Object? reactions) {
  if (reactions is! List) return null;
  for (final reaction in reactions) {
    final token = reaction is Map<String, dynamic> ? reaction['reaction'] : null;
    if (token is! String || token.isEmpty || token.length > _maxReactionTokenLength) {
      continue;
    }
    final repaired = repairInstagramMojibake(token);
    if (repaired.isEmpty) continue;
    return {reactionMetadataKey: repaired};
  }
  return null;
}

/// Media references of one message entry, grouped by the export fields that
/// prove their media type.
Iterable<({String path, String mediaType})> _messageMediaReferences(
  Map<String, dynamic> entry,
) sync* {
  for (final field in _messageMediaFields.entries) {
    final list = entry[field.key];
    if (list is! List) continue;
    for (final item in list) {
      final uri = item is Map<String, dynamic> ? item['uri'] : null;
      if (uri is String) yield (path: uri, mediaType: field.value);
    }
  }
  // A sticker is one object, not a list, and its file is an image.
  final sticker = entry['sticker'];
  final stickerUri = sticker is Map<String, dynamic> ? sticker['uri'] : null;
  if (stickerUri is String) yield (path: stickerUri, mediaType: 'image');
}

/// Decodes one archive entry's bytes to JSON, tolerating a broken encoding.
///
/// Strict UTF-8 is tried first. When the bytes are not valid UTF-8 - a
/// truncated multi-byte character, or a file written in a single-byte code
/// page - the whole file used to be counted as malformed and dropped, losing
/// every record it held. The byte-preserving Latin-1 decode never fails and
/// keeps the ASCII JSON syntax intact, so the file still parses; the text it
/// carries is then repaired from the decoded string by [repairExportedText],
/// both here and again against the column it is stored in.
///
/// Throws [FormatException] when neither decode yields JSON.
Object? _decodeArchiveJson(Uint8List bytes) {
  try {
    return jsonDecode(utf8.decode(bytes, allowMalformed: false));
  } on FormatException {
    // Not valid UTF-8: every byte maps to the code point of the same value, so
    // structure is preserved for the parser to judge.
    return jsonDecode(latin1.decode(bytes));
  }
}

/// Parses a scan off the UI thread where isolates exist.
///
/// The browser build cannot start an isolate; the parse is already bounded by
/// `maxRecords`, so it runs inline there instead of throwing.
Future<FacebookImportPreview> _parseInBackground(
  ArchiveScan scan,
  int maxRecords,
) => kIsWeb
    ? Future<FacebookImportPreview>.value(_parsePreview(scan, maxRecords))
    : Isolate.run(() => _parsePreview(scan, maxRecords));
