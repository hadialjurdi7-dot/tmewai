# نموذج البيانات ومسار الاستيراد

## 1. الغرض

تعريف حد فاصل بين صيغ المنصات المختلفة وبين ميزات البحث/Timeline/Agent. كل importer يحول ملف مصدر إلى سجل داخلي موحّد مع معلومات provenance كافية للرجوع للمصدر وعدم عرض استنتاج وكأنه حقيقة أصلية.

## 2. نموذج المجال

### ImportBatch

- `id`: UUID محلي.
- `platform`: قيمة enum مع namespace.
- `format`: مثل `facebook_json`، لا نخمن الامتداد وحده.
- `sourceFingerprint`: بصمة أرشيف/مجموعة ملفات، لا تحفظ محتوى الملف.
- `createdAt`, `finishedAt`.
- `status`: inspecting / importing / completed / completed_with_warnings / failed / cancelled.
- `importerVersion`, `appSchemaVersion`.
- counters وwarnings آمنة بلا نص خاص.

### SourceFile

- `id`, `importId`.
- `relativePath`: المسار داخل التصدير، بعد تطبيع آمن.
- `fileName`, `declaredType`, `detectedType`, `byteLength`, `sha256` اختياري.
- `parseStatus`, `errorCode`, `recordCount`.
- لا يحتفظ بمسار مطلق يكشف اسم حساب نظام المستخدم ضمن سجلات التحليلات.

### Person

- `id`, `platform`, `platformScopedId?`, `displayName`, `aliases?`.
- مفتاح الهوية محلي للنظام المصدر؛ لا ندمج حسب الاسم وحده.
- بيانات profiling مثل البريد/الهاتف لا تُخزن إلا إذا طلبت ميزة محددة ذلك وشرحت للمستخدم.

### Conversation

- `id`, `importId`, `sourceConversationId?`, `title?`, `participants` عبر جدول ربط.
- provenance إلى الملف/العنصر الذي بدأ منه.
- لا نعتبر عنوان المحادثة اسم شخص مؤكدًا.

### Event

- `id`, `importId`, `sourceFileId`, `sourceLocator`.
- `platform`, `eventType` (message/comment/reaction/post/follow/like/media_reference/other supported enum).
- `actorPersonId?`, `conversationId?`, `targetPersonId?`.
- `timestampRaw?`, `timestampUtc?`, `timezoneStatus` (utc/local/unknown/invalid).
- `text?`, `targetReference?`, `mediaAttachmentIds`.
- `metadata`: حقول normalized محدودة، لا dump JSON مفتوح غير محدود.
- المصدر لا يتغير؛ normalization حقل منفصل عنه.

### Attachment

- `id`, `sourceFileId`, `eventId?`, `relativePath`, `mediaType`, `length`, `hash?`, `availability`.
- الملف يبقى داخل workspace private، لا يوضع في مجلد public.
- V1 قد تعرض صورة/فيديو ضمن عارض محلي لاحقًا؛ لا يلزم تحليل المحتوى المرئي أو التعرف على الوجه.

### DerivedInsight / Evidence

- `id`, `scope`, `method`, `model?`, `createdAt`, `content`.
- `evidenceEventIds`, `timeRange`, `sampleCount`, `confidenceLabel`, `limitations`.
- مشتق قابل للحذف وإعادة الإنشاء؛ لا يُعامل كحدث أصلي.

## 3. JSON وSQLite

الحقول المهيكلة ذات الاستخدام المتكرر تكون أعمدة وعلاقات صريحة. يمكن حفظ metadata JSON فقط لمفاتيح allowlist وبيانات غير حرجة، مع حدود حجم/عمق. لا تخزن كامل الملف المصدر داخل صف قاعدة البيانات. حدّد مفاتيح foreign keys وunique constraints على platform-scoped source IDs عند توافرها.

### فهارس مقترحة

- `events(import_id, timestamp_utc)`
- `events(event_type, timestamp_utc)`
- `events(actor_person_id, timestamp_utc)`
- `events(conversation_id, timestamp_utc)`
- `source_files(import_id, relative_path)` unique بعد التطبيع
- FTS5 لنصوص الحدث والأسماء التي يسمح المستخدم بالبحث فيها.

عمليات إدخال الدفعة transactionized، وملفات الوسائط staged منفصلة حتى يكتمل التحقق. مع فشل transaction تُزال الملفات التي أنشأتها الدفعة ولا تُترك بيانات جزئية تبدو مكتملة.

## 4. الاستيراد من المصدر

