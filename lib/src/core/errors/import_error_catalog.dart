/// Severity of a reported import issue, for ordering and styling.
enum ImportErrorSeverity { info, warning, error }

/// One catalog entry: a stable code plus the text a user may see.
///
/// Codes are content-free and never carry a path, an exception message or file
/// text, so an entry can be shown, logged or stored safely.
class ImportErrorEntry {
  const ImportErrorEntry({
    required this.code,
    required this.messageEn,
    required this.messageAr,
    required this.actionEn,
    required this.actionAr,
    required this.severity,
    this.aliases = const {},
  });

  final String code;
  final String messageEn;
  final String messageAr;

  /// What the user can do about it, in both supported languages.
  final String actionEn;
  final String actionAr;

  final ImportErrorSeverity severity;

  /// Older or alternate spellings of the same condition that may still be
  /// stored or reported. They resolve to this entry, never to a second one.
  final Set<String> aliases;
}

/// The single registry of import error codes.
///
/// Every code the inspector, importer and coordinator can throw or report is
/// declared here, so no free-form string reaches storage or the screen. A code
/// that is not in the catalog resolves to [unknownError], whose message is
/// generic and never includes exception text.
abstract final class ImportErrorCatalog {
  static final ImportErrorEntry unknownError = const ImportErrorEntry(
    code: 'unknown_error',
    messageEn: 'An unexpected error occurred during the import.',
    messageAr: 'حدث خطأ غير متوقع أثناء الاستيراد.',
    actionEn: 'Try the import again with a fresh export archive.',
    actionAr: 'أعد الاستيراد باستخدام أرشيف تصدير جديد.',
    severity: ImportErrorSeverity.error,
  );

  /// Codes used by the importer's per-file families, generated so their four
  /// variants stay consistent.
  static final List<ImportErrorEntry> _fileFamilies = [
    for (final (fileKind, recordKind, ar) in const [
      ('message', 'message', 'الرسائل'),
      ('comments', 'comment', 'التعليقات'),
      ('reactions', 'reaction', 'التفاعلات'),
      ('posts', 'post', 'المنشورات'),
    ]) ...[
      ImportErrorEntry(
        code: 'malformed_${fileKind}_json',
        messageEn: 'The export\'s $fileKind file is not valid JSON.',
        messageAr: 'ملف $ar في التصدير ليس JSON صالحًا.',
        actionEn: 'Export the archive again from Facebook.',
        actionAr: 'أعد تصدير الأرشيف من فيسبوك.',
        severity: ImportErrorSeverity.warning,
      ),
      ImportErrorEntry(
        code: 'unsupported_${fileKind}_json',
        messageEn: 'The export\'s $fileKind file is not a supported shape.',
        messageAr: 'ملف $ar في التصدير بصيغة غير مدعومة.',
        actionEn: 'Update the app or skip this file; other files still import.',
        actionAr: 'حدّث التطبيق أو تجاهل هذا الملف؛ تُستورد بقية الملفات.',
        severity: ImportErrorSeverity.warning,
      ),
      ImportErrorEntry(
        code: 'invalid_${recordKind}_record',
        messageEn:
            'Some $recordKind entries could not be read and were skipped.',
        messageAr: 'تعذّرت قراءة بعض عناصر $ar وتم تخطيها.',
        actionEn: 'Check the import report; nothing was guessed.',
        actionAr: 'راجع تقرير الاستيراد؛ لم يُخمَّن أي شيء.',
        severity: ImportErrorSeverity.warning,
      ),
      ImportErrorEntry(
        code: 'invalid_${recordKind}_timestamp',
        messageEn:
            'Some $recordKind timestamps were out of the supported range.',
        messageAr: 'بعض طوابع وقت $ar خارج النطاق المدعوم.',
        actionEn: 'Those timestamps were left empty rather than guessed.',
        actionAr: 'تُركت تلك الطوابع فارغة بدل تخمينها.',
        severity: ImportErrorSeverity.warning,
      ),
    ],
  ];

