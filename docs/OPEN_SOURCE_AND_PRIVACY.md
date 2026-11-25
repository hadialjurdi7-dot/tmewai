# مشاريع مفتوحة المصدر والخصوصية

## 1. جدول دمج المرشحين

> تحقّق من الإصدار والرخصة والمنصات عند الإضافة. لا تُثبّت dependency لمجرد ظهورها في هذه القائمة؛ أضف أقل مجموعة لازمة للمرحلة الحالية.

| مشروع | الرخصة كما تظهر في المصدر | ماذا يقدم | كيف ندمجه | ما لا يقدمه |
|---|---|---|---|---|
| Flutter | BSD-style (تحقق من توزيع SDK ومكوناته) | واجهة وتطبيق Desktop | Flutter app؛ اختبر target OS لكل plugin | ليس Backend أو قاعدة بيانات بذاته. |
| flutter_riverpod / Riverpod | MIT | إدارة حالة وdependency injection | Providers للـrepositories وimport progress | ليس parser ولا تخزينًا. |
| Drift | MIT | ORM/SQL type-safe فوق SQLite وmigrations وreactive queries | DAOs وmigrations، وFTS5 من drift SQL | لا يشفر قاعدة البيانات تلقائيًا. |
| sqlite3 (Dart package) | MIT (تحقق من bundled/native components) | SQLite native API والبناء | backend لـDrift | يلزم التحقق من extensions والمكتبات المضمنة. |
| archive | MIT | قراءة ZIP وأنواع أرشيف أخرى | فحص entries ثم إرسال الملفات المدعومة للمحلل | لا يصمم أمان الاستيراد نيابة عنا. |
| file_picker | MIT | Native file/dialog picker | ZIP/folder selection | لا يتحقق من محتوى الملف. |
| path_provider | MIT | مسارات التطبيق الخاصة بالمنصة | Application Support data dir | لا يشفر ولا يحمي من مستخدم النظام. |
| flutter_secure_storage | MIT (تحقق من الإضافات الفرعية) | تخزين أسرار عبر OS keystore/keychain/keyring | تخزين database/API key بعد اختبار OS | لا يشفر DB/media؛ Linux قد يحتاج libsecret/keyring. |
| flutter_test / integration_test | جزء من Flutter SDK | unit/widget/integration tests | اختبار منطق وواجهة وOS حقيقي | mock لا يثبت تكامل المكونات الأصلية. |

رخصة التطبيق الرئيسي قرار مستقل عن رخصة المكتبات. استخدم ملفات الرخص الرسمية لكل إصدار وسجّلها في notices/SBOM عند التوزيع. لا تنقل نص رخصة أو علامة تجارية دون تدقيق.

## 2. مستندات تقنية أساسية

- Flutter Desktop: https://docs.flutter.dev/platform-integration/desktop
- Riverpod package: https://pub.dev/packages/flutter_riverpod
- Riverpod testing: https://riverpod.dev/docs/how_to/testing
- Drift: https://pub.dev/packages/drift
- Drift native backend: https://drift.simonbinder.eu/platforms/vm/
- Drift FTS5: https://drift.simonbinder.eu/sql_api/extensions/
- SQLite FTS5: https://sqlite.org/fts5.html
- archive: https://pub.dev/packages/archive
- file_picker: https://pub.dev/packages/file_picker
- path_provider: https://pub.dev/packages/path_provider
- flutter_secure_storage: https://pub.dev/packages/flutter_secure_storage

## 3. ZIP وأمان الملفات

- القراءة من الأرشيف لا تعني فكّه بأمان. لا تستخدم helper يستخرج كل الملفات دون التحقق من كل مسار وحجم ونوع.
- ارفض absolute paths، `..`، symlinks، أسماء مكررة أو التباس Unicode إن لم يكن لها معالجة واضحة.
- حدّد ميزانيات منفصلة لحجم الملف المضغوط، عدد entries، حجم entry غير المضغوط، والمجموع الكلي، مع عدّ الحجم الفعلي أثناء فك الضغط.
- احذر zip bombs والملفات المتداخلة/المفسدة وJSON شديد العمق أو الحجم.
- عدم تنفيذ الملفات المستوردة قاعدة ثابتة.
- إن لزم staging، يكون خاصًا بالتطبيق، مع صلاحيات محدودة، ويتم تنظيفه عند success/error/cancel.
- اختبر الهروب من المسار على Windows وLinux/macOS لأن فواصل المسارات والقواعد تختلف.
- package archive يدعم file streams لكنه يترك مسؤولية التحقق من أسماء entries والروابط الرمزية للتطبيق. اقرأ README/API المطابقة للإصدار المثبت قبل الاعتماد على سلوك محدد.

## 4. SQLite وFTS والتشفير

### FTS5

- Drift يدعم FTS5 عبر virtual tables في ملفات `.drift`، لا تعريف Dart table عادي.
- أضف اختبار startup/integration ينشئ virtual table ويفهرس ويبحث في العربية والإنجليزية على النسخة الأصلية التي ستشحن.
- استعمل معاملات SQLite. ولا تمرر نص query مباشرة دون تحديد سلوك operators/quotes في FTS.
- حافظ على اتساق فهرس FTS مع حذف/تعديل السجلات، واختبر reindex/backfill.

### التشفير