1. **اختيار:** FilePicker يحدد ZIP أو مجلد.
2. **Inspection:** قراءة metadata مع حدود، وعدم كتابة أي شيء خارج staging.
3. **Manifest/report:** اكتشاف الملفات المعروفة عبر schema detector بإصدار محدد. أسماء الملفات وحدها مؤشر لا دليل نهائي.
4. **Consent:** يعرض أنواع الملفات، المساحة، وحدود النسخة المدعومة، ثم يوافق المستخدم.
5. **Decode:** معالجة على isolate/خلفية مناسبة حتى لا تتجمد الواجهة.
6. **Parse:** importer يقرأ JSON وفق schemas معروفة، يتحقق من الأنواع والحقول والحدود.
7. **Normalize:** تحويل الحقول إلى نماذج داخلية مع raw values/provenance.
8. **Persist:** transaction للأحداث والفهرس، staged media في مساحة خاصة.
9. **Summary:** counters دقيقة وتحذيرات ملفية، لا تخفي الخسائر.
10. **Cleanup:** تنظيف staging/bytes المؤقتة عند النجاح/الإلغاء/الفشل.

## 5. فاحص ZIP

مكتبة `archive` تفك المحتوى لكنها لا تضمن أن كل مدخل آمن لهدف التطبيق. لذلك:

- لا نستخرج تلقائيًا كل entries إلى مجلد عام أو مسار يحدده الأرشيف.
- رفض entry إذا كان absolute أو يحتوي traversal بعد canonicalization، أو يحاول تجاوز root.
- رفض symlink/hardlink في V1.
- حظر أسماء مكررة بعد تطبيع Unicode وفواصل المسارات.
- حد أعلى للحجم المضغوط، entries، حجم كل ملف مفكوك، ومجموع bytes الفعلي.
- لا نثق بحجم entry المكتوب داخل header وحده؛ نعد bytes الفعلية عند القراءة.
- حد عمق directory/path، حد طول اسم ومسار، وحد وقت تحليل.
- لا نفك archive داخل archive في V1.
- لا نفتح HTML أو PDF أو وسائط تلقائيًا في التطبيق أثناء التحليل.
- اختبار الملفات المفسدة وzip bombs والحقن في أسماء الملفات؛ فشل آمن برسالة عامة.

## 6. Facebook JSON importer — مواصفات أولية

لا نثبت schema قبل الحصول على عدة عينات مشروعة ومنزوعة الهوية. ملفات Facebook وتصديراته تتغير بحسب إعداد المستخدم والوقت. المُستورد يتبع هذا التصميم:

- **Schema detector:** يجمع أسماء الملفات/مفاتيح جذرية بشكل محدود، ويصنف known/unknown، ولا يطبع المحتوى الحساس.
- **Adapter per export version/shape:** لا تستخدم parser عريض يتسامح مع أي شكل ثم يسقط أخطاء.
- **Category mapping:** تربط كل فئة ملف بنوع أحداث موثق. إذا لم نعرف دلالة حقل، نحفظه ضمن تقرير عدم الدعم أو نرفضه بدل اختراع معنى.
- **Date normalization:** يحتفظ بالقيمة الأصلية؛ يحول إلى UTC فقط عندما تكون timezone/datum مفهومة. التاريخ المفقود يبقى null.
- **People mapping:** معرفات المنصة إن وجدت؛ الاسم لا يعتبر unique.
- **Text decoding:** unicode/RTL محفوظ، ولا نمرر النص لواجهة HTML غير منقاة.
- **Attachments:** نسجل metadata/reference؛ لا نقرأ محتوى الملف المرئي أو الصوتي للـAI في أول مرحلة.
- **Duplicates:** source locator/IDs/hash إذا توفر؛ الإعادة idempotent.

### معايير إدخال فئة جديدة

- وثيقة أو sample تصدير يثبت شكلها.
- fixture مرخصة ومنزوعة الهوية.
- اختبارات missing/null/wrong type/date/timezone/malformed.
- تقرير تغطية يبين الفئة المدعومة.
- مراجع المصدر لنتائج UI/Agent.

## 7. العقود بين importer وRepository

واجهة مفاهيمية (التنفيذ الفعلي يطابق أسلوب Dart بالمشروع):

```dart
abstract interface class PlatformImporter {
  String get platformId;
  Future<InspectionReport> inspect(ImportSource source, ImportLimits limits);
  Stream<ImportProgress> importInto(
    ImportSource source,
    DataRepository repository,
    ImportLimits limits,
    CancellationToken cancellation,
  );
}
```

`InspectionReport` لا يحتوي raw private text. `ImportProgress` stages/counters. `ImportFailure` يحمل safe code، file locator اختياري، ورسالة مترجمة لاحقًا. Cancellation يجب أن تُترجم إلى rollback/cleanup.

## 8. Fixtures ومصدرها

- استخدم data مصطنعة للبناء الأولي.
- إذا استخدم فريق التطوير exports حقيقية، أزل الأسماء والروابط والمعرفات والوسائط بعناية وتأكد من عدم إعادة التعرف، وخذ موافقة مالكها.
- لا تضع export ZIP أو database أو API response في GitHub/issues/CI artifacts.
- الاختبارات لا تحتاج شبكات ولا credentials.