  static final List<ImportErrorEntry> entries = [
    ..._fileFamilies,
    const ImportErrorEntry(
      code: 'archive_invalid',
      messageEn: 'The selected file is not a supported, intact ZIP archive.',
      messageAr: 'الملف المحدد ليس أرشيف ZIP سليمًا ومدعومًا.',
      actionEn: 'Choose the ZIP archive produced by Facebook.',
      actionAr: 'اختر أرشيف ZIP الذي أنشأه فيسبوك.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'invalid_archive',
      messageEn: 'The archive is not readable or is not an intact ZIP.',
      messageAr: 'الأرشيف غير قابل للقراءة أو ليس ZIP سليمًا.',
      actionEn: 'Export the archive again from Facebook.',
      actionAr: 'أعد تصدير الأرشيف من فيسبوك.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'archive_corrupt',
      messageEn: 'A file inside the archive did not match its declared size.',
      messageAr: 'ملف داخل الأرشيف لا يطابق حجمه المعلن.',
      actionEn: 'Export the archive again and retry.',
      actionAr: 'أعد تصدير الأرشيف ثم حاول مجددًا.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'archive_changed',
      messageEn: 'The archive changed while it was being read.',
      messageAr: 'تغيّر الأرشيف أثناء قراءته.',
      actionEn: 'Close other programs using the file and try again.',
      actionAr: 'أغلق البرامج الأخرى التي تستخدم الملف ثم حاول مجددًا.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'archive_empty',
      messageEn: 'The selected file is empty.',
      messageAr: 'الملف المحدد فارغ.',
      actionEn: 'Choose the export folder or a complete archive.',
      actionAr: 'اختر مجلد التصدير أو أرشيفًا كاملًا.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'folder_unreadable',
      messageEn: 'A file in the selected folder could not be read.',
      messageAr: 'تعذّرت قراءة أحد ملفات المجلد المحدد.',
      actionEn: 'Check the folder permissions, then choose it again.',
      actionAr: 'تحقّق من صلاحيات المجلد ثم اختره مرة أخرى.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'archive_unreadable',
      messageEn: 'The selected archive could not be opened.',
      messageAr: 'تعذّر فتح الأرشيف المحدد.',
      actionEn: 'Check that the file still exists and is not open elsewhere.',
      actionAr: 'تأكّد أن الملف موجود وأنه غير مفتوح في برنامج آخر.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'archive_encrypted',
      messageEn: 'The archive is password protected.',
      messageAr: 'الأرشيف محمي بكلمة سر.',
      actionEn: 'Export the archive again without a password.',
      actionAr: 'أعد تصدير الأرشيف بدون كلمة سر.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'archive_size_limit',
      messageEn: 'The archive is larger than the supported size.',
      messageAr: 'الأرشيف أكبر من الحجم المدعوم.',
      actionEn: 'Extract the archive and choose the folder instead.',
      actionAr: 'استخرج الأرشيف واختر المجلد بدلًا منه.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'path_traversal',
      messageEn: 'A file path tries to leave the archive folder.',
      messageAr: 'مسار ملف يحاول الخروج من مجلد الأرشيف.',
      actionEn: 'Do not modify the export; export it again from Facebook.',
      actionAr: 'لا تعدّل التصدير؛ أعد تصديره من فيسبوك.',
      severity: ImportErrorSeverity.error,
      aliases: {'path_escape'},
    ),
    const ImportErrorEntry(
      code: 'absolute_entry_path',
      messageEn: 'A file path is absolute instead of archive-relative.',
      messageAr: 'مسار ملف مطلق بدل أن يكون داخل الأرشيف.',
      actionEn: 'Export the archive again; it was modified.',
      actionAr: 'أعد تصدير الأرشيف؛ فقد تم تعديله.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'invalid_entry_path',
      messageEn: 'A file path in the archive is invalid or ambiguous.',
      messageAr: 'مسار ملف في الأرشيف غير صالح أو ملتبس.',
      actionEn: 'Export the archive again; it was modified.',
      actionAr: 'أعد تصدير الأرشيف؛ فقد تم تعديله.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'symbolic_link_rejected',
      messageEn:
          'The archive contains symbolic links, which are not supported.',
      messageAr: 'الأرشيف يحتوي روابط رمزية غير مدعومة.',
      actionEn: 'Export the archive again without links.',
      actionAr: 'أعد تصدير الأرشيف بدون روابط.',
      severity: ImportErrorSeverity.error,
      aliases: {'symlink_entry'},
    ),
    const ImportErrorEntry(
      code: 'duplicate_entry',
      messageEn: 'The archive contains duplicate or ambiguous file paths.',
      messageAr: 'الأرشيف يحتوي مسارات ملفات مكررة أو ملتبسة.',
      actionEn: 'Export the archive again from Facebook.',
      actionAr: 'أعد تصدير الأرشيف من فيسبوك.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'entry_count_limit',
      messageEn: 'The archive contains more files than the supported limit.',
      messageAr: 'الأرشيف يحتوي ملفات أكثر من الحد المدعوم.',
      actionEn: 'Import a smaller date range.',
      actionAr: 'استورد نطاقًا زمنيًا أصغر.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'entry_size_limit',
      messageEn: 'A file inside the archive is larger than the supported size.',
      messageAr: 'ملف داخل الأرشيف أكبر من الحجم المدعوم.',
      actionEn: 'Import a smaller date range.',
      actionAr: 'استورد نطاقًا زمنيًا أصغر.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'expanded_size_limit',
      messageEn: 'The archive expands to more data than the supported total.',
      messageAr: 'الأرشيف يتضمن بيانات أكبر من الإجمالي المدعوم.',
      actionEn: 'Import a smaller date range.',
      actionAr: 'استورد نطاقًا زمنيًا أصغر.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'json_file_size_limit',
      messageEn: 'A supported JSON file is larger than the read limit.',
      messageAr: 'ملف JSON مدعوم أكبر من حد القراءة.',
      actionEn: 'Import a smaller date range.',
      actionAr: 'استورد نطاقًا زمنيًا أصغر.',
      severity: ImportErrorSeverity.error,
      aliases: {'payload_size_limit'},
    ),
    const ImportErrorEntry(
      code: 'json_payload_size_limit',
      messageEn: 'The supported JSON files together exceed the read limit.',
      messageAr: 'ملفات JSON المدعومة تتجاوز حد القراءة الإجمالي.',
      actionEn: 'Import a smaller date range.',
      actionAr: 'استورد نطاقًا زمنيًا أصغر.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'json_too_deep',
      messageEn: 'A JSON file is nested more deeply than the supported limit.',
      messageAr: 'ملف JSON متداخل أعمق من الحد المدعوم.',
      actionEn: 'Update the app; nothing was imported from that file.',
      actionAr: 'حدّث التطبيق؛ لم يُستورد شيء من ذلك الملف.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'invalid_json_path_filter',
      messageEn: 'The requested supported-file filter is invalid.',
      messageAr: 'مرشّح الملفات المدعومة المطلوب غير صالح.',
      actionEn: 'This is an app problem; update the app.',
      actionAr: 'هذه مشكلة في التطبيق؛ حدّثه.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'attachment_path_rejected',
      messageEn:
          'A media reference points outside the archive and was skipped.',
      messageAr: 'إشارة وسائط تشير إلى خارج الأرشيف وتم تخطيها.',
      actionEn: 'Export the archive again; other files still import.',
      actionAr: 'أعد تصدير الأرشيف؛ تُستورد بقية الملفات.',
      severity: ImportErrorSeverity.warning,
    ),
    const ImportErrorEntry(
      code: 'attachment_missing',
      messageEn: 'A referenced media file is missing from the archive.',
      messageAr: 'ملف وسائط مشار إليه مفقود من الأرشيف.',
      actionEn: 'Export the archive again with media included.',
      actionAr: 'أعد تصدير الأرشيف مع تضمين الوسائط.',
      severity: ImportErrorSeverity.warning,
    ),
    const ImportErrorEntry(
      code: 'attachment_hash_size_limit',
      messageEn:
          'A media file was too large to hash; only its metadata was kept.',
      messageAr: 'ملف وسائط أكبر من حد التجزئة؛ حُفظت بياناته الوصفية فقط.',
      actionEn: 'This does not affect the imported records.',
      actionAr: 'لا يؤثر ذلك على السجلات المستوردة.',
      severity: ImportErrorSeverity.warning,
    ),
    const ImportErrorEntry(
      code: 'attachment_count_limit',
      messageEn: 'A record references more media files than are supported.',
      messageAr: 'سجل يشير إلى ملفات وسائط أكثر من المدعوم.',
      actionEn: 'The extra references were skipped, not guessed.',
      actionAr: 'تم تخطي الإشارات الزائدة دون تخمين.',
      severity: ImportErrorSeverity.warning,
    ),
    const ImportErrorEntry(
      code: 'no_supported_files_found',
      messageEn: 'No supported files were found in the archive.',
      messageAr: 'لم تُعثر على ملفات مدعومة في الأرشيف.',
      actionEn: 'Check that the archive is a full Facebook export.',
      actionAr: 'تأكد أن الأرشيف تصدير كامل من فيسبوك.',
      severity: ImportErrorSeverity.warning,
    ),
    const ImportErrorEntry(
      code: 'unsupported_json_files_present',
      messageEn:
          'Some JSON files in the archive are not supported and were skipped.',
      messageAr: 'بعض ملفات JSON في الأرشيف غير مدعومة وتم تخطيها.',
      actionEn: 'Those files were left out; nothing was guessed.',
      actionAr: 'تم استبعاد تلك الملفات دون تخمين.',
      severity: ImportErrorSeverity.info,
    ),
    const ImportErrorEntry(
      code: 'known_folders_not_imported',
      messageEn:
          'Some files are in known Facebook folders that are not imported yet.',
      messageAr: 'بعض الملفات في مجلدات فيسبوك معروفة لم تُستورد بعد.',
      actionEn: 'They stay untouched in the archive; nothing was guessed.',
      actionAr: 'تبقى كما هي في الأرشيف دون تخمين.',
      severity: ImportErrorSeverity.info,
    ),
    const ImportErrorEntry(
      code: 'known_not_imported',
      messageEn: 'A file in a known Facebook folder is not imported yet.',
      messageAr: 'ملف في مجلد فيسبوك معروف لم يُستورد بعد.',
      actionEn: 'It is reported by category, not treated as unknown.',
      actionAr: 'يُبلَّغ عنه ضمن فئته ولا يُعدّ مجهولاً.',
      severity: ImportErrorSeverity.info,
    ),
    const ImportErrorEntry(
      code: 'no_json_files',
      messageEn: 'The archive contains no JSON files.',
      messageAr: 'الأرشيف لا يحتوي ملفات JSON.',
      actionEn: 'Check that the archive is a full Facebook export.',
      actionAr: 'تأكد أن الأرشيف تصدير كامل من فيسبوك.',
      severity: ImportErrorSeverity.warning,
    ),
    const ImportErrorEntry(
      code: 'unsupported_files_present',
      messageEn: 'Some files in the archive are not supported.',
      messageAr: 'بعض ملفات الأرشيف غير مدعومة.',
      actionEn: 'They were counted, not imported.',
      actionAr: 'تم إحصاؤها دون استيرادها.',
      severity: ImportErrorSeverity.info,
    ),
    const ImportErrorEntry(
      code: 'malformed_json',
      messageEn: 'A JSON file could not be read.',
      messageAr: 'تعذّرت قراءة ملف JSON.',
      actionEn: 'Export the archive again from Facebook.',
      actionAr: 'أعد تصدير الأرشيف من فيسبوك.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'unsupported_json_shape',
      messageEn: 'A JSON file has a shape this version does not support.',
      messageAr: 'ملف JSON بصيغة لا يدعمها هذا الإصدار.',
      actionEn: 'Update the app or import the file later.',
      actionAr: 'حدّث التطبيق أو استورد الملف لاحقًا.',
      severity: ImportErrorSeverity.warning,
    ),
    const ImportErrorEntry(
      code: 'unsupported_media',
      messageEn: 'A media file was reported but not parsed.',
      messageAr: 'تم الإبلاغ عن ملف وسائط دون تحليله.',
      actionEn: 'Media stays inside the archive and is not copied.',
      actionAr: 'تبقى الوسائط داخل الأرشيف ولا تُنسخ.',
      severity: ImportErrorSeverity.info,
    ),
    const ImportErrorEntry(
      code: 'unknown_extension',
      messageEn: 'A file type in the archive is not supported.',
      messageAr: 'نوع ملف في الأرشيف غير مدعوم.',
      actionEn: 'It was counted, not imported.',
      actionAr: 'تم إحصاؤه دون استيراده.',
      severity: ImportErrorSeverity.info,
    ),
    const ImportErrorEntry(
      code: 'blocked_unsafe_path',
      messageEn: 'The archive was blocked because a path inside it is unsafe.',
      messageAr: 'تم حظر الأرشيف لأن أحد مساراته غير آمن.',
      actionEn: 'Export the archive again from Facebook; it was modified.',
      actionAr: 'أعد تصدير الأرشيف من فيسبوك؛ فقد تم تعديله.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'oversized_archive',
      messageEn: 'The archive exceeded a configured size or count limit.',
      messageAr: 'الأرشيف تجاوز حدًا للحجم أو العدد.',
      actionEn: 'Import a smaller date range.',
      actionAr: 'استورد نطاقًا زمنيًا أصغر.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'record_count_limit',
      messageEn: 'The archive holds more records than the import limit.',
      messageAr: 'الأرشيف يحتوي سجلات أكثر من حد الاستيراد.',
      actionEn: 'Import a smaller date range.',
      actionAr: 'استورد نطاقًا زمنيًا أصغر.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'import_write_failed',
      messageEn: 'The import could not be saved; nothing was written.',
      messageAr: 'تعذّر حفظ الاستيراد؛ لم يُكتب أي شيء.',
      actionEn: 'Retry the import.',
      actionAr: 'أعد محاولة الاستيراد.',
      severity: ImportErrorSeverity.error,
    ),
    // The write phase names what failed instead of reporting one opaque code:
    // a 139k-record import used to fail as "it did not save" with no reason.
    const ImportErrorEntry(
      code: 'import_write_invalid_value',
      messageEn: 'A record holds a value the local database cannot store.',
      messageAr: 'يوجد سجل يحتوي قيمة لا يمكن لقاعدة البيانات المحلية تخزينها.',
      actionEn: 'Report this on the project issues page with the record count.',
      actionAr: 'أبلغ عن هذا في صفحة مشاكل المشروع مع عدد السجلات.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'import_write_conflict',
      messageEn: 'Two records claim the same position in the export.',
      messageAr: 'سجلان يدّعيان الموقع نفسه في التصدير.',
      actionEn: 'Report this on the project issues page; nothing was saved.',
      actionAr: 'أبلغ عن هذا في صفحة مشاكل المشروع؛ لم يُحفظ شيء.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'import_write_busy',
      messageEn: 'The local database was busy with another task.',
      messageAr: 'قاعدة البيانات المحلية كانت مشغولة بمهمة أخرى.',
      actionEn: 'Close other windows of the app and import again.',
      actionAr: 'أغلق بقية نوافذ التطبيق ثم أعد الاستيراد.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'import_disk_full',
      messageEn: 'There is not enough free space to store the import.',
      messageAr: 'لا توجد مساحة كافية لتخزين الاستيراد.',
      actionEn: 'Free up disk space, then import again.',
      actionAr: 'أفرغ مساحة على القرص ثم أعد الاستيراد.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'import_write_io_error',
      messageEn: 'The import could not be written to the local workspace.',
      messageAr: 'تعذّرت كتابة الاستيراد في مساحة العمل المحلية.',
      actionEn: 'Check the workspace folder permissions, then retry.',
      actionAr: 'تحقّق من صلاحيات مجلد مساحة العمل ثم حاول مجددًا.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'record_exceeds_column_limit',
      messageEn:
          'Some records hold values too large to store and were skipped.',
      messageAr: 'بعض السجلات تحتوي قيمًا أكبر من أن تُخزَّن وتم تخطيها.',
      actionEn: 'The rest of the archive still imported.',
      actionAr: 'بقية الأرشيف استُوردت.',
      severity: ImportErrorSeverity.info,
    ),
    // Names the file, field and violated bound of one skipped record. The
    // value itself is never part of the warning.
    const ImportErrorEntry(
      code: 'import_record_skipped',
      messageEn: 'A record could not be stored and was skipped.',
      messageAr: 'تعذّر تخزين أحد السجلات وتم تخطيه.',
      actionEn: 'The rest of the archive still imported.',
      actionAr: 'بقية الأرشيف استُوردت.',
      severity: ImportErrorSeverity.info,
    ),
    const ImportErrorEntry(
      code: 'record_without_source_file',
      messageEn: 'Some records could not be linked to their source file.',
      messageAr: 'تعذّر ربط بعض السجلات بملف مصدرها.',
      actionEn: 'They were skipped; the rest of the archive still imported.',
      actionAr: 'تم تخطيها؛ وبقية الأرشيف استُوردت.',
      severity: ImportErrorSeverity.info,
    ),
    const ImportErrorEntry(
      code: 'import_unexpected_failed',
      messageEn: 'The import stopped before it could read the selected source.',
      messageAr: 'توقّف الاستيراد قبل أن يتمكن من قراءة المصدر المحدَّد.',
      actionEn: 'Check that the export file still exists, then try again.',
      actionAr: 'تأكّد من أن ملف التصدير ما زال موجودًا، ثم حاول مجددًا.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'consent_required',
      messageEn: 'Explicit consent is required before any data can be sent.',
      messageAr: 'الموافقة الصريحة مطلوبة قبل إرسال أي بيانات.',
      actionEn: 'Review exactly what would be sent and grant consent first.',
      actionAr: 'راجع ما سيُرسل بالضبط وامنح الموافقة أولًا.',
      severity: ImportErrorSeverity.error,
    ),
    const ImportErrorEntry(
      code: 'cancelled',
      messageEn: 'The import was cancelled; nothing was written.',
      messageAr: 'تم إلغاء الاستيراد؛ لم يُكتب أي شيء.',
      actionEn: 'Start the import again when ready.',
      actionAr: 'ابدأ الاستيراد مجددًا عند الجاهزية.',
      severity: ImportErrorSeverity.info,
    ),
    unknownError,
  ];

  static final Map<String, ImportErrorEntry> _byCode = {
    for (final entry in entries) ...{
      entry.code: entry,
      for (final alias in entry.aliases) alias: entry,
    },
  };

  /// The catalog entry for [code], including aliases, or null.
  static ImportErrorEntry? byCode(String? code) =>
      code == null ? null : _byCode[code];

  /// The entry for [code], falling back to [unknownError] for an unknown or
  /// null code. Never throws and never echoes the input.
  static ImportErrorEntry lookup(String? code) => byCode(code) ?? unknownError;

  /// Every primary code, for validation and tests.
  static Set<String> get codes => {for (final entry in entries) entry.code};
}