- حماية الملفات المحلية تحتاج تعريف نموذج تهديد: هل المطلوب حماية عند ضياع الجهاز وهو مغلق؟ هل ملفات الوسائط مشمولة؟ هل backups مشمولة؟
- مخزن الأسرار يحفظ key ولا يشفّر SQLite وحده.
- إذا استخدمنا encrypted SQLite، نفحص cipher/version/extension/rخصة وFTS5 والتوافق لكل target، ونجري اختبارًا على التطبيق المعبأ لا build التطوير فقط.
- المفاتيح لا تُكتب إلى stdout/log/diagnostics. فشل keychain لا يؤدي إلى fallback صامت لتخزين plaintext.
- فقد مفتاح قاعدة مشفرة قد يعني فقد البيانات؛ التصميم يقرر سياسة recovery قبل تفعيل التشفير.

## 5. حدود الخصوصية الصادقة

### ما يمكن الوعد به في V1 بعد تنفيذ واختبار السلوك

- الاستيراد والفهرسة والبحث والإحصاءات المحلية لا تحتاج اتصال إنترنت.
- لا نرفع الأرشيف إلى خادم تابع للمشروع.
- AI الخارجي متوقف ما لم يُهيئه المستخدم ويوافق على عملية إرسال.
- نستطيع حصر ما يخرج في مقتطفات evidence محددة، إذا اجتازت الاختبارات.
- لا نستخدم سجلات الأعطال لالتقاط نص البيانات.

### ما لا يجوز الوعد به دون دليل/اتفاقية محددة

- «لا يغادر جهازك أبدًا» إذا استُخدم API سحابي.
- «لا يتم الاحتفاظ بأي شيء» أو «حذف فوري كامل» لمجرد أن المزود يقول no training.
- «غير قابل للاختراق» أو «تشفير كامل» قبل اختبار DB وmedia/temp/backups على target.
- «يعرف حقيقتك» أو «يشخّص شخصيتك».
- «كل بيانات الحساب» من ملف تصدير اختار المستخدم فئاته وفترته.

## 6. AI provider: شروط القبول

قبل إضافة provider رسمي، وثّق هذه البنود بمصدر رسمي وتاريخ مراجعة:

1. هل مدخلات API مستخدمة للتدريب افتراضيًا؟ وهل يمكن تغيير ذلك؟
2. ما احتفاظ abuse-monitoring والسجلات وحالة الطلبات؟ ما استثناءات الخصائص؟
3. هل توجد ZDR؟ هل تتطلب موافقة/عقدًا؟ وأي endpoints مستثناة؟
4. هل يمكن تعطيل حفظ المحادثات/الملفات/التخزين المتكرر؟
5. منطقة المعالجة، المعالجون الفرعيون، الحذف، الشروط والخصوصية.
6. دعم العربية وجودة المخرجات وأدوات/JSON المقيد.
7. السعر، token limits، ومخاطر إرسال مقتطفات حساسة.
8. هل المفتاح BYOK محفوظ محليًا بطريقة OS-backed؟
9. هل المزود يفرض حسابًا مدفوعًا أو يغير السياسة بين المجاني والمدفوع؟
10. هل يسمح عقد/شروط API باستخدام البيانات الشخصية لهذا الغرض؟ راجع قانونيًا حسب مكان المستخدم.

مثالان رسميان يوضحان أن السياسة تختلف حسب الخدمة:
- OpenAI API data controls: https://developers.openai.com/api/docs/guides/your-data
- Google Gemini API terms: https://ai.google.dev/gemini-api/terms
- Google Gemini logging policy: https://ai.google.dev/gemini-api/docs/logs-policy

هذه روابط للمقارنة وليست توصية بمزود. لا نُبني تكاملًا قبل فحص أحدث وثائق المزود وتحديث هذه الصفحة.

## 7. تصميم consent للإرسال

الخطوات:
1. المستخدم يطلب تحليلًا يعتمد على AI.
2. يستخرج التطبيق محليًا الأدلة المتعلقة فقط.
3. يعرض مقتطفات قابلة للمراجعة/الإزالة، وتحديدًا عددها والفترة والفئات.
4. يعرض المزود والنموذج وسياسة الاحتفاظ ورابط المصدر، والتكلفة التقديرية أو «غير متاحة».
5. المستخدم يوافق لإرسال هذا الطلب فقط، ما لم يختر بوضوح إذنًا مستمرًا قابلًا للإلغاء.
6. بعد الإجابة، تظهر الأدلة التي أُرسلت ومراجعها، لا hidden context.
7. حذف سجل المحادثة يوضح أين حُذف: التطبيق المحلي فقط أو كذلك لدى المزود إن كانت هناك API لحذف الطلب.

## 8. أمن الاستدلال وحقن التعليمات

- رسائل المستخدم المستوردة بيانات اقتباسية غير موثوقة، وليست تعليمات نظام.
- لا يُسمح للنموذج باستدعاء shell أو ملفات أو شبكة حرة.
- الأدوات allowlist وarguments لها schema محلي؛ القيم تمر عبر تحقق.
- المخرجات غير موثوقة؛ لا تنفذها ولا تعرض Markdown/HTML نشطًا بلا تنقية.
- لا ترسل تفاصيل أكثر من حاجة السؤال؛ أزل identifiers المباشرة إن أمكن دون إفساد الاستنتاج.
- لا تجعل وظيفة Agent تعيد كشف كل بيانات شخص لمجرد أن النص طلب ذلك؛ الاسترجاع يخضع لمصدر البيانات وحدود المستخدم.
