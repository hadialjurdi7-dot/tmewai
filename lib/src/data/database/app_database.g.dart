// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ImportsTable extends Imports with TableInfo<$ImportsTable, Import> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceFingerprintMeta = const VerificationMeta(
    'sourceFingerprint',
  );
  @override
  late final GeneratedColumn<String> sourceFingerprint =
      GeneratedColumn<String>(
        'source_fingerprint',
        aliasedName,
        false,
        additionalChecks: GeneratedColumn.checkTextLength(
          minTextLength: 1,
          maxTextLength: 128,
        ),
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importerVersionMeta = const VerificationMeta(
    'importerVersion',
  );
  @override
  late final GeneratedColumn<String> importerVersion = GeneratedColumn<String>(
    'importer_version',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ImportStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ImportStatus>($ImportsTable.$converterstatus);
  static const VerificationMeta _coverageJsonMeta = const VerificationMeta(
    'coverageJson',
  );
  @override
  late final GeneratedColumn<String> coverageJson = GeneratedColumn<String>(
    'coverage_json',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 2,
      maxTextLength: 4096,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    platform,
    format,
    sourceFingerprint,
    startedAt,
    completedAt,
    importerVersion,
    status,
    coverageJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'imports';
  @override
  VerificationContext validateIntegrity(
    Insertable<Import> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('source_fingerprint')) {
      context.handle(
        _sourceFingerprintMeta,
        sourceFingerprint.isAcceptableOrUnknown(
          data['source_fingerprint']!,
          _sourceFingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceFingerprintMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('importer_version')) {
      context.handle(
        _importerVersionMeta,
        importerVersion.isAcceptableOrUnknown(
          data['importer_version']!,
          _importerVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_importerVersionMeta);
    }
    if (data.containsKey('coverage_json')) {
      context.handle(
        _coverageJsonMeta,
        coverageJson.isAcceptableOrUnknown(
          data['coverage_json']!,
          _coverageJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Import map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Import(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      sourceFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_fingerprint'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      importerVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}importer_version'],
      )!,
      status: $ImportsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      coverageJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}coverage_json'],
      ),
    );
  }

  @override
  $ImportsTable createAlias(String alias) {
    return $ImportsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ImportStatus, String, String> $converterstatus =
      const EnumNameConverter<ImportStatus>(ImportStatus.values);
}

class Import extends DataClass implements Insertable<Import> {
  final int id;
  final String platform;
  final String format;
  final String sourceFingerprint;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String importerVersion;
  final ImportStatus status;

  /// Coverage totals of this import as a JSON object of counts, so the import
  /// report survives without re-reading the archive.
  final String? coverageJson;
  const Import({
    required this.id,
    required this.platform,
    required this.format,
    required this.sourceFingerprint,
    required this.startedAt,
    this.completedAt,
    required this.importerVersion,
    required this.status,
    this.coverageJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['platform'] = Variable<String>(platform);
    map['format'] = Variable<String>(format);
    map['source_fingerprint'] = Variable<String>(sourceFingerprint);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['importer_version'] = Variable<String>(importerVersion);
    {
      map['status'] = Variable<String>(
        $ImportsTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || coverageJson != null) {
      map['coverage_json'] = Variable<String>(coverageJson);
    }
    return map;
  }

  ImportsCompanion toCompanion(bool nullToAbsent) {
    return ImportsCompanion(
      id: Value(id),
      platform: Value(platform),
      format: Value(format),
      sourceFingerprint: Value(sourceFingerprint),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      importerVersion: Value(importerVersion),
      status: Value(status),
      coverageJson: coverageJson == null && nullToAbsent
          ? const Value.absent()
          : Value(coverageJson),
    );
  }

  factory Import.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Import(
      id: serializer.fromJson<int>(json['id']),
      platform: serializer.fromJson<String>(json['platform']),
      format: serializer.fromJson<String>(json['format']),
      sourceFingerprint: serializer.fromJson<String>(json['sourceFingerprint']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      importerVersion: serializer.fromJson<String>(json['importerVersion']),
      status: $ImportsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      coverageJson: serializer.fromJson<String?>(json['coverageJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'platform': serializer.toJson<String>(platform),
      'format': serializer.toJson<String>(format),
      'sourceFingerprint': serializer.toJson<String>(sourceFingerprint),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'importerVersion': serializer.toJson<String>(importerVersion),
      'status': serializer.toJson<String>(
        $ImportsTable.$converterstatus.toJson(status),
      ),
      'coverageJson': serializer.toJson<String?>(coverageJson),
    };
  }

  Import copyWith({
    int? id,
    String? platform,
    String? format,
    String? sourceFingerprint,
    DateTime? startedAt,
    Value<DateTime?> completedAt = const Value.absent(),
    String? importerVersion,
    ImportStatus? status,
    Value<String?> coverageJson = const Value.absent(),
  }) => Import(
    id: id ?? this.id,
    platform: platform ?? this.platform,
    format: format ?? this.format,
    sourceFingerprint: sourceFingerprint ?? this.sourceFingerprint,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    importerVersion: importerVersion ?? this.importerVersion,
    status: status ?? this.status,
    coverageJson: coverageJson.present ? coverageJson.value : this.coverageJson,
  );
  Import copyWithCompanion(ImportsCompanion data) {
    return Import(
      id: data.id.present ? data.id.value : this.id,
      platform: data.platform.present ? data.platform.value : this.platform,
      format: data.format.present ? data.format.value : this.format,
      sourceFingerprint: data.sourceFingerprint.present
          ? data.sourceFingerprint.value
          : this.sourceFingerprint,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      importerVersion: data.importerVersion.present
          ? data.importerVersion.value
          : this.importerVersion,
      status: data.status.present ? data.status.value : this.status,
      coverageJson: data.coverageJson.present
          ? data.coverageJson.value
          : this.coverageJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Import(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('format: $format, ')
          ..write('sourceFingerprint: $sourceFingerprint, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('importerVersion: $importerVersion, ')
          ..write('status: $status, ')
          ..write('coverageJson: $coverageJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    platform,
    format,
    sourceFingerprint,
    startedAt,
    completedAt,
    importerVersion,
    status,
    coverageJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Import &&
          other.id == this.id &&
          other.platform == this.platform &&
          other.format == this.format &&
          other.sourceFingerprint == this.sourceFingerprint &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.importerVersion == this.importerVersion &&
          other.status == this.status &&
          other.coverageJson == this.coverageJson);
}

class ImportsCompanion extends UpdateCompanion<Import> {
  final Value<int> id;
  final Value<String> platform;
  final Value<String> format;
  final Value<String> sourceFingerprint;
  final Value<DateTime> startedAt;
  final Value<DateTime?> completedAt;
  final Value<String> importerVersion;
  final Value<ImportStatus> status;
  final Value<String?> coverageJson;
  const ImportsCompanion({
    this.id = const Value.absent(),
    this.platform = const Value.absent(),
    this.format = const Value.absent(),
    this.sourceFingerprint = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.importerVersion = const Value.absent(),
    this.status = const Value.absent(),
    this.coverageJson = const Value.absent(),
  });
  ImportsCompanion.insert({
    this.id = const Value.absent(),
    required String platform,
    required String format,
    required String sourceFingerprint,
    required DateTime startedAt,
    this.completedAt = const Value.absent(),
    required String importerVersion,
    required ImportStatus status,
    this.coverageJson = const Value.absent(),
  }) : platform = Value(platform),
       format = Value(format),
       sourceFingerprint = Value(sourceFingerprint),
       startedAt = Value(startedAt),
       importerVersion = Value(importerVersion),
       status = Value(status);
  static Insertable<Import> custom({
    Expression<int>? id,
    Expression<String>? platform,
    Expression<String>? format,
    Expression<String>? sourceFingerprint,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<String>? importerVersion,
    Expression<String>? status,
    Expression<String>? coverageJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (platform != null) 'platform': platform,
      if (format != null) 'format': format,
      if (sourceFingerprint != null) 'source_fingerprint': sourceFingerprint,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (importerVersion != null) 'importer_version': importerVersion,
      if (status != null) 'status': status,
      if (coverageJson != null) 'coverage_json': coverageJson,
    });
  }

  ImportsCompanion copyWith({
    Value<int>? id,
    Value<String>? platform,
    Value<String>? format,
    Value<String>? sourceFingerprint,
    Value<DateTime>? startedAt,
    Value<DateTime?>? completedAt,
    Value<String>? importerVersion,
    Value<ImportStatus>? status,
    Value<String?>? coverageJson,
  }) {
    return ImportsCompanion(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      format: format ?? this.format,
      sourceFingerprint: sourceFingerprint ?? this.sourceFingerprint,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      importerVersion: importerVersion ?? this.importerVersion,
      status: status ?? this.status,
      coverageJson: coverageJson ?? this.coverageJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (sourceFingerprint.present) {
      map['source_fingerprint'] = Variable<String>(sourceFingerprint.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (importerVersion.present) {
      map['importer_version'] = Variable<String>(importerVersion.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $ImportsTable.$converterstatus.toSql(status.value),
      );
    }
    if (coverageJson.present) {
      map['coverage_json'] = Variable<String>(coverageJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportsCompanion(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('format: $format, ')
          ..write('sourceFingerprint: $sourceFingerprint, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('importerVersion: $importerVersion, ')
          ..write('status: $status, ')
          ..write('coverageJson: $coverageJson')
          ..write(')'))
        .toString();
  }
}

class $SourceFilesTable extends SourceFiles
    with TableInfo<$SourceFilesTable, SourceFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SourceFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _importIdMeta = const VerificationMeta(
    'importId',
  );
  @override
  late final GeneratedColumn<int> importId = GeneratedColumn<int>(
    'import_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES imports (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 1024,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ParseStatus, String> parseStatus =
      GeneratedColumn<String>(
        'parse_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ParseStatus>($SourceFilesTable.$converterparseStatus);
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    importId,
    relativePath,
    mediaType,
    contentHash,
    parseStatus,
    errorCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'source_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<SourceFile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('import_id')) {
      context.handle(
        _importIdMeta,
        importId.isAcceptableOrUnknown(data['import_id']!, _importIdMeta),
      );
    } else if (isInserting) {
      context.missing(_importIdMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {importId, relativePath},
  ];
  @override
  SourceFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SourceFile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      importId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}import_id'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      ),
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
      parseStatus: $SourceFilesTable.$converterparseStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}parse_status'],
        )!,
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
    );
  }

  @override
  $SourceFilesTable createAlias(String alias) {
    return $SourceFilesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ParseStatus, String, String> $converterparseStatus =
      const EnumNameConverter<ParseStatus>(ParseStatus.values);
}

class SourceFile extends DataClass implements Insertable<SourceFile> {
  final int id;
  final int importId;
  final String relativePath;
  final String? mediaType;
  final String? contentHash;
  final ParseStatus parseStatus;
  final String? errorCode;
  const SourceFile({
    required this.id,
    required this.importId,
    required this.relativePath,
    this.mediaType,
    this.contentHash,
    required this.parseStatus,
    this.errorCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['import_id'] = Variable<int>(importId);
    map['relative_path'] = Variable<String>(relativePath);
    if (!nullToAbsent || mediaType != null) {
      map['media_type'] = Variable<String>(mediaType);
    }
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    {
      map['parse_status'] = Variable<String>(
        $SourceFilesTable.$converterparseStatus.toSql(parseStatus),
      );
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    return map;
  }

  SourceFilesCompanion toCompanion(bool nullToAbsent) {
    return SourceFilesCompanion(
      id: Value(id),
      importId: Value(importId),
      relativePath: Value(relativePath),
      mediaType: mediaType == null && nullToAbsent
          ? const Value.absent()
          : Value(mediaType),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
      parseStatus: Value(parseStatus),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
    );
  }

  factory SourceFile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SourceFile(
      id: serializer.fromJson<int>(json['id']),
      importId: serializer.fromJson<int>(json['importId']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      mediaType: serializer.fromJson<String?>(json['mediaType']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
      parseStatus: $SourceFilesTable.$converterparseStatus.fromJson(
        serializer.fromJson<String>(json['parseStatus']),
      ),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'importId': serializer.toJson<int>(importId),
      'relativePath': serializer.toJson<String>(relativePath),
      'mediaType': serializer.toJson<String?>(mediaType),
      'contentHash': serializer.toJson<String?>(contentHash),
      'parseStatus': serializer.toJson<String>(
        $SourceFilesTable.$converterparseStatus.toJson(parseStatus),
      ),
      'errorCode': serializer.toJson<String?>(errorCode),
    };
  }

  SourceFile copyWith({
    int? id,
    int? importId,
    String? relativePath,
    Value<String?> mediaType = const Value.absent(),
    Value<String?> contentHash = const Value.absent(),
    ParseStatus? parseStatus,
    Value<String?> errorCode = const Value.absent(),
  }) => SourceFile(
    id: id ?? this.id,
    importId: importId ?? this.importId,
    relativePath: relativePath ?? this.relativePath,
    mediaType: mediaType.present ? mediaType.value : this.mediaType,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
    parseStatus: parseStatus ?? this.parseStatus,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
  );
  SourceFile copyWithCompanion(SourceFilesCompanion data) {
    return SourceFile(
      id: data.id.present ? data.id.value : this.id,
      importId: data.importId.present ? data.importId.value : this.importId,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      parseStatus: data.parseStatus.present
          ? data.parseStatus.value
          : this.parseStatus,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SourceFile(')
          ..write('id: $id, ')
          ..write('importId: $importId, ')
          ..write('relativePath: $relativePath, ')
          ..write('mediaType: $mediaType, ')
          ..write('contentHash: $contentHash, ')
          ..write('parseStatus: $parseStatus, ')
          ..write('errorCode: $errorCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    importId,
    relativePath,
    mediaType,
    contentHash,
    parseStatus,
    errorCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SourceFile &&
          other.id == this.id &&
          other.importId == this.importId &&
          other.relativePath == this.relativePath &&
          other.mediaType == this.mediaType &&
          other.contentHash == this.contentHash &&
          other.parseStatus == this.parseStatus &&
          other.errorCode == this.errorCode);
}

class SourceFilesCompanion extends UpdateCompanion<SourceFile> {
  final Value<int> id;
  final Value<int> importId;
  final Value<String> relativePath;
  final Value<String?> mediaType;
  final Value<String?> contentHash;
  final Value<ParseStatus> parseStatus;
  final Value<String?> errorCode;
  const SourceFilesCompanion({
    this.id = const Value.absent(),
    this.importId = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.parseStatus = const Value.absent(),
    this.errorCode = const Value.absent(),
  });
  SourceFilesCompanion.insert({
    this.id = const Value.absent(),
    required int importId,
    required String relativePath,
    this.mediaType = const Value.absent(),
    this.contentHash = const Value.absent(),
    required ParseStatus parseStatus,
    this.errorCode = const Value.absent(),
  }) : importId = Value(importId),
       relativePath = Value(relativePath),
       parseStatus = Value(parseStatus);
  static Insertable<SourceFile> custom({
    Expression<int>? id,
    Expression<int>? importId,
    Expression<String>? relativePath,
    Expression<String>? mediaType,
    Expression<String>? contentHash,
    Expression<String>? parseStatus,
    Expression<String>? errorCode,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (importId != null) 'import_id': importId,
      if (relativePath != null) 'relative_path': relativePath,
      if (mediaType != null) 'media_type': mediaType,
      if (contentHash != null) 'content_hash': contentHash,
      if (parseStatus != null) 'parse_status': parseStatus,
      if (errorCode != null) 'error_code': errorCode,
    });
  }

  SourceFilesCompanion copyWith({
    Value<int>? id,
    Value<int>? importId,
    Value<String>? relativePath,
    Value<String?>? mediaType,
    Value<String?>? contentHash,
    Value<ParseStatus>? parseStatus,
    Value<String?>? errorCode,
  }) {
    return SourceFilesCompanion(
      id: id ?? this.id,
      importId: importId ?? this.importId,
      relativePath: relativePath ?? this.relativePath,
      mediaType: mediaType ?? this.mediaType,
      contentHash: contentHash ?? this.contentHash,
      parseStatus: parseStatus ?? this.parseStatus,
      errorCode: errorCode ?? this.errorCode,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (importId.present) {
      map['import_id'] = Variable<int>(importId.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (parseStatus.present) {
      map['parse_status'] = Variable<String>(
        $SourceFilesTable.$converterparseStatus.toSql(parseStatus.value),
      );
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SourceFilesCompanion(')
          ..write('id: $id, ')
          ..write('importId: $importId, ')
          ..write('relativePath: $relativePath, ')
          ..write('mediaType: $mediaType, ')
          ..write('contentHash: $contentHash, ')
          ..write('parseStatus: $parseStatus, ')
          ..write('errorCode: $errorCode')
          ..write(')'))
        .toString();
  }
}

class $PeopleTable extends People with TableInfo<$PeopleTable, PeopleData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeopleTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformPersonIdMeta = const VerificationMeta(
    'platformPersonId',
  );
  @override
  late final GeneratedColumn<String> platformPersonId = GeneratedColumn<String>(
    'platform_person_id',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 512,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    platform,
    platformPersonId,
    displayName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'people';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeopleData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('platform_person_id')) {
      context.handle(
        _platformPersonIdMeta,
        platformPersonId.isAcceptableOrUnknown(
          data['platform_person_id']!,
          _platformPersonIdMeta,
        ),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {platform, platformPersonId},
  ];
  @override
  PeopleData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeopleData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      )!,
      platformPersonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform_person_id'],
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
    );
  }

  @override
  $PeopleTable createAlias(String alias) {
    return $PeopleTable(attachedDatabase, alias);
  }
}

class PeopleData extends DataClass implements Insertable<PeopleData> {
  final int id;
  final String platform;
  final String? platformPersonId;
  final String displayName;
  const PeopleData({
    required this.id,
    required this.platform,
    this.platformPersonId,
    required this.displayName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['platform'] = Variable<String>(platform);
    if (!nullToAbsent || platformPersonId != null) {
      map['platform_person_id'] = Variable<String>(platformPersonId);
    }
    map['display_name'] = Variable<String>(displayName);
    return map;
  }

  PeopleCompanion toCompanion(bool nullToAbsent) {
    return PeopleCompanion(
      id: Value(id),
      platform: Value(platform),
      platformPersonId: platformPersonId == null && nullToAbsent
          ? const Value.absent()
          : Value(platformPersonId),
      displayName: Value(displayName),
    );
  }

  factory PeopleData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeopleData(
      id: serializer.fromJson<int>(json['id']),
      platform: serializer.fromJson<String>(json['platform']),
      platformPersonId: serializer.fromJson<String?>(json['platformPersonId']),
      displayName: serializer.fromJson<String>(json['displayName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'platform': serializer.toJson<String>(platform),
      'platformPersonId': serializer.toJson<String?>(platformPersonId),
      'displayName': serializer.toJson<String>(displayName),
    };
  }

  PeopleData copyWith({
    int? id,
    String? platform,
    Value<String?> platformPersonId = const Value.absent(),
    String? displayName,
  }) => PeopleData(
    id: id ?? this.id,
    platform: platform ?? this.platform,
    platformPersonId: platformPersonId.present
        ? platformPersonId.value
        : this.platformPersonId,
    displayName: displayName ?? this.displayName,
  );
  PeopleData copyWithCompanion(PeopleCompanion data) {
    return PeopleData(
      id: data.id.present ? data.id.value : this.id,
      platform: data.platform.present ? data.platform.value : this.platform,
      platformPersonId: data.platformPersonId.present
          ? data.platformPersonId.value
          : this.platformPersonId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeopleData(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('platformPersonId: $platformPersonId, ')
          ..write('displayName: $displayName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, platform, platformPersonId, displayName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeopleData &&
          other.id == this.id &&
          other.platform == this.platform &&
          other.platformPersonId == this.platformPersonId &&
          other.displayName == this.displayName);
}

class PeopleCompanion extends UpdateCompanion<PeopleData> {
  final Value<int> id;
  final Value<String> platform;
  final Value<String?> platformPersonId;
  final Value<String> displayName;
  const PeopleCompanion({
    this.id = const Value.absent(),
    this.platform = const Value.absent(),
    this.platformPersonId = const Value.absent(),
    this.displayName = const Value.absent(),
  });
  PeopleCompanion.insert({
    this.id = const Value.absent(),
    required String platform,
    this.platformPersonId = const Value.absent(),
    required String displayName,
  }) : platform = Value(platform),
       displayName = Value(displayName);
  static Insertable<PeopleData> custom({
    Expression<int>? id,
    Expression<String>? platform,
    Expression<String>? platformPersonId,
    Expression<String>? displayName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (platform != null) 'platform': platform,
      if (platformPersonId != null) 'platform_person_id': platformPersonId,
      if (displayName != null) 'display_name': displayName,
    });
  }

  PeopleCompanion copyWith({
    Value<int>? id,
    Value<String>? platform,
    Value<String?>? platformPersonId,
    Value<String>? displayName,
  }) {
    return PeopleCompanion(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      platformPersonId: platformPersonId ?? this.platformPersonId,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (platformPersonId.present) {
      map['platform_person_id'] = Variable<String>(platformPersonId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeopleCompanion(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('platformPersonId: $platformPersonId, ')
          ..write('displayName: $displayName')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, Conversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _importIdMeta = const VerificationMeta(
    'importId',
  );
  @override
  late final GeneratedColumn<int> importId = GeneratedColumn<int>(
    'import_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES imports (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sourceConversationIdMeta =
      const VerificationMeta('sourceConversationId');
  @override
  late final GeneratedColumn<String> sourceConversationId =
      GeneratedColumn<String>(
        'source_conversation_id',
        aliasedName,
        true,
        additionalChecks: GeneratedColumn.checkTextLength(
          minTextLength: 1,
          maxTextLength: 128,
        ),
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 512,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    importId,
    sourceConversationId,
    title,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Conversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('import_id')) {
      context.handle(
        _importIdMeta,
        importId.isAcceptableOrUnknown(data['import_id']!, _importIdMeta),
      );
    } else if (isInserting) {
      context.missing(_importIdMeta);
    }
    if (data.containsKey('source_conversation_id')) {
      context.handle(
        _sourceConversationIdMeta,
        sourceConversationId.isAcceptableOrUnknown(
          data['source_conversation_id']!,
          _sourceConversationIdMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      importId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}import_id'],
      )!,
      sourceConversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_conversation_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class Conversation extends DataClass implements Insertable<Conversation> {
  final int id;
  final int importId;
  final String? sourceConversationId;
  final String? title;
  const Conversation({
    required this.id,
    required this.importId,
    this.sourceConversationId,
    this.title,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['import_id'] = Variable<int>(importId);
    if (!nullToAbsent || sourceConversationId != null) {
      map['source_conversation_id'] = Variable<String>(sourceConversationId);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      importId: Value(importId),
      sourceConversationId: sourceConversationId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceConversationId),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
    );
  }

  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversation(
      id: serializer.fromJson<int>(json['id']),
      importId: serializer.fromJson<int>(json['importId']),
      sourceConversationId: serializer.fromJson<String?>(
        json['sourceConversationId'],
      ),
      title: serializer.fromJson<String?>(json['title']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'importId': serializer.toJson<int>(importId),
      'sourceConversationId': serializer.toJson<String?>(sourceConversationId),
      'title': serializer.toJson<String?>(title),
    };
  }

  Conversation copyWith({
    int? id,
    int? importId,
    Value<String?> sourceConversationId = const Value.absent(),
    Value<String?> title = const Value.absent(),
  }) => Conversation(
    id: id ?? this.id,
    importId: importId ?? this.importId,
    sourceConversationId: sourceConversationId.present
        ? sourceConversationId.value
        : this.sourceConversationId,
    title: title.present ? title.value : this.title,
  );
  Conversation copyWithCompanion(ConversationsCompanion data) {
    return Conversation(
      id: data.id.present ? data.id.value : this.id,
      importId: data.importId.present ? data.importId.value : this.importId,
      sourceConversationId: data.sourceConversationId.present
          ? data.sourceConversationId.value
          : this.sourceConversationId,
      title: data.title.present ? data.title.value : this.title,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversation(')
          ..write('id: $id, ')
          ..write('importId: $importId, ')
          ..write('sourceConversationId: $sourceConversationId, ')
          ..write('title: $title')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, importId, sourceConversationId, title);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversation &&
          other.id == this.id &&
          other.importId == this.importId &&
          other.sourceConversationId == this.sourceConversationId &&
          other.title == this.title);
}

class ConversationsCompanion extends UpdateCompanion<Conversation> {
  final Value<int> id;
  final Value<int> importId;
  final Value<String?> sourceConversationId;
  final Value<String?> title;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.importId = const Value.absent(),
    this.sourceConversationId = const Value.absent(),
    this.title = const Value.absent(),
  });
  ConversationsCompanion.insert({
    this.id = const Value.absent(),
    required int importId,
    this.sourceConversationId = const Value.absent(),
    this.title = const Value.absent(),
  }) : importId = Value(importId);
  static Insertable<Conversation> custom({
    Expression<int>? id,
    Expression<int>? importId,
    Expression<String>? sourceConversationId,
    Expression<String>? title,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (importId != null) 'import_id': importId,
      if (sourceConversationId != null)
        'source_conversation_id': sourceConversationId,
      if (title != null) 'title': title,
    });
  }

  ConversationsCompanion copyWith({
    Value<int>? id,
    Value<int>? importId,
    Value<String?>? sourceConversationId,
    Value<String?>? title,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
      importId: importId ?? this.importId,
      sourceConversationId: sourceConversationId ?? this.sourceConversationId,
      title: title ?? this.title,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (importId.present) {
      map['import_id'] = Variable<int>(importId.value);
    }
    if (sourceConversationId.present) {
      map['source_conversation_id'] = Variable<String>(
        sourceConversationId.value,
      );
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('importId: $importId, ')
          ..write('sourceConversationId: $sourceConversationId, ')
          ..write('title: $title')
          ..write(')'))
        .toString();
  }
}

class $EventsTable extends Events with TableInfo<$EventsTable, Event> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _importIdMeta = const VerificationMeta(
    'importId',
  );
  @override
  late final GeneratedColumn<int> importId = GeneratedColumn<int>(
    'import_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES imports (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sourceFileIdMeta = const VerificationMeta(
    'sourceFileId',
  );
  @override
  late final GeneratedColumn<int> sourceFileId = GeneratedColumn<int>(
    'source_file_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES source_files (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sourceLocatorMeta = const VerificationMeta(
    'sourceLocator',
  );
  @override
  late final GeneratedColumn<String> sourceLocator = GeneratedColumn<String>(
    'source_locator',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 2048,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampRawMeta = const VerificationMeta(
    'timestampRaw',
  );
  @override
  late final GeneratedColumn<String> timestampRaw = GeneratedColumn<String>(
    'timestamp_raw',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timestampNormalizedMeta =
      const VerificationMeta('timestampNormalized');
  @override
  late final GeneratedColumn<DateTime> timestampNormalized =
      GeneratedColumn<DateTime>(
        'timestamp_normalized',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  late final GeneratedColumnWithTypeConverter<TimezoneStatus, String>
  timezoneStatus = GeneratedColumn<String>(
    'timezone_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<TimezoneStatus>($EventsTable.$convertertimezoneStatus);
  static const VerificationMeta _actorIdMeta = const VerificationMeta(
    'actorId',
  );
  @override
  late final GeneratedColumn<int> actorId = GeneratedColumn<int>(
    'actor_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES people (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<int> conversationId = GeneratedColumn<int>(
    'conversation_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversations (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _textContentMeta = const VerificationMeta(
    'textContent',
  );
  @override
  late final GeneratedColumn<String> textContent = GeneratedColumn<String>(
    'text_content',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 0,
      maxTextLength: 100000,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 0,
      maxTextLength: 8192,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    importId,
    sourceFileId,
    sourceLocator,
    platform,
    eventType,
    timestampRaw,
    timestampNormalized,
    timezoneStatus,
    actorId,
    conversationId,
    textContent,
    metadataJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<Event> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('import_id')) {
      context.handle(
        _importIdMeta,
        importId.isAcceptableOrUnknown(data['import_id']!, _importIdMeta),
      );
    } else if (isInserting) {
      context.missing(_importIdMeta);
    }
    if (data.containsKey('source_file_id')) {
      context.handle(
        _sourceFileIdMeta,
        sourceFileId.isAcceptableOrUnknown(
          data['source_file_id']!,
          _sourceFileIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceFileIdMeta);
    }
    if (data.containsKey('source_locator')) {
      context.handle(
        _sourceLocatorMeta,
        sourceLocator.isAcceptableOrUnknown(
          data['source_locator']!,
          _sourceLocatorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceLocatorMeta);
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('timestamp_raw')) {
      context.handle(
        _timestampRawMeta,
        timestampRaw.isAcceptableOrUnknown(
          data['timestamp_raw']!,
          _timestampRawMeta,
        ),
      );
    }
    if (data.containsKey('timestamp_normalized')) {
      context.handle(
        _timestampNormalizedMeta,
        timestampNormalized.isAcceptableOrUnknown(
          data['timestamp_normalized']!,
          _timestampNormalizedMeta,
        ),
      );
    }
    if (data.containsKey('actor_id')) {
      context.handle(
        _actorIdMeta,
        actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta),
      );
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    }
    if (data.containsKey('text_content')) {
      context.handle(
        _textContentMeta,
        textContent.isAcceptableOrUnknown(
          data['text_content']!,
          _textContentMeta,
        ),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {importId, sourceLocator},
  ];
  @override
  Event map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Event(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      importId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}import_id'],
      )!,
      sourceFileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_file_id'],
      )!,
      sourceLocator: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_locator'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      timestampRaw: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timestamp_raw'],
      ),
      timestampNormalized: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp_normalized'],
      ),
      timezoneStatus: $EventsTable.$convertertimezoneStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}timezone_status'],
        )!,
      ),
      actorId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actor_id'],
      ),
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}conversation_id'],
      ),
      textContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_content'],
      ),
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      ),
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TimezoneStatus, String, String>
  $convertertimezoneStatus = const EnumNameConverter<TimezoneStatus>(
    TimezoneStatus.values,
  );
}

class Event extends DataClass implements Insertable<Event> {
  final int id;
  final int importId;
  final int sourceFileId;
  final String sourceLocator;
  final String platform;
  final String eventType;
  final String? timestampRaw;
  final DateTime? timestampNormalized;
  final TimezoneStatus timezoneStatus;
  final int? actorId;
  final int? conversationId;
  final String? textContent;
  final String? metadataJson;
  const Event({
    required this.id,
    required this.importId,
    required this.sourceFileId,
    required this.sourceLocator,
    required this.platform,
    required this.eventType,
    this.timestampRaw,
    this.timestampNormalized,
    required this.timezoneStatus,
    this.actorId,
    this.conversationId,
    this.textContent,
    this.metadataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['import_id'] = Variable<int>(importId);
    map['source_file_id'] = Variable<int>(sourceFileId);
    map['source_locator'] = Variable<String>(sourceLocator);
    map['platform'] = Variable<String>(platform);
    map['event_type'] = Variable<String>(eventType);
    if (!nullToAbsent || timestampRaw != null) {
      map['timestamp_raw'] = Variable<String>(timestampRaw);
    }
    if (!nullToAbsent || timestampNormalized != null) {
      map['timestamp_normalized'] = Variable<DateTime>(timestampNormalized);
    }
    {
      map['timezone_status'] = Variable<String>(
        $EventsTable.$convertertimezoneStatus.toSql(timezoneStatus),
      );
    }
    if (!nullToAbsent || actorId != null) {
      map['actor_id'] = Variable<int>(actorId);
    }
    if (!nullToAbsent || conversationId != null) {
      map['conversation_id'] = Variable<int>(conversationId);
    }
    if (!nullToAbsent || textContent != null) {
      map['text_content'] = Variable<String>(textContent);
    }
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      id: Value(id),
      importId: Value(importId),
      sourceFileId: Value(sourceFileId),
      sourceLocator: Value(sourceLocator),
      platform: Value(platform),
      eventType: Value(eventType),
      timestampRaw: timestampRaw == null && nullToAbsent
          ? const Value.absent()
          : Value(timestampRaw),
      timestampNormalized: timestampNormalized == null && nullToAbsent
          ? const Value.absent()
          : Value(timestampNormalized),
      timezoneStatus: Value(timezoneStatus),
      actorId: actorId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorId),
      conversationId: conversationId == null && nullToAbsent
          ? const Value.absent()
          : Value(conversationId),
      textContent: textContent == null && nullToAbsent
          ? const Value.absent()
          : Value(textContent),
      metadataJson: metadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataJson),
    );
  }

  factory Event.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Event(
      id: serializer.fromJson<int>(json['id']),
      importId: serializer.fromJson<int>(json['importId']),
      sourceFileId: serializer.fromJson<int>(json['sourceFileId']),
      sourceLocator: serializer.fromJson<String>(json['sourceLocator']),
      platform: serializer.fromJson<String>(json['platform']),
      eventType: serializer.fromJson<String>(json['eventType']),
      timestampRaw: serializer.fromJson<String?>(json['timestampRaw']),
      timestampNormalized: serializer.fromJson<DateTime?>(
        json['timestampNormalized'],
      ),
      timezoneStatus: $EventsTable.$convertertimezoneStatus.fromJson(
        serializer.fromJson<String>(json['timezoneStatus']),
      ),
      actorId: serializer.fromJson<int?>(json['actorId']),
      conversationId: serializer.fromJson<int?>(json['conversationId']),
      textContent: serializer.fromJson<String?>(json['textContent']),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'importId': serializer.toJson<int>(importId),
      'sourceFileId': serializer.toJson<int>(sourceFileId),
      'sourceLocator': serializer.toJson<String>(sourceLocator),
      'platform': serializer.toJson<String>(platform),
      'eventType': serializer.toJson<String>(eventType),
      'timestampRaw': serializer.toJson<String?>(timestampRaw),
      'timestampNormalized': serializer.toJson<DateTime?>(timestampNormalized),
      'timezoneStatus': serializer.toJson<String>(
        $EventsTable.$convertertimezoneStatus.toJson(timezoneStatus),
      ),
      'actorId': serializer.toJson<int?>(actorId),
      'conversationId': serializer.toJson<int?>(conversationId),
      'textContent': serializer.toJson<String?>(textContent),
      'metadataJson': serializer.toJson<String?>(metadataJson),
    };
  }

  Event copyWith({
    int? id,
    int? importId,
    int? sourceFileId,
    String? sourceLocator,
    String? platform,
    String? eventType,
    Value<String?> timestampRaw = const Value.absent(),
    Value<DateTime?> timestampNormalized = const Value.absent(),
    TimezoneStatus? timezoneStatus,
    Value<int?> actorId = const Value.absent(),
    Value<int?> conversationId = const Value.absent(),
    Value<String?> textContent = const Value.absent(),
    Value<String?> metadataJson = const Value.absent(),
  }) => Event(
    id: id ?? this.id,
    importId: importId ?? this.importId,
    sourceFileId: sourceFileId ?? this.sourceFileId,
    sourceLocator: sourceLocator ?? this.sourceLocator,
    platform: platform ?? this.platform,
    eventType: eventType ?? this.eventType,
    timestampRaw: timestampRaw.present ? timestampRaw.value : this.timestampRaw,
    timestampNormalized: timestampNormalized.present
        ? timestampNormalized.value
        : this.timestampNormalized,
    timezoneStatus: timezoneStatus ?? this.timezoneStatus,
    actorId: actorId.present ? actorId.value : this.actorId,
    conversationId: conversationId.present
        ? conversationId.value
        : this.conversationId,
    textContent: textContent.present ? textContent.value : this.textContent,
    metadataJson: metadataJson.present ? metadataJson.value : this.metadataJson,
  );
  Event copyWithCompanion(EventsCompanion data) {
    return Event(
      id: data.id.present ? data.id.value : this.id,
      importId: data.importId.present ? data.importId.value : this.importId,
      sourceFileId: data.sourceFileId.present
          ? data.sourceFileId.value
          : this.sourceFileId,
      sourceLocator: data.sourceLocator.present
          ? data.sourceLocator.value
          : this.sourceLocator,
      platform: data.platform.present ? data.platform.value : this.platform,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      timestampRaw: data.timestampRaw.present
          ? data.timestampRaw.value
          : this.timestampRaw,
      timestampNormalized: data.timestampNormalized.present
          ? data.timestampNormalized.value
          : this.timestampNormalized,
      timezoneStatus: data.timezoneStatus.present
          ? data.timezoneStatus.value
          : this.timezoneStatus,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      textContent: data.textContent.present
          ? data.textContent.value
          : this.textContent,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Event(')
          ..write('id: $id, ')
          ..write('importId: $importId, ')
          ..write('sourceFileId: $sourceFileId, ')
          ..write('sourceLocator: $sourceLocator, ')
          ..write('platform: $platform, ')
          ..write('eventType: $eventType, ')
          ..write('timestampRaw: $timestampRaw, ')
          ..write('timestampNormalized: $timestampNormalized, ')
          ..write('timezoneStatus: $timezoneStatus, ')
          ..write('actorId: $actorId, ')
          ..write('conversationId: $conversationId, ')
          ..write('textContent: $textContent, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    importId,
    sourceFileId,
    sourceLocator,
    platform,
    eventType,
    timestampRaw,
    timestampNormalized,
    timezoneStatus,
    actorId,
    conversationId,
    textContent,
    metadataJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Event &&
          other.id == this.id &&
          other.importId == this.importId &&
          other.sourceFileId == this.sourceFileId &&
          other.sourceLocator == this.sourceLocator &&
          other.platform == this.platform &&
          other.eventType == this.eventType &&
          other.timestampRaw == this.timestampRaw &&
          other.timestampNormalized == this.timestampNormalized &&
          other.timezoneStatus == this.timezoneStatus &&
          other.actorId == this.actorId &&
          other.conversationId == this.conversationId &&
          other.textContent == this.textContent &&
          other.metadataJson == this.metadataJson);
}

class EventsCompanion extends UpdateCompanion<Event> {
  final Value<int> id;
  final Value<int> importId;
  final Value<int> sourceFileId;
  final Value<String> sourceLocator;
  final Value<String> platform;
  final Value<String> eventType;
  final Value<String?> timestampRaw;
  final Value<DateTime?> timestampNormalized;
  final Value<TimezoneStatus> timezoneStatus;
  final Value<int?> actorId;
  final Value<int?> conversationId;
  final Value<String?> textContent;
  final Value<String?> metadataJson;
  const EventsCompanion({
    this.id = const Value.absent(),
    this.importId = const Value.absent(),
    this.sourceFileId = const Value.absent(),
    this.sourceLocator = const Value.absent(),
    this.platform = const Value.absent(),
    this.eventType = const Value.absent(),
    this.timestampRaw = const Value.absent(),
    this.timestampNormalized = const Value.absent(),
    this.timezoneStatus = const Value.absent(),
    this.actorId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.textContent = const Value.absent(),
    this.metadataJson = const Value.absent(),
  });
  EventsCompanion.insert({
    this.id = const Value.absent(),
    required int importId,
    required int sourceFileId,
    required String sourceLocator,
    required String platform,
    required String eventType,
    this.timestampRaw = const Value.absent(),
    this.timestampNormalized = const Value.absent(),
    required TimezoneStatus timezoneStatus,
    this.actorId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.textContent = const Value.absent(),
    this.metadataJson = const Value.absent(),
  }) : importId = Value(importId),
       sourceFileId = Value(sourceFileId),
       sourceLocator = Value(sourceLocator),
       platform = Value(platform),
       eventType = Value(eventType),
       timezoneStatus = Value(timezoneStatus);
  static Insertable<Event> custom({
    Expression<int>? id,
    Expression<int>? importId,
    Expression<int>? sourceFileId,
    Expression<String>? sourceLocator,
    Expression<String>? platform,
    Expression<String>? eventType,
    Expression<String>? timestampRaw,
    Expression<DateTime>? timestampNormalized,
    Expression<String>? timezoneStatus,
    Expression<int>? actorId,
    Expression<int>? conversationId,
    Expression<String>? textContent,
    Expression<String>? metadataJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (importId != null) 'import_id': importId,
      if (sourceFileId != null) 'source_file_id': sourceFileId,
      if (sourceLocator != null) 'source_locator': sourceLocator,
      if (platform != null) 'platform': platform,
      if (eventType != null) 'event_type': eventType,
      if (timestampRaw != null) 'timestamp_raw': timestampRaw,
      if (timestampNormalized != null)
        'timestamp_normalized': timestampNormalized,
      if (timezoneStatus != null) 'timezone_status': timezoneStatus,
      if (actorId != null) 'actor_id': actorId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (textContent != null) 'text_content': textContent,
      if (metadataJson != null) 'metadata_json': metadataJson,
    });
  }

  EventsCompanion copyWith({
    Value<int>? id,
    Value<int>? importId,
    Value<int>? sourceFileId,
    Value<String>? sourceLocator,
    Value<String>? platform,
    Value<String>? eventType,
    Value<String?>? timestampRaw,
    Value<DateTime?>? timestampNormalized,
    Value<TimezoneStatus>? timezoneStatus,
    Value<int?>? actorId,
    Value<int?>? conversationId,
    Value<String?>? textContent,
    Value<String?>? metadataJson,
  }) {
    return EventsCompanion(
      id: id ?? this.id,
      importId: importId ?? this.importId,
      sourceFileId: sourceFileId ?? this.sourceFileId,
      sourceLocator: sourceLocator ?? this.sourceLocator,
      platform: platform ?? this.platform,
      eventType: eventType ?? this.eventType,
      timestampRaw: timestampRaw ?? this.timestampRaw,
      timestampNormalized: timestampNormalized ?? this.timestampNormalized,
      timezoneStatus: timezoneStatus ?? this.timezoneStatus,
      actorId: actorId ?? this.actorId,
      conversationId: conversationId ?? this.conversationId,
      textContent: textContent ?? this.textContent,
      metadataJson: metadataJson ?? this.metadataJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (importId.present) {
      map['import_id'] = Variable<int>(importId.value);
    }
    if (sourceFileId.present) {
      map['source_file_id'] = Variable<int>(sourceFileId.value);
    }
    if (sourceLocator.present) {
      map['source_locator'] = Variable<String>(sourceLocator.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (timestampRaw.present) {
      map['timestamp_raw'] = Variable<String>(timestampRaw.value);
    }
    if (timestampNormalized.present) {
      map['timestamp_normalized'] = Variable<DateTime>(
        timestampNormalized.value,
      );
    }
    if (timezoneStatus.present) {
      map['timezone_status'] = Variable<String>(
        $EventsTable.$convertertimezoneStatus.toSql(timezoneStatus.value),
      );
    }
    if (actorId.present) {
      map['actor_id'] = Variable<int>(actorId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<int>(conversationId.value);
    }
    if (textContent.present) {
      map['text_content'] = Variable<String>(textContent.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('id: $id, ')
          ..write('importId: $importId, ')
          ..write('sourceFileId: $sourceFileId, ')
          ..write('sourceLocator: $sourceLocator, ')
          ..write('platform: $platform, ')
          ..write('eventType: $eventType, ')
          ..write('timestampRaw: $timestampRaw, ')
          ..write('timestampNormalized: $timestampNormalized, ')
          ..write('timezoneStatus: $timezoneStatus, ')
          ..write('actorId: $actorId, ')
          ..write('conversationId: $conversationId, ')
          ..write('textContent: $textContent, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, Attachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
    'event_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES events (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sourceFileIdMeta = const VerificationMeta(
    'sourceFileId',
  );
  @override
  late final GeneratedColumn<int> sourceFileId = GeneratedColumn<int>(
    'source_file_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES source_files (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 1024,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediaTypeMeta = const VerificationMeta(
    'mediaType',
  );
  @override
  late final GeneratedColumn<String> mediaType = GeneratedColumn<String>(
    'media_type',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 128,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventId,
    sourceFileId,
    relativePath,
    mediaType,
    sizeBytes,
    contentHash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('source_file_id')) {
      context.handle(
        _sourceFileIdMeta,
        sourceFileId.isAcceptableOrUnknown(
          data['source_file_id']!,
          _sourceFileIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceFileIdMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    }
    if (data.containsKey('media_type')) {
      context.handle(
        _mediaTypeMeta,
        mediaType.isAcceptableOrUnknown(data['media_type']!, _mediaTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaTypeMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attachment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_id'],
      ),
      sourceFileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_file_id'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      ),
      mediaType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}media_type'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      ),
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class Attachment extends DataClass implements Insertable<Attachment> {
  final int id;
  final int? eventId;
  final int sourceFileId;
  final String? relativePath;
  final String mediaType;
  final int sizeBytes;
  final String? contentHash;
  const Attachment({
    required this.id,
    this.eventId,
    required this.sourceFileId,
    this.relativePath,
    required this.mediaType,
    required this.sizeBytes,
    this.contentHash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<int>(eventId);
    }
    map['source_file_id'] = Variable<int>(sourceFileId);
    if (!nullToAbsent || relativePath != null) {
      map['relative_path'] = Variable<String>(relativePath);
    }
    map['media_type'] = Variable<String>(mediaType);
    map['size_bytes'] = Variable<int>(sizeBytes);
    if (!nullToAbsent || contentHash != null) {
      map['content_hash'] = Variable<String>(contentHash);
    }
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      sourceFileId: Value(sourceFileId),
      relativePath: relativePath == null && nullToAbsent
          ? const Value.absent()
          : Value(relativePath),
      mediaType: Value(mediaType),
      sizeBytes: Value(sizeBytes),
      contentHash: contentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(contentHash),
    );
  }

  factory Attachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attachment(
      id: serializer.fromJson<int>(json['id']),
      eventId: serializer.fromJson<int?>(json['eventId']),
      sourceFileId: serializer.fromJson<int>(json['sourceFileId']),
      relativePath: serializer.fromJson<String?>(json['relativePath']),
      mediaType: serializer.fromJson<String>(json['mediaType']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      contentHash: serializer.fromJson<String?>(json['contentHash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'eventId': serializer.toJson<int?>(eventId),
      'sourceFileId': serializer.toJson<int>(sourceFileId),
      'relativePath': serializer.toJson<String?>(relativePath),
      'mediaType': serializer.toJson<String>(mediaType),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'contentHash': serializer.toJson<String?>(contentHash),
    };
  }

  Attachment copyWith({
    int? id,
    Value<int?> eventId = const Value.absent(),
    int? sourceFileId,
    Value<String?> relativePath = const Value.absent(),
    String? mediaType,
    int? sizeBytes,
    Value<String?> contentHash = const Value.absent(),
  }) => Attachment(
    id: id ?? this.id,
    eventId: eventId.present ? eventId.value : this.eventId,
    sourceFileId: sourceFileId ?? this.sourceFileId,
    relativePath: relativePath.present ? relativePath.value : this.relativePath,
    mediaType: mediaType ?? this.mediaType,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    contentHash: contentHash.present ? contentHash.value : this.contentHash,
  );
  Attachment copyWithCompanion(AttachmentsCompanion data) {
    return Attachment(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      sourceFileId: data.sourceFileId.present
          ? data.sourceFileId.value
          : this.sourceFileId,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attachment(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('sourceFileId: $sourceFileId, ')
          ..write('relativePath: $relativePath, ')
          ..write('mediaType: $mediaType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('contentHash: $contentHash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventId,
    sourceFileId,
    relativePath,
    mediaType,
    sizeBytes,
    contentHash,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attachment &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.sourceFileId == this.sourceFileId &&
          other.relativePath == this.relativePath &&
          other.mediaType == this.mediaType &&
          other.sizeBytes == this.sizeBytes &&
          other.contentHash == this.contentHash);
}

class AttachmentsCompanion extends UpdateCompanion<Attachment> {
  final Value<int> id;
  final Value<int?> eventId;
  final Value<int> sourceFileId;
  final Value<String?> relativePath;
  final Value<String> mediaType;
  final Value<int> sizeBytes;
  final Value<String?> contentHash;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.sourceFileId = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.contentHash = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    required int sourceFileId,
    this.relativePath = const Value.absent(),
    required String mediaType,
    required int sizeBytes,
    this.contentHash = const Value.absent(),
  }) : sourceFileId = Value(sourceFileId),
       mediaType = Value(mediaType),
       sizeBytes = Value(sizeBytes);
  static Insertable<Attachment> custom({
    Expression<int>? id,
    Expression<int>? eventId,
    Expression<int>? sourceFileId,
    Expression<String>? relativePath,
    Expression<String>? mediaType,
    Expression<int>? sizeBytes,
    Expression<String>? contentHash,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (sourceFileId != null) 'source_file_id': sourceFileId,
      if (relativePath != null) 'relative_path': relativePath,
      if (mediaType != null) 'media_type': mediaType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (contentHash != null) 'content_hash': contentHash,
    });
  }

  AttachmentsCompanion copyWith({
    Value<int>? id,
    Value<int?>? eventId,
    Value<int>? sourceFileId,
    Value<String?>? relativePath,
    Value<String>? mediaType,
    Value<int>? sizeBytes,
    Value<String?>? contentHash,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      sourceFileId: sourceFileId ?? this.sourceFileId,
      relativePath: relativePath ?? this.relativePath,
      mediaType: mediaType ?? this.mediaType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      contentHash: contentHash ?? this.contentHash,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (sourceFileId.present) {
      map['source_file_id'] = Variable<int>(sourceFileId.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(mediaType.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('sourceFileId: $sourceFileId, ')
          ..write('relativePath: $relativePath, ')
          ..write('mediaType: $mediaType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('contentHash: $contentHash')
          ..write(')'))
        .toString();
  }
}

class $EventEmbeddingsTable extends EventEmbeddings
    with TableInfo<$EventEmbeddingsTable, EventEmbedding> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventEmbeddingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<int> eventId = GeneratedColumn<int>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES events (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dimMeta = const VerificationMeta('dim');
  @override
  late final GeneratedColumn<int> dim = GeneratedColumn<int>(
    'dim',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vectorMeta = const VerificationMeta('vector');
  @override
  late final GeneratedColumn<Uint8List> vector = GeneratedColumn<Uint8List>(
    'vector',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [eventId, modelId, dim, vector];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event_embeddings';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventEmbedding> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('dim')) {
      context.handle(
        _dimMeta,
        dim.isAcceptableOrUnknown(data['dim']!, _dimMeta),
      );
    } else if (isInserting) {
      context.missing(_dimMeta);
    }
    if (data.containsKey('vector')) {
      context.handle(
        _vectorMeta,
        vector.isAcceptableOrUnknown(data['vector']!, _vectorMeta),
      );
    } else if (isInserting) {
      context.missing(_vectorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  EventEmbedding map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventEmbedding(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_id'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      dim: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dim'],
      )!,
      vector: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}vector'],
      )!,
    );
  }

  @override
  $EventEmbeddingsTable createAlias(String alias) {
    return $EventEmbeddingsTable(attachedDatabase, alias);
  }
}

class EventEmbedding extends DataClass implements Insertable<EventEmbedding> {
  final int eventId;

  /// Identifies the model the vector came from. It is internal app state, not
  /// archive text, so it has no import text bound; the embedding model contract
  /// owns its shape and the indexer only writes the id of the loaded model.
  final String modelId;
  final int dim;
  final Uint8List vector;
  const EventEmbedding({
    required this.eventId,
    required this.modelId,
    required this.dim,
    required this.vector,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<int>(eventId);
    map['model_id'] = Variable<String>(modelId);
    map['dim'] = Variable<int>(dim);
    map['vector'] = Variable<Uint8List>(vector);
    return map;
  }

  EventEmbeddingsCompanion toCompanion(bool nullToAbsent) {
    return EventEmbeddingsCompanion(
      eventId: Value(eventId),
      modelId: Value(modelId),
      dim: Value(dim),
      vector: Value(vector),
    );
  }

  factory EventEmbedding.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventEmbedding(
      eventId: serializer.fromJson<int>(json['eventId']),
      modelId: serializer.fromJson<String>(json['modelId']),
      dim: serializer.fromJson<int>(json['dim']),
      vector: serializer.fromJson<Uint8List>(json['vector']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<int>(eventId),
      'modelId': serializer.toJson<String>(modelId),
      'dim': serializer.toJson<int>(dim),
      'vector': serializer.toJson<Uint8List>(vector),
    };
  }

  EventEmbedding copyWith({
    int? eventId,
    String? modelId,
    int? dim,
    Uint8List? vector,
  }) => EventEmbedding(
    eventId: eventId ?? this.eventId,
    modelId: modelId ?? this.modelId,
    dim: dim ?? this.dim,
    vector: vector ?? this.vector,
  );
  EventEmbedding copyWithCompanion(EventEmbeddingsCompanion data) {
    return EventEmbedding(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      dim: data.dim.present ? data.dim.value : this.dim,
      vector: data.vector.present ? data.vector.value : this.vector,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventEmbedding(')
          ..write('eventId: $eventId, ')
          ..write('modelId: $modelId, ')
          ..write('dim: $dim, ')
          ..write('vector: $vector')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(eventId, modelId, dim, $driftBlobEquality.hash(vector));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventEmbedding &&
          other.eventId == this.eventId &&
          other.modelId == this.modelId &&
          other.dim == this.dim &&
          $driftBlobEquality.equals(other.vector, this.vector));
}

class EventEmbeddingsCompanion extends UpdateCompanion<EventEmbedding> {
  final Value<int> eventId;
  final Value<String> modelId;
  final Value<int> dim;
  final Value<Uint8List> vector;
  const EventEmbeddingsCompanion({
    this.eventId = const Value.absent(),
    this.modelId = const Value.absent(),
    this.dim = const Value.absent(),
    this.vector = const Value.absent(),
  });
  EventEmbeddingsCompanion.insert({
    this.eventId = const Value.absent(),
    required String modelId,
    required int dim,
    required Uint8List vector,
  }) : modelId = Value(modelId),
       dim = Value(dim),
       vector = Value(vector);
  static Insertable<EventEmbedding> custom({
    Expression<int>? eventId,
    Expression<String>? modelId,
    Expression<int>? dim,
    Expression<Uint8List>? vector,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (modelId != null) 'model_id': modelId,
      if (dim != null) 'dim': dim,
      if (vector != null) 'vector': vector,
    });
  }

  EventEmbeddingsCompanion copyWith({
    Value<int>? eventId,
    Value<String>? modelId,
    Value<int>? dim,
    Value<Uint8List>? vector,
  }) {
    return EventEmbeddingsCompanion(
      eventId: eventId ?? this.eventId,
      modelId: modelId ?? this.modelId,
      dim: dim ?? this.dim,
      vector: vector ?? this.vector,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<int>(eventId.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (dim.present) {
      map['dim'] = Variable<int>(dim.value);
    }
    if (vector.present) {
      map['vector'] = Variable<Uint8List>(vector.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventEmbeddingsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('modelId: $modelId, ')
          ..write('dim: $dim, ')
          ..write('vector: $vector')
          ..write(')'))
        .toString();
  }
}

class $AiConsentsTable extends AiConsents
    with TableInfo<$AiConsentsTable, AiConsent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiConsentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _policyVersionMeta = const VerificationMeta(
    'policyVersion',
  );
  @override
  late final GeneratedColumn<String> policyVersion = GeneratedColumn<String>(
    'policy_version',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeSummaryMeta = const VerificationMeta(
    'scopeSummary',
  );
  @override
  late final GeneratedColumn<String> scopeSummary = GeneratedColumn<String>(
    'scope_summary',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 1024,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _grantedAtMeta = const VerificationMeta(
    'grantedAt',
  );
  @override
  late final GeneratedColumn<DateTime> grantedAt = GeneratedColumn<DateTime>(
    'granted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventCountMeta = const VerificationMeta(
    'eventCount',
  );
  @override
  late final GeneratedColumn<int> eventCount = GeneratedColumn<int>(
    'event_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteCountMeta = const VerificationMeta(
    'byteCount',
  );
  @override
  late final GeneratedColumn<int> byteCount = GeneratedColumn<int>(
    'byte_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    providerId,
    policyVersion,
    scopeSummary,
    grantedAt,
    eventCount,
    byteCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_consents';
  @override
  VerificationContext validateIntegrity(
    Insertable<AiConsent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('policy_version')) {
      context.handle(
        _policyVersionMeta,
        policyVersion.isAcceptableOrUnknown(
          data['policy_version']!,
          _policyVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_policyVersionMeta);
    }
    if (data.containsKey('scope_summary')) {
      context.handle(
        _scopeSummaryMeta,
        scopeSummary.isAcceptableOrUnknown(
          data['scope_summary']!,
          _scopeSummaryMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scopeSummaryMeta);
    }
    if (data.containsKey('granted_at')) {
      context.handle(
        _grantedAtMeta,
        grantedAt.isAcceptableOrUnknown(data['granted_at']!, _grantedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_grantedAtMeta);
    }
    if (data.containsKey('event_count')) {
      context.handle(
        _eventCountMeta,
        eventCount.isAcceptableOrUnknown(data['event_count']!, _eventCountMeta),
      );
    } else if (isInserting) {
      context.missing(_eventCountMeta);
    }
    if (data.containsKey('byte_count')) {
      context.handle(
        _byteCountMeta,
        byteCount.isAcceptableOrUnknown(data['byte_count']!, _byteCountMeta),
      );
    } else if (isInserting) {
      context.missing(_byteCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiConsent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiConsent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      policyVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}policy_version'],
      )!,
      scopeSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_summary'],
      )!,
      grantedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}granted_at'],
      )!,
      eventCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}event_count'],
      )!,
      byteCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_count'],
      )!,
    );
  }

  @override
  $AiConsentsTable createAlias(String alias) {
    return $AiConsentsTable(attachedDatabase, alias);
  }
}

class AiConsent extends DataClass implements Insertable<AiConsent> {
  final int id;
  final String providerId;
  final String policyVersion;
  final String scopeSummary;
  final DateTime grantedAt;
  final int eventCount;
  final int byteCount;
  const AiConsent({
    required this.id,
    required this.providerId,
    required this.policyVersion,
    required this.scopeSummary,
    required this.grantedAt,
    required this.eventCount,
    required this.byteCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['provider_id'] = Variable<String>(providerId);
    map['policy_version'] = Variable<String>(policyVersion);
    map['scope_summary'] = Variable<String>(scopeSummary);
    map['granted_at'] = Variable<DateTime>(grantedAt);
    map['event_count'] = Variable<int>(eventCount);
    map['byte_count'] = Variable<int>(byteCount);
    return map;
  }

  AiConsentsCompanion toCompanion(bool nullToAbsent) {
    return AiConsentsCompanion(
      id: Value(id),
      providerId: Value(providerId),
      policyVersion: Value(policyVersion),
      scopeSummary: Value(scopeSummary),
      grantedAt: Value(grantedAt),
      eventCount: Value(eventCount),
      byteCount: Value(byteCount),
    );
  }

  factory AiConsent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiConsent(
      id: serializer.fromJson<int>(json['id']),
      providerId: serializer.fromJson<String>(json['providerId']),
      policyVersion: serializer.fromJson<String>(json['policyVersion']),
      scopeSummary: serializer.fromJson<String>(json['scopeSummary']),
      grantedAt: serializer.fromJson<DateTime>(json['grantedAt']),
      eventCount: serializer.fromJson<int>(json['eventCount']),
      byteCount: serializer.fromJson<int>(json['byteCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'providerId': serializer.toJson<String>(providerId),
      'policyVersion': serializer.toJson<String>(policyVersion),
      'scopeSummary': serializer.toJson<String>(scopeSummary),
      'grantedAt': serializer.toJson<DateTime>(grantedAt),
      'eventCount': serializer.toJson<int>(eventCount),
      'byteCount': serializer.toJson<int>(byteCount),
    };
  }

  AiConsent copyWith({
    int? id,
    String? providerId,
    String? policyVersion,
    String? scopeSummary,
    DateTime? grantedAt,
    int? eventCount,
    int? byteCount,
  }) => AiConsent(
    id: id ?? this.id,
    providerId: providerId ?? this.providerId,
    policyVersion: policyVersion ?? this.policyVersion,
    scopeSummary: scopeSummary ?? this.scopeSummary,
    grantedAt: grantedAt ?? this.grantedAt,
    eventCount: eventCount ?? this.eventCount,
    byteCount: byteCount ?? this.byteCount,
  );
  AiConsent copyWithCompanion(AiConsentsCompanion data) {
    return AiConsent(
      id: data.id.present ? data.id.value : this.id,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      policyVersion: data.policyVersion.present
          ? data.policyVersion.value
          : this.policyVersion,
      scopeSummary: data.scopeSummary.present
          ? data.scopeSummary.value
          : this.scopeSummary,
      grantedAt: data.grantedAt.present ? data.grantedAt.value : this.grantedAt,
      eventCount: data.eventCount.present
          ? data.eventCount.value
          : this.eventCount,
      byteCount: data.byteCount.present ? data.byteCount.value : this.byteCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiConsent(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('policyVersion: $policyVersion, ')
          ..write('scopeSummary: $scopeSummary, ')
          ..write('grantedAt: $grantedAt, ')
          ..write('eventCount: $eventCount, ')
          ..write('byteCount: $byteCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    providerId,
    policyVersion,
    scopeSummary,
    grantedAt,
    eventCount,
    byteCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiConsent &&
          other.id == this.id &&
          other.providerId == this.providerId &&
          other.policyVersion == this.policyVersion &&
          other.scopeSummary == this.scopeSummary &&
          other.grantedAt == this.grantedAt &&
          other.eventCount == this.eventCount &&
          other.byteCount == this.byteCount);
}

class AiConsentsCompanion extends UpdateCompanion<AiConsent> {
  final Value<int> id;
  final Value<String> providerId;
  final Value<String> policyVersion;
  final Value<String> scopeSummary;
  final Value<DateTime> grantedAt;
  final Value<int> eventCount;
  final Value<int> byteCount;
  const AiConsentsCompanion({
    this.id = const Value.absent(),
    this.providerId = const Value.absent(),
    this.policyVersion = const Value.absent(),
    this.scopeSummary = const Value.absent(),
    this.grantedAt = const Value.absent(),
    this.eventCount = const Value.absent(),
    this.byteCount = const Value.absent(),
  });
  AiConsentsCompanion.insert({
    this.id = const Value.absent(),
    required String providerId,
    required String policyVersion,
    required String scopeSummary,
    required DateTime grantedAt,
    required int eventCount,
    required int byteCount,
  }) : providerId = Value(providerId),
       policyVersion = Value(policyVersion),
       scopeSummary = Value(scopeSummary),
       grantedAt = Value(grantedAt),
       eventCount = Value(eventCount),
       byteCount = Value(byteCount);
  static Insertable<AiConsent> custom({
    Expression<int>? id,
    Expression<String>? providerId,
    Expression<String>? policyVersion,
    Expression<String>? scopeSummary,
    Expression<DateTime>? grantedAt,
    Expression<int>? eventCount,
    Expression<int>? byteCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (providerId != null) 'provider_id': providerId,
      if (policyVersion != null) 'policy_version': policyVersion,
      if (scopeSummary != null) 'scope_summary': scopeSummary,
      if (grantedAt != null) 'granted_at': grantedAt,
      if (eventCount != null) 'event_count': eventCount,
      if (byteCount != null) 'byte_count': byteCount,
    });
  }

  AiConsentsCompanion copyWith({
    Value<int>? id,
    Value<String>? providerId,
    Value<String>? policyVersion,
    Value<String>? scopeSummary,
    Value<DateTime>? grantedAt,
    Value<int>? eventCount,
    Value<int>? byteCount,
  }) {
    return AiConsentsCompanion(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      policyVersion: policyVersion ?? this.policyVersion,
      scopeSummary: scopeSummary ?? this.scopeSummary,
      grantedAt: grantedAt ?? this.grantedAt,
      eventCount: eventCount ?? this.eventCount,
      byteCount: byteCount ?? this.byteCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (policyVersion.present) {
      map['policy_version'] = Variable<String>(policyVersion.value);
    }
    if (scopeSummary.present) {
      map['scope_summary'] = Variable<String>(scopeSummary.value);
    }
    if (grantedAt.present) {
      map['granted_at'] = Variable<DateTime>(grantedAt.value);
    }
    if (eventCount.present) {
      map['event_count'] = Variable<int>(eventCount.value);
    }
    if (byteCount.present) {
      map['byte_count'] = Variable<int>(byteCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiConsentsCompanion(')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('policyVersion: $policyVersion, ')
          ..write('scopeSummary: $scopeSummary, ')
          ..write('grantedAt: $grantedAt, ')
          ..write('eventCount: $eventCount, ')
          ..write('byteCount: $byteCount')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ImportsTable imports = $ImportsTable(this);
  late final $SourceFilesTable sourceFiles = $SourceFilesTable(this);
  late final $PeopleTable people = $PeopleTable(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $EventsTable events = $EventsTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  late final $EventEmbeddingsTable eventEmbeddings = $EventEmbeddingsTable(
    this,
  );
  late final $AiConsentsTable aiConsents = $AiConsentsTable(this);
  late final Index sourceFilesImportId = Index(
    'source_files_import_id',
    'CREATE INDEX source_files_import_id ON source_files (import_id)',
  );
  late final Index conversationsImportId = Index(
    'conversations_import_id',
    'CREATE INDEX conversations_import_id ON conversations (import_id)',
  );
  late final Index eventsImportId = Index(
    'events_import_id',
    'CREATE INDEX events_import_id ON events (import_id)',
  );
  late final Index eventsTimestampNormalized = Index(
    'events_timestamp_normalized',
    'CREATE INDEX events_timestamp_normalized ON events (timestamp_normalized)',
  );
  late final Index eventsEventType = Index(
    'events_event_type',
    'CREATE INDEX events_event_type ON events (event_type)',
  );
  late final Index eventEmbeddingsModelId = Index(
    'event_embeddings_model_id',
    'CREATE INDEX event_embeddings_model_id ON event_embeddings (model_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    imports,
    sourceFiles,
    people,
    conversations,
    events,
    attachments,
    eventEmbeddings,
    aiConsents,
    sourceFilesImportId,
    conversationsImportId,
    eventsImportId,
    eventsTimestampNormalized,
    eventsEventType,
    eventEmbeddingsModelId,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'imports',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('source_files', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'imports',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('conversations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'imports',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'source_files',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'people',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('events', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'conversations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('events', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attachments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'source_files',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('attachments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('event_embeddings', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ImportsTableCreateCompanionBuilder = ImportsCompanion Function({
  Value<int> id,
  required String platform,
  required String format,
  required String sourceFingerprint,
  required DateTime startedAt,
  Value<DateTime?> completedAt,
  required String importerVersion,
  required ImportStatus status,
  Value<String?> coverageJson,
});
typedef $$ImportsTableUpdateCompanionBuilder = ImportsCompanion Function({
  Value<int> id,
  Value<String> platform,
  Value<String> format,
  Value<String> sourceFingerprint,
  Value<DateTime> startedAt,
  Value<DateTime?> completedAt,
  Value<String> importerVersion,
  Value<ImportStatus> status,
  Value<String?> coverageJson,
});

final class $$ImportsTableReferences
    extends BaseReferences<_$AppDatabase, $ImportsTable, Import> {
  $$ImportsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SourceFilesTable, List<SourceFile>>
  _sourceFilesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.sourceFiles,
    aliasName: 'imports__id__source_files__import_id',
  );

  $$SourceFilesTableProcessedTableManager get sourceFilesRefs {
    final manager = $$SourceFilesTableTableManager(
      $_db,
      $_db.sourceFiles,
    ).filter((f) => f.importId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_sourceFilesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ConversationsTable, List<Conversation>>
  _conversationsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.conversations,
    aliasName: 'imports__id__conversations__import_id',
  );

  $$ConversationsTableProcessedTableManager get conversationsRefs {
    final manager = $$ConversationsTableTableManager(
      $_db,
      $_db.conversations,
    ).filter((f) => f.importId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_conversationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EventsTable, List<Event>> _eventsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.events,
    aliasName: 'imports__id__events__import_id',
  );

  $$EventsTableProcessedTableManager get eventsRefs {
    final manager = $$EventsTableTableManager(
      $_db,
      $_db.events,
    ).filter((f) => f.importId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_eventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ImportsTableFilterComposer
    extends Composer<_$AppDatabase, $ImportsTable> {
  $$ImportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceFingerprint => $composableBuilder(
    column: $table.sourceFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get importerVersion => $composableBuilder(
    column: $table.importerVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ImportStatus, ImportStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get coverageJson => $composableBuilder(
    column: $table.coverageJson,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sourceFilesRefs(
    Expression<bool> Function($$SourceFilesTableFilterComposer f) f,
  ) {
    final $$SourceFilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sourceFiles,
      getReferencedColumn: (t) => t.importId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceFilesTableFilterComposer(
            $db: $db,
            $table: $db.sourceFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> conversationsRefs(
    Expression<bool> Function($$ConversationsTableFilterComposer f) f,
  ) {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.importId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableFilterComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> eventsRefs(
    Expression<bool> Function($$EventsTableFilterComposer f) f,
  ) {
    final $$EventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.importId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableFilterComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ImportsTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportsTable> {
  $$ImportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceFingerprint => $composableBuilder(
    column: $table.sourceFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get importerVersion => $composableBuilder(
    column: $table.importerVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverageJson => $composableBuilder(
    column: $table.coverageJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportsTable> {
  $$ImportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get sourceFingerprint => $composableBuilder(
    column: $table.sourceFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get importerVersion => $composableBuilder(
    column: $table.importerVersion,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ImportStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get coverageJson => $composableBuilder(
    column: $table.coverageJson,
    builder: (column) => column,
  );

  Expression<T> sourceFilesRefs<T extends Object>(
    Expression<T> Function($$SourceFilesTableAnnotationComposer a) f,
  ) {
    final $$SourceFilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sourceFiles,
      getReferencedColumn: (t) => t.importId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceFilesTableAnnotationComposer(
            $db: $db,
            $table: $db.sourceFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> conversationsRefs<T extends Object>(
    Expression<T> Function($$ConversationsTableAnnotationComposer a) f,
  ) {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.importId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableAnnotationComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> eventsRefs<T extends Object>(
    Expression<T> Function($$EventsTableAnnotationComposer a) f,
  ) {
    final $$EventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.importId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableAnnotationComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ImportsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportsTable,
          Import,
          $$ImportsTableFilterComposer,
          $$ImportsTableOrderingComposer,
          $$ImportsTableAnnotationComposer,
          $$ImportsTableCreateCompanionBuilder,
          $$ImportsTableUpdateCompanionBuilder,
          (Import, $$ImportsTableReferences),
          Import,
          PrefetchHooks Function({
            bool sourceFilesRefs,
            bool conversationsRefs,
            bool eventsRefs,
          })
        > {
  $$ImportsTableTableManager(_$AppDatabase db, $ImportsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> sourceFingerprint = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<String> importerVersion = const Value.absent(),
                Value<ImportStatus> status = const Value.absent(),
                Value<String?> coverageJson = const Value.absent(),
              }) => ImportsCompanion(
                id: id,
                platform: platform,
                format: format,
                sourceFingerprint: sourceFingerprint,
                startedAt: startedAt,
                completedAt: completedAt,
                importerVersion: importerVersion,
                status: status,
                coverageJson: coverageJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String platform,
                required String format,
                required String sourceFingerprint,
                required DateTime startedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                required String importerVersion,
                required ImportStatus status,
                Value<String?> coverageJson = const Value.absent(),
              }) => ImportsCompanion.insert(
                id: id,
                platform: platform,
                format: format,
                sourceFingerprint: sourceFingerprint,
                startedAt: startedAt,
                completedAt: completedAt,
                importerVersion: importerVersion,
                status: status,
                coverageJson: coverageJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ImportsTable, Import>(table),
                  $$ImportsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sourceFilesRefs = false,
                conversationsRefs = false,
                eventsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sourceFilesRefs) db.sourceFiles,
                    if (conversationsRefs) db.conversations,
                    if (eventsRefs) db.events,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sourceFilesRefs)
                        await $_getPrefetchedDataByColumns<
                          Import,
                          $ImportsTable,
                          SourceFile,
                          $SourceFilesTable
                        >(
                          currentTable: table,
                          referencedTable: $$ImportsTableReferences
                              ._sourceFilesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ImportsTableReferences(
                                db,
                                table,
                                p0,
                              ).sourceFilesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'import_id',
                          typedResults: items,
                        ),
                      if (conversationsRefs)
                        await $_getPrefetchedDataByColumns<
                          Import,
                          $ImportsTable,
                          Conversation,
                          $ConversationsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ImportsTableReferences
                              ._conversationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ImportsTableReferences(
                                db,
                                table,
                                p0,
                              ).conversationsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'import_id',
                          typedResults: items,
                        ),
                      if (eventsRefs)
                        await $_getPrefetchedDataByColumns<
                          Import,
                          $ImportsTable,
                          Event,
                          $EventsTable
                        >(
                          currentTable: table,
                          referencedTable: $$ImportsTableReferences
                              ._eventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ImportsTableReferences(
                                db,
                                table,
                                p0,
                              ).eventsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'import_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ImportsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportsTable,
      Import,
      $$ImportsTableFilterComposer,
      $$ImportsTableOrderingComposer,
      $$ImportsTableAnnotationComposer,
      $$ImportsTableCreateCompanionBuilder,
      $$ImportsTableUpdateCompanionBuilder,
      (Import, $$ImportsTableReferences),
      Import,
      PrefetchHooks Function({
        bool sourceFilesRefs,
        bool conversationsRefs,
        bool eventsRefs,
      })
    >;
typedef $$SourceFilesTableCreateCompanionBuilder =
    SourceFilesCompanion Function({
      Value<int> id,
      required int importId,
      required String relativePath,
      Value<String?> mediaType,
      Value<String?> contentHash,
      required ParseStatus parseStatus,
      Value<String?> errorCode,
    });
typedef $$SourceFilesTableUpdateCompanionBuilder =
    SourceFilesCompanion Function({
      Value<int> id,
      Value<int> importId,
      Value<String> relativePath,
      Value<String?> mediaType,
      Value<String?> contentHash,
      Value<ParseStatus> parseStatus,
      Value<String?> errorCode,
    });

final class $$SourceFilesTableReferences
    extends BaseReferences<_$AppDatabase, $SourceFilesTable, SourceFile> {
  $$SourceFilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ImportsTable _importIdTable(_$AppDatabase db) =>
      db.imports.createAlias('source_files__import_id__imports__id');

  $$ImportsTableProcessedTableManager get importId {
    final $_column = $_itemColumn<int>('import_id')!;

    final manager = $$ImportsTableTableManager(
      $_db,
      $_db.imports,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_importIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$EventsTable, List<Event>> _eventsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.events,
    aliasName: 'source_files__id__events__source_file_id',
  );

  $$EventsTableProcessedTableManager get eventsRefs {
    final manager = $$EventsTableTableManager(
      $_db,
      $_db.events,
    ).filter((f) => f.sourceFileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_eventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AttachmentsTable, List<Attachment>>
  _attachmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attachments,
    aliasName: 'source_files__id__attachments__source_file_id',
  );

  $$AttachmentsTableProcessedTableManager get attachmentsRefs {
    final manager = $$AttachmentsTableTableManager(
      $_db,
      $_db.attachments,
    ).filter((f) => f.sourceFileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_attachmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SourceFilesTableFilterComposer
    extends Composer<_$AppDatabase, $SourceFilesTable> {
  $$SourceFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ParseStatus, ParseStatus, String>
  get parseStatus => $composableBuilder(
    column: $table.parseStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  $$ImportsTableFilterComposer get importId {
    final $$ImportsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importId,
      referencedTable: $db.imports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportsTableFilterComposer(
            $db: $db,
            $table: $db.imports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> eventsRefs(
    Expression<bool> Function($$EventsTableFilterComposer f) f,
  ) {
    final $$EventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.sourceFileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableFilterComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> attachmentsRefs(
    Expression<bool> Function($$AttachmentsTableFilterComposer f) f,
  ) {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.sourceFileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SourceFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $SourceFilesTable> {
  $$SourceFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parseStatus => $composableBuilder(
    column: $table.parseStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  $$ImportsTableOrderingComposer get importId {
    final $$ImportsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importId,
      referencedTable: $db.imports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportsTableOrderingComposer(
            $db: $db,
            $table: $db.imports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SourceFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SourceFilesTable> {
  $$SourceFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ParseStatus, String> get parseStatus =>
      $composableBuilder(
        column: $table.parseStatus,
        builder: (column) => column,
      );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  $$ImportsTableAnnotationComposer get importId {
    final $$ImportsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importId,
      referencedTable: $db.imports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportsTableAnnotationComposer(
            $db: $db,
            $table: $db.imports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> eventsRefs<T extends Object>(
    Expression<T> Function($$EventsTableAnnotationComposer a) f,
  ) {
    final $$EventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.sourceFileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableAnnotationComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> attachmentsRefs<T extends Object>(
    Expression<T> Function($$AttachmentsTableAnnotationComposer a) f,
  ) {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.sourceFileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SourceFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SourceFilesTable,
          SourceFile,
          $$SourceFilesTableFilterComposer,
          $$SourceFilesTableOrderingComposer,
          $$SourceFilesTableAnnotationComposer,
          $$SourceFilesTableCreateCompanionBuilder,
          $$SourceFilesTableUpdateCompanionBuilder,
          (SourceFile, $$SourceFilesTableReferences),
          SourceFile,
          PrefetchHooks Function({
            bool importId,
            bool eventsRefs,
            bool attachmentsRefs,
          })
        > {
  $$SourceFilesTableTableManager(_$AppDatabase db, $SourceFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SourceFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SourceFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SourceFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> importId = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String?> mediaType = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                Value<ParseStatus> parseStatus = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
              }) => SourceFilesCompanion(
                id: id,
                importId: importId,
                relativePath: relativePath,
                mediaType: mediaType,
                contentHash: contentHash,
                parseStatus: parseStatus,
                errorCode: errorCode,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int importId,
                required String relativePath,
                Value<String?> mediaType = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
                required ParseStatus parseStatus,
                Value<String?> errorCode = const Value.absent(),
              }) => SourceFilesCompanion.insert(
                id: id,
                importId: importId,
                relativePath: relativePath,
                mediaType: mediaType,
                contentHash: contentHash,
                parseStatus: parseStatus,
                errorCode: errorCode,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SourceFilesTable, SourceFile>(table),
                  $$SourceFilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                importId = false,
                eventsRefs = false,
                attachmentsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (eventsRefs) db.events,
                    if (attachmentsRefs) db.attachments,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (importId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.importId,
                            referencedTable: $$SourceFilesTableReferences
                                ._importIdTable(db),
                            referencedColumn: $$SourceFilesTableReferences
                                ._importIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (eventsRefs)
                        await $_getPrefetchedDataByColumns<
                          SourceFile,
                          $SourceFilesTable,
                          Event,
                          $EventsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SourceFilesTableReferences
                              ._eventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourceFilesTableReferences(
                                db,
                                table,
                                p0,
                              ).eventsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'source_file_id',
                          typedResults: items,
                        ),
                      if (attachmentsRefs)
                        await $_getPrefetchedDataByColumns<
                          SourceFile,
                          $SourceFilesTable,
                          Attachment,
                          $AttachmentsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SourceFilesTableReferences
                              ._attachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SourceFilesTableReferences(
                                db,
                                table,
                                p0,
                              ).attachmentsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'source_file_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SourceFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SourceFilesTable,
      SourceFile,
      $$SourceFilesTableFilterComposer,
      $$SourceFilesTableOrderingComposer,
      $$SourceFilesTableAnnotationComposer,
      $$SourceFilesTableCreateCompanionBuilder,
      $$SourceFilesTableUpdateCompanionBuilder,
      (SourceFile, $$SourceFilesTableReferences),
      SourceFile,
      PrefetchHooks Function({
        bool importId,
        bool eventsRefs,
        bool attachmentsRefs,
      })
    >;
typedef $$PeopleTableCreateCompanionBuilder = PeopleCompanion Function({
  Value<int> id,
  required String platform,
  Value<String?> platformPersonId,
  required String displayName,
});
typedef $$PeopleTableUpdateCompanionBuilder = PeopleCompanion Function({
  Value<int> id,
  Value<String> platform,
  Value<String?> platformPersonId,
  Value<String> displayName,
});

final class $$PeopleTableReferences
    extends BaseReferences<_$AppDatabase, $PeopleTable, PeopleData> {
  $$PeopleTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EventsTable, List<Event>> _eventsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.events,
    aliasName: 'people__id__events__actor_id',
  );

  $$EventsTableProcessedTableManager get eventsRefs {
    final manager = $$EventsTableTableManager(
      $_db,
      $_db.events,
    ).filter((f) => f.actorId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_eventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PeopleTableFilterComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platformPersonId => $composableBuilder(
    column: $table.platformPersonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> eventsRefs(
    Expression<bool> Function($$EventsTableFilterComposer f) f,
  ) {
    final $$EventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.actorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableFilterComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PeopleTableOrderingComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platformPersonId => $composableBuilder(
    column: $table.platformPersonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeopleTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get platformPersonId => $composableBuilder(
    column: $table.platformPersonId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  Expression<T> eventsRefs<T extends Object>(
    Expression<T> Function($$EventsTableAnnotationComposer a) f,
  ) {
    final $$EventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.actorId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableAnnotationComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PeopleTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeopleTable,
          PeopleData,
          $$PeopleTableFilterComposer,
          $$PeopleTableOrderingComposer,
          $$PeopleTableAnnotationComposer,
          $$PeopleTableCreateCompanionBuilder,
          $$PeopleTableUpdateCompanionBuilder,
          (PeopleData, $$PeopleTableReferences),
          PeopleData,
          PrefetchHooks Function({bool eventsRefs})
        > {
  $$PeopleTableTableManager(_$AppDatabase db, $PeopleTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeopleTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeopleTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeopleTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<String?> platformPersonId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
              }) => PeopleCompanion(
                id: id,
                platform: platform,
                platformPersonId: platformPersonId,
                displayName: displayName,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String platform,
                Value<String?> platformPersonId = const Value.absent(),
                required String displayName,
              }) => PeopleCompanion.insert(
                id: id,
                platform: platform,
                platformPersonId: platformPersonId,
                displayName: displayName,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PeopleTable, PeopleData>(table),
                  $$PeopleTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({eventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (eventsRefs) db.events],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (eventsRefs)
                    await $_getPrefetchedDataByColumns<
                      PeopleData,
                      $PeopleTable,
                      Event,
                      $EventsTable
                    >(
                      currentTable: table,
                      referencedTable: $$PeopleTableReferences._eventsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$PeopleTableReferences(db, table, p0).eventsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'actor_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PeopleTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeopleTable,
      PeopleData,
      $$PeopleTableFilterComposer,
      $$PeopleTableOrderingComposer,
      $$PeopleTableAnnotationComposer,
      $$PeopleTableCreateCompanionBuilder,
      $$PeopleTableUpdateCompanionBuilder,
      (PeopleData, $$PeopleTableReferences),
      PeopleData,
      PrefetchHooks Function({bool eventsRefs})
    >;
typedef $$ConversationsTableCreateCompanionBuilder =
    ConversationsCompanion Function({
      Value<int> id,
      required int importId,
      Value<String?> sourceConversationId,
      Value<String?> title,
    });
typedef $$ConversationsTableUpdateCompanionBuilder =
    ConversationsCompanion Function({
      Value<int> id,
      Value<int> importId,
      Value<String?> sourceConversationId,
      Value<String?> title,
    });

final class $$ConversationsTableReferences
    extends BaseReferences<_$AppDatabase, $ConversationsTable, Conversation> {
  $$ConversationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ImportsTable _importIdTable(_$AppDatabase db) =>
      db.imports.createAlias('conversations__import_id__imports__id');

  $$ImportsTableProcessedTableManager get importId {
    final $_column = $_itemColumn<int>('import_id')!;

    final manager = $$ImportsTableTableManager(
      $_db,
      $_db.imports,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_importIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$EventsTable, List<Event>> _eventsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.events,
    aliasName: 'conversations__id__events__conversation_id',
  );

  $$EventsTableProcessedTableManager get eventsRefs {
    final manager = $$EventsTableTableManager(
      $_db,
      $_db.events,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_eventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceConversationId => $composableBuilder(
    column: $table.sourceConversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  $$ImportsTableFilterComposer get importId {
    final $$ImportsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importId,
      referencedTable: $db.imports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportsTableFilterComposer(
            $db: $db,
            $table: $db.imports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> eventsRefs(
    Expression<bool> Function($$EventsTableFilterComposer f) f,
  ) {
    final $$EventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableFilterComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceConversationId => $composableBuilder(
    column: $table.sourceConversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  $$ImportsTableOrderingComposer get importId {
    final $$ImportsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importId,
      referencedTable: $db.imports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportsTableOrderingComposer(
            $db: $db,
            $table: $db.imports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceConversationId => $composableBuilder(
    column: $table.sourceConversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  $$ImportsTableAnnotationComposer get importId {
    final $$ImportsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importId,
      referencedTable: $db.imports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportsTableAnnotationComposer(
            $db: $db,
            $table: $db.imports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> eventsRefs<T extends Object>(
    Expression<T> Function($$EventsTableAnnotationComposer a) f,
  ) {
    final $$EventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableAnnotationComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationsTable,
          Conversation,
          $$ConversationsTableFilterComposer,
          $$ConversationsTableOrderingComposer,
          $$ConversationsTableAnnotationComposer,
          $$ConversationsTableCreateCompanionBuilder,
          $$ConversationsTableUpdateCompanionBuilder,
          (Conversation, $$ConversationsTableReferences),
          Conversation,
          PrefetchHooks Function({bool importId, bool eventsRefs})
        > {
  $$ConversationsTableTableManager(_$AppDatabase db, $ConversationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> importId = const Value.absent(),
                Value<String?> sourceConversationId = const Value.absent(),
                Value<String?> title = const Value.absent(),
              }) => ConversationsCompanion(
                id: id,
                importId: importId,
                sourceConversationId: sourceConversationId,
                title: title,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int importId,
                Value<String?> sourceConversationId = const Value.absent(),
                Value<String?> title = const Value.absent(),
              }) => ConversationsCompanion.insert(
                id: id,
                importId: importId,
                sourceConversationId: sourceConversationId,
                title: title,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConversationsTable, Conversation>(table),
                  $$ConversationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({importId = false, eventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (eventsRefs) db.events],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (importId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.importId,
                        referencedTable: $$ConversationsTableReferences
                            ._importIdTable(db),
                        referencedColumn: $$ConversationsTableReferences
                            ._importIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (eventsRefs)
                    await $_getPrefetchedDataByColumns<
                      Conversation,
                      $ConversationsTable,
                      Event,
                      $EventsTable
                    >(
                      currentTable: table,
                      referencedTable: $$ConversationsTableReferences
                          ._eventsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ConversationsTableReferences(
                            db,
                            table,
                            p0,
                          ).eventsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'conversation_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationsTable,
      Conversation,
      $$ConversationsTableFilterComposer,
      $$ConversationsTableOrderingComposer,
      $$ConversationsTableAnnotationComposer,
      $$ConversationsTableCreateCompanionBuilder,
      $$ConversationsTableUpdateCompanionBuilder,
      (Conversation, $$ConversationsTableReferences),
      Conversation,
      PrefetchHooks Function({bool importId, bool eventsRefs})
    >;
typedef $$EventsTableCreateCompanionBuilder = EventsCompanion Function({
  Value<int> id,
  required int importId,
  required int sourceFileId,
  required String sourceLocator,
  required String platform,
  required String eventType,
  Value<String?> timestampRaw,
  Value<DateTime?> timestampNormalized,
  required TimezoneStatus timezoneStatus,
  Value<int?> actorId,
  Value<int?> conversationId,
  Value<String?> textContent,
  Value<String?> metadataJson,
});
typedef $$EventsTableUpdateCompanionBuilder = EventsCompanion Function({
  Value<int> id,
  Value<int> importId,
  Value<int> sourceFileId,
  Value<String> sourceLocator,
  Value<String> platform,
  Value<String> eventType,
  Value<String?> timestampRaw,
  Value<DateTime?> timestampNormalized,
  Value<TimezoneStatus> timezoneStatus,
  Value<int?> actorId,
  Value<int?> conversationId,
  Value<String?> textContent,
  Value<String?> metadataJson,
});

final class $$EventsTableReferences
    extends BaseReferences<_$AppDatabase, $EventsTable, Event> {
  $$EventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ImportsTable _importIdTable(_$AppDatabase db) =>
      db.imports.createAlias('events__import_id__imports__id');

  $$ImportsTableProcessedTableManager get importId {
    final $_column = $_itemColumn<int>('import_id')!;

    final manager = $$ImportsTableTableManager(
      $_db,
      $_db.imports,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_importIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SourceFilesTable _sourceFileIdTable(_$AppDatabase db) =>
      db.sourceFiles.createAlias('events__source_file_id__source_files__id');

  $$SourceFilesTableProcessedTableManager get sourceFileId {
    final $_column = $_itemColumn<int>('source_file_id')!;

    final manager = $$SourceFilesTableTableManager(
      $_db,
      $_db.sourceFiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceFileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PeopleTable _actorIdTable(_$AppDatabase db) =>
      db.people.createAlias('events__actor_id__people__id');

  $$PeopleTableProcessedTableManager? get actorId {
    final $_column = $_itemColumn<int>('actor_id');
    if ($_column == null) return null;
    final manager = $$PeopleTableTableManager(
      $_db,
      $_db.people,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_actorIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ConversationsTable _conversationIdTable(_$AppDatabase db) => db
      .conversations
      .createAlias('events__conversation_id__conversations__id');

  $$ConversationsTableProcessedTableManager? get conversationId {
    final $_column = $_itemColumn<int>('conversation_id');
    if ($_column == null) return null;
    final manager = $$ConversationsTableTableManager(
      $_db,
      $_db.conversations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AttachmentsTable, List<Attachment>>
  _attachmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.attachments,
    aliasName: 'events__id__attachments__event_id',
  );

  $$AttachmentsTableProcessedTableManager get attachmentsRefs {
    final manager = $$AttachmentsTableTableManager(
      $_db,
      $_db.attachments,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_attachmentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EventEmbeddingsTable, List<EventEmbedding>>
  _eventEmbeddingsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.eventEmbeddings,
    aliasName: 'events__id__event_embeddings__event_id',
  );

  $$EventEmbeddingsTableProcessedTableManager get eventEmbeddingsRefs {
    final manager = $$EventEmbeddingsTableTableManager(
      $_db,
      $_db.eventEmbeddings,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _eventEmbeddingsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EventsTableFilterComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceLocator => $composableBuilder(
    column: $table.sourceLocator,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timestampRaw => $composableBuilder(
    column: $table.timestampRaw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestampNormalized => $composableBuilder(
    column: $table.timestampNormalized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TimezoneStatus, TimezoneStatus, String>
  get timezoneStatus => $composableBuilder(
    column: $table.timezoneStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  $$ImportsTableFilterComposer get importId {
    final $$ImportsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importId,
      referencedTable: $db.imports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportsTableFilterComposer(
            $db: $db,
            $table: $db.imports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourceFilesTableFilterComposer get sourceFileId {
    final $$SourceFilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceFileId,
      referencedTable: $db.sourceFiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceFilesTableFilterComposer(
            $db: $db,
            $table: $db.sourceFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PeopleTableFilterComposer get actorId {
    final $$PeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.actorId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableFilterComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ConversationsTableFilterComposer get conversationId {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableFilterComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> attachmentsRefs(
    Expression<bool> Function($$AttachmentsTableFilterComposer f) f,
  ) {
    final $$AttachmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableFilterComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> eventEmbeddingsRefs(
    Expression<bool> Function($$EventEmbeddingsTableFilterComposer f) f,
  ) {
    final $$EventEmbeddingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.eventEmbeddings,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventEmbeddingsTableFilterComposer(
            $db: $db,
            $table: $db.eventEmbeddings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EventsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceLocator => $composableBuilder(
    column: $table.sourceLocator,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timestampRaw => $composableBuilder(
    column: $table.timestampRaw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestampNormalized => $composableBuilder(
    column: $table.timestampNormalized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timezoneStatus => $composableBuilder(
    column: $table.timezoneStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$ImportsTableOrderingComposer get importId {
    final $$ImportsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importId,
      referencedTable: $db.imports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportsTableOrderingComposer(
            $db: $db,
            $table: $db.imports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourceFilesTableOrderingComposer get sourceFileId {
    final $$SourceFilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceFileId,
      referencedTable: $db.sourceFiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceFilesTableOrderingComposer(
            $db: $db,
            $table: $db.sourceFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PeopleTableOrderingComposer get actorId {
    final $$PeopleTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.actorId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableOrderingComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ConversationsTableOrderingComposer get conversationId {
    final $$ConversationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableOrderingComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceLocator => $composableBuilder(
    column: $table.sourceLocator,
    builder: (column) => column,
  );

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get timestampRaw => $composableBuilder(
    column: $table.timestampRaw,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get timestampNormalized => $composableBuilder(
    column: $table.timestampNormalized,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TimezoneStatus, String> get timezoneStatus =>
      $composableBuilder(
        column: $table.timezoneStatus,
        builder: (column) => column,
      );

  GeneratedColumn<String> get textContent => $composableBuilder(
    column: $table.textContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  $$ImportsTableAnnotationComposer get importId {
    final $$ImportsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importId,
      referencedTable: $db.imports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportsTableAnnotationComposer(
            $db: $db,
            $table: $db.imports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourceFilesTableAnnotationComposer get sourceFileId {
    final $$SourceFilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceFileId,
      referencedTable: $db.sourceFiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceFilesTableAnnotationComposer(
            $db: $db,
            $table: $db.sourceFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PeopleTableAnnotationComposer get actorId {
    final $$PeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.actorId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ConversationsTableAnnotationComposer get conversationId {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableAnnotationComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> attachmentsRefs<T extends Object>(
    Expression<T> Function($$AttachmentsTableAnnotationComposer a) f,
  ) {
    final $$AttachmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.attachments,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AttachmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.attachments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> eventEmbeddingsRefs<T extends Object>(
    Expression<T> Function($$EventEmbeddingsTableAnnotationComposer a) f,
  ) {
    final $$EventEmbeddingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.eventEmbeddings,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventEmbeddingsTableAnnotationComposer(
            $db: $db,
            $table: $db.eventEmbeddings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventsTable,
          Event,
          $$EventsTableFilterComposer,
          $$EventsTableOrderingComposer,
          $$EventsTableAnnotationComposer,
          $$EventsTableCreateCompanionBuilder,
          $$EventsTableUpdateCompanionBuilder,
          (Event, $$EventsTableReferences),
          Event,
          PrefetchHooks Function({
            bool importId,
            bool sourceFileId,
            bool actorId,
            bool conversationId,
            bool attachmentsRefs,
            bool eventEmbeddingsRefs,
          })
        > {
  $$EventsTableTableManager(_$AppDatabase db, $EventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> importId = const Value.absent(),
                Value<int> sourceFileId = const Value.absent(),
                Value<String> sourceLocator = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String?> timestampRaw = const Value.absent(),
                Value<DateTime?> timestampNormalized = const Value.absent(),
                Value<TimezoneStatus> timezoneStatus = const Value.absent(),
                Value<int?> actorId = const Value.absent(),
                Value<int?> conversationId = const Value.absent(),
                Value<String?> textContent = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
              }) => EventsCompanion(
                id: id,
                importId: importId,
                sourceFileId: sourceFileId,
                sourceLocator: sourceLocator,
                platform: platform,
                eventType: eventType,
                timestampRaw: timestampRaw,
                timestampNormalized: timestampNormalized,
                timezoneStatus: timezoneStatus,
                actorId: actorId,
                conversationId: conversationId,
                textContent: textContent,
                metadataJson: metadataJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int importId,
                required int sourceFileId,
                required String sourceLocator,
                required String platform,
                required String eventType,
                Value<String?> timestampRaw = const Value.absent(),
                Value<DateTime?> timestampNormalized = const Value.absent(),
                required TimezoneStatus timezoneStatus,
                Value<int?> actorId = const Value.absent(),
                Value<int?> conversationId = const Value.absent(),
                Value<String?> textContent = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
              }) => EventsCompanion.insert(
                id: id,
                importId: importId,
                sourceFileId: sourceFileId,
                sourceLocator: sourceLocator,
                platform: platform,
                eventType: eventType,
                timestampRaw: timestampRaw,
                timestampNormalized: timestampNormalized,
                timezoneStatus: timezoneStatus,
                actorId: actorId,
                conversationId: conversationId,
                textContent: textContent,
                metadataJson: metadataJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EventsTable, Event>(table),
                  $$EventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                importId = false,
                sourceFileId = false,
                actorId = false,
                conversationId = false,
                attachmentsRefs = false,
                eventEmbeddingsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (attachmentsRefs) db.attachments,
                    if (eventEmbeddingsRefs) db.eventEmbeddings,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (importId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.importId,
                            referencedTable: $$EventsTableReferences
                                ._importIdTable(db),
                            referencedColumn: $$EventsTableReferences
                                ._importIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (sourceFileId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceFileId,
                            referencedTable: $$EventsTableReferences
                                ._sourceFileIdTable(db),
                            referencedColumn: $$EventsTableReferences
                                ._sourceFileIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (actorId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.actorId,
                            referencedTable: $$EventsTableReferences
                                ._actorIdTable(db),
                            referencedColumn: $$EventsTableReferences
                                ._actorIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (conversationId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.conversationId,
                            referencedTable: $$EventsTableReferences
                                ._conversationIdTable(db),
                            referencedColumn: $$EventsTableReferences
                                ._conversationIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (attachmentsRefs)
                        await $_getPrefetchedDataByColumns<
                          Event,
                          $EventsTable,
                          Attachment,
                          $AttachmentsTable
                        >(
                          currentTable: table,
                          referencedTable: $$EventsTableReferences
                              ._attachmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EventsTableReferences(
                                db,
                                table,
                                p0,
                              ).attachmentsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'event_id',
                          typedResults: items,
                        ),
                      if (eventEmbeddingsRefs)
                        await $_getPrefetchedDataByColumns<
                          Event,
                          $EventsTable,
                          EventEmbedding,
                          $EventEmbeddingsTable
                        >(
                          currentTable: table,
                          referencedTable: $$EventsTableReferences
                              ._eventEmbeddingsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EventsTableReferences(
                                db,
                                table,
                                p0,
                              ).eventEmbeddingsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'event_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$EventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventsTable,
      Event,
      $$EventsTableFilterComposer,
      $$EventsTableOrderingComposer,
      $$EventsTableAnnotationComposer,
      $$EventsTableCreateCompanionBuilder,
      $$EventsTableUpdateCompanionBuilder,
      (Event, $$EventsTableReferences),
      Event,
      PrefetchHooks Function({
        bool importId,
        bool sourceFileId,
        bool actorId,
        bool conversationId,
        bool attachmentsRefs,
        bool eventEmbeddingsRefs,
      })
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<int> id,
      Value<int?> eventId,
      required int sourceFileId,
      Value<String?> relativePath,
      required String mediaType,
      required int sizeBytes,
      Value<String?> contentHash,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<int> id,
      Value<int?> eventId,
      Value<int> sourceFileId,
      Value<String?> relativePath,
      Value<String> mediaType,
      Value<int> sizeBytes,
      Value<String?> contentHash,
    });

final class $$AttachmentsTableReferences
    extends BaseReferences<_$AppDatabase, $AttachmentsTable, Attachment> {
  $$AttachmentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EventsTable _eventIdTable(_$AppDatabase db) =>
      db.events.createAlias('attachments__event_id__events__id');

  $$EventsTableProcessedTableManager? get eventId {
    final $_column = $_itemColumn<int>('event_id');
    if ($_column == null) return null;
    final manager = $$EventsTableTableManager(
      $_db,
      $_db.events,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SourceFilesTable _sourceFileIdTable(_$AppDatabase db) => db
      .sourceFiles
      .createAlias('attachments__source_file_id__source_files__id');

  $$SourceFilesTableProcessedTableManager get sourceFileId {
    final $_column = $_itemColumn<int>('source_file_id')!;

    final manager = $$SourceFilesTableTableManager(
      $_db,
      $_db.sourceFiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceFileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  $$EventsTableFilterComposer get eventId {
    final $$EventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableFilterComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourceFilesTableFilterComposer get sourceFileId {
    final $$SourceFilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceFileId,
      referencedTable: $db.sourceFiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceFilesTableFilterComposer(
            $db: $db,
            $table: $db.sourceFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  $$EventsTableOrderingComposer get eventId {
    final $$EventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableOrderingComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourceFilesTableOrderingComposer get sourceFileId {
    final $$SourceFilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceFileId,
      referencedTable: $db.sourceFiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceFilesTableOrderingComposer(
            $db: $db,
            $table: $db.sourceFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  $$EventsTableAnnotationComposer get eventId {
    final $$EventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableAnnotationComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SourceFilesTableAnnotationComposer get sourceFileId {
    final $$SourceFilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceFileId,
      referencedTable: $db.sourceFiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SourceFilesTableAnnotationComposer(
            $db: $db,
            $table: $db.sourceFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttachmentsTable,
          Attachment,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (Attachment, $$AttachmentsTableReferences),
          Attachment,
          PrefetchHooks Function({bool eventId, bool sourceFileId})
        > {
  $$AttachmentsTableTableManager(_$AppDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> eventId = const Value.absent(),
                Value<int> sourceFileId = const Value.absent(),
                Value<String?> relativePath = const Value.absent(),
                Value<String> mediaType = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String?> contentHash = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                eventId: eventId,
                sourceFileId: sourceFileId,
                relativePath: relativePath,
                mediaType: mediaType,
                sizeBytes: sizeBytes,
                contentHash: contentHash,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> eventId = const Value.absent(),
                required int sourceFileId,
                Value<String?> relativePath = const Value.absent(),
                required String mediaType,
                required int sizeBytes,
                Value<String?> contentHash = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                eventId: eventId,
                sourceFileId: sourceFileId,
                relativePath: relativePath,
                mediaType: mediaType,
                sizeBytes: sizeBytes,
                contentHash: contentHash,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AttachmentsTable, Attachment>(table),
                  $$AttachmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({eventId = false, sourceFileId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (eventId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.eventId,
                        referencedTable: $$AttachmentsTableReferences
                            ._eventIdTable(db),
                        referencedColumn: $$AttachmentsTableReferences
                            ._eventIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (sourceFileId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sourceFileId,
                        referencedTable: $$AttachmentsTableReferences
                            ._sourceFileIdTable(db),
                        referencedColumn: $$AttachmentsTableReferences
                            ._sourceFileIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttachmentsTable,
      Attachment,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (Attachment, $$AttachmentsTableReferences),
      Attachment,
      PrefetchHooks Function({bool eventId, bool sourceFileId})
    >;
typedef $$EventEmbeddingsTableCreateCompanionBuilder =
    EventEmbeddingsCompanion Function({
      Value<int> eventId,
      required String modelId,
      required int dim,
      required Uint8List vector,
    });
typedef $$EventEmbeddingsTableUpdateCompanionBuilder =
    EventEmbeddingsCompanion Function({
      Value<int> eventId,
      Value<String> modelId,
      Value<int> dim,
      Value<Uint8List> vector,
    });

final class $$EventEmbeddingsTableReferences
    extends
        BaseReferences<_$AppDatabase, $EventEmbeddingsTable, EventEmbedding> {
  $$EventEmbeddingsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EventsTable _eventIdTable(_$AppDatabase db) =>
      db.events.createAlias('event_embeddings__event_id__events__id');

  $$EventsTableProcessedTableManager get eventId {
    final $_column = $_itemColumn<int>('event_id')!;

    final manager = $$EventsTableTableManager(
      $_db,
      $_db.events,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EventEmbeddingsTableFilterComposer
    extends Composer<_$AppDatabase, $EventEmbeddingsTable> {
  $$EventEmbeddingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dim => $composableBuilder(
    column: $table.dim,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get vector => $composableBuilder(
    column: $table.vector,
    builder: (column) => ColumnFilters(column),
  );

  $$EventsTableFilterComposer get eventId {
    final $$EventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableFilterComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EventEmbeddingsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventEmbeddingsTable> {
  $$EventEmbeddingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dim => $composableBuilder(
    column: $table.dim,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get vector => $composableBuilder(
    column: $table.vector,
    builder: (column) => ColumnOrderings(column),
  );

  $$EventsTableOrderingComposer get eventId {
    final $$EventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableOrderingComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EventEmbeddingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventEmbeddingsTable> {
  $$EventEmbeddingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<int> get dim =>
      $composableBuilder(column: $table.dim, builder: (column) => column);

  GeneratedColumn<Uint8List> get vector =>
      $composableBuilder(column: $table.vector, builder: (column) => column);

  $$EventsTableAnnotationComposer get eventId {
    final $$EventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.events,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsTableAnnotationComposer(
            $db: $db,
            $table: $db.events,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EventEmbeddingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventEmbeddingsTable,
          EventEmbedding,
          $$EventEmbeddingsTableFilterComposer,
          $$EventEmbeddingsTableOrderingComposer,
          $$EventEmbeddingsTableAnnotationComposer,
          $$EventEmbeddingsTableCreateCompanionBuilder,
          $$EventEmbeddingsTableUpdateCompanionBuilder,
          (EventEmbedding, $$EventEmbeddingsTableReferences),
          EventEmbedding,
          PrefetchHooks Function({bool eventId})
        > {
  $$EventEmbeddingsTableTableManager(
    _$AppDatabase db,
    $EventEmbeddingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventEmbeddingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventEmbeddingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventEmbeddingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> eventId = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<int> dim = const Value.absent(),
                Value<Uint8List> vector = const Value.absent(),
              }) => EventEmbeddingsCompanion(
                eventId: eventId,
                modelId: modelId,
                dim: dim,
                vector: vector,
              ),
          createCompanionCallback:
              ({
                Value<int> eventId = const Value.absent(),
                required String modelId,
                required int dim,
                required Uint8List vector,
              }) => EventEmbeddingsCompanion.insert(
                eventId: eventId,
                modelId: modelId,
                dim: dim,
                vector: vector,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EventEmbeddingsTable, EventEmbedding>(table),
                  $$EventEmbeddingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({eventId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (eventId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.eventId,
                        referencedTable: $$EventEmbeddingsTableReferences
                            ._eventIdTable(db),
                        referencedColumn: $$EventEmbeddingsTableReferences
                            ._eventIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EventEmbeddingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventEmbeddingsTable,
      EventEmbedding,
      $$EventEmbeddingsTableFilterComposer,
      $$EventEmbeddingsTableOrderingComposer,
      $$EventEmbeddingsTableAnnotationComposer,
      $$EventEmbeddingsTableCreateCompanionBuilder,
      $$EventEmbeddingsTableUpdateCompanionBuilder,
      (EventEmbedding, $$EventEmbeddingsTableReferences),
      EventEmbedding,
      PrefetchHooks Function({bool eventId})
    >;
typedef $$AiConsentsTableCreateCompanionBuilder = AiConsentsCompanion Function({
  Value<int> id,
  required String providerId,
  required String policyVersion,
  required String scopeSummary,
  required DateTime grantedAt,
  required int eventCount,
  required int byteCount,
});
typedef $$AiConsentsTableUpdateCompanionBuilder = AiConsentsCompanion Function({
  Value<int> id,
  Value<String> providerId,
  Value<String> policyVersion,
  Value<String> scopeSummary,
  Value<DateTime> grantedAt,
  Value<int> eventCount,
  Value<int> byteCount,
});

class $$AiConsentsTableFilterComposer
    extends Composer<_$AppDatabase, $AiConsentsTable> {
  $$AiConsentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get policyVersion => $composableBuilder(
    column: $table.policyVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeSummary => $composableBuilder(
    column: $table.scopeSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get grantedAt => $composableBuilder(
    column: $table.grantedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get eventCount => $composableBuilder(
    column: $table.eventCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteCount => $composableBuilder(
    column: $table.byteCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AiConsentsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiConsentsTable> {
  $$AiConsentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get policyVersion => $composableBuilder(
    column: $table.policyVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeSummary => $composableBuilder(
    column: $table.scopeSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get grantedAt => $composableBuilder(
    column: $table.grantedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get eventCount => $composableBuilder(
    column: $table.eventCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteCount => $composableBuilder(
    column: $table.byteCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AiConsentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiConsentsTable> {
  $$AiConsentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get policyVersion => $composableBuilder(
    column: $table.policyVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scopeSummary => $composableBuilder(
    column: $table.scopeSummary,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get grantedAt =>
      $composableBuilder(column: $table.grantedAt, builder: (column) => column);

  GeneratedColumn<int> get eventCount => $composableBuilder(
    column: $table.eventCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get byteCount =>
      $composableBuilder(column: $table.byteCount, builder: (column) => column);
}

class $$AiConsentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AiConsentsTable,
          AiConsent,
          $$AiConsentsTableFilterComposer,
          $$AiConsentsTableOrderingComposer,
          $$AiConsentsTableAnnotationComposer,
          $$AiConsentsTableCreateCompanionBuilder,
          $$AiConsentsTableUpdateCompanionBuilder,
          (
            AiConsent,
            BaseReferences<_$AppDatabase, $AiConsentsTable, AiConsent>,
          ),
          AiConsent,
          PrefetchHooks Function()
        > {
  $$AiConsentsTableTableManager(_$AppDatabase db, $AiConsentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiConsentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiConsentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiConsentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> policyVersion = const Value.absent(),
                Value<String> scopeSummary = const Value.absent(),
                Value<DateTime> grantedAt = const Value.absent(),
                Value<int> eventCount = const Value.absent(),
                Value<int> byteCount = const Value.absent(),
              }) => AiConsentsCompanion(
                id: id,
                providerId: providerId,
                policyVersion: policyVersion,
                scopeSummary: scopeSummary,
                grantedAt: grantedAt,
                eventCount: eventCount,
                byteCount: byteCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String providerId,
                required String policyVersion,
                required String scopeSummary,
                required DateTime grantedAt,
                required int eventCount,
                required int byteCount,
              }) => AiConsentsCompanion.insert(
                id: id,
                providerId: providerId,
                policyVersion: policyVersion,
                scopeSummary: scopeSummary,
                grantedAt: grantedAt,
                eventCount: eventCount,
                byteCount: byteCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AiConsentsTable, AiConsent>(table),
                  BaseReferences<_$AppDatabase, $AiConsentsTable, AiConsent>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AiConsentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AiConsentsTable,
      AiConsent,
      $$AiConsentsTableFilterComposer,
      $$AiConsentsTableOrderingComposer,
      $$AiConsentsTableAnnotationComposer,
      $$AiConsentsTableCreateCompanionBuilder,
      $$AiConsentsTableUpdateCompanionBuilder,
      (AiConsent, BaseReferences<_$AppDatabase, $AiConsentsTable, AiConsent>),
      AiConsent,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ImportsTableTableManager get imports =>
      $$ImportsTableTableManager(_db, _db.imports);
  $$SourceFilesTableTableManager get sourceFiles =>
      $$SourceFilesTableTableManager(_db, _db.sourceFiles);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db, _db.people);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
  $$EventEmbeddingsTableTableManager get eventEmbeddings =>
      $$EventEmbeddingsTableTableManager(_db, _db.eventEmbeddings);
  $$AiConsentsTableTableManager get aiConsents =>
      $$AiConsentsTableTableManager(_db, _db.aiConsents);
}
