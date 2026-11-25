# Tmewai

![Tmewai](assets/branding/tmewai_logo.png)

**Tell me exactly who am I.**

Explore your social media data exports privately, on your own device.

Tmewai is a desktop application for opening and understanding the personal data archives you download from social platforms. It inspects ZIP archives locally, identifies files it can read, and is being built to help you explore your history with clear links back to its source. Optional AI-assisted analysis is planned around evidence you can review; your archive is not uploaded by this prototype.

> **Current status:** v0.2.0. The app opens a local workspace, imports a supported subset of a Facebook export in a transaction, and lets you search it, browse a timeline, and review an auditable overview. AI-assisted analysis is still not implemented, and Facebook export support remains partial.

## What it does today

- Creates a local workspace with an explicit open/close lifecycle and a safe, idempotent delete.
- Inspects ZIP files on your device without extracting their contents to a folder.
- Applies archive safety limits and rejects unsafe paths, duplicate entries, and symbolic links.
- Imports the supported Facebook shapes - messages, comments, reactions and posts - transactionally, with duplicate detection and safe cancellation.
- Stores attachment metadata and SHA-256 hashes while never copying attachment bytes into the workspace.
- Classifies every file in an archive in a per-file coverage report, so you can see what was imported and what was not.
- Searches imported events with SQLite FTS5 and an Arabic-friendly tokenizer, filtered by type and date.
- Browses a grouped timeline, an overview dashboard with counts and drill-down, and a settings screen for privacy controls.
- Ships Arabic and English interface strings, Arabic RTL layout and accessibility semantics, plus a bilingual catalog of safe error messages.
- Keeps archive inspection, import, storage and search on your device; no importer opens a network connection.

Facebook export formats differ by platform version and export settings, so support is partial: only recognized JSON shapes are parsed, and unrecognized files are reported rather than guessed at. The AI provider interface and consent gate exist, but no request is dispatched and no provider is configured - no archive content leaves the device.

## Download

Prebuilt Windows x64 packages are published on the [Releases page](../../releases). Install with `tmewai-X.Y.Z-setup.exe` (per-user install into `%LOCALAPPDATA%\Programs\tmewai`, no admin rights), or use the portable `tmewai-windows-x64.zip` and run `tmewai.exe` with the DLLs and `data` folder kept beside it.

Every release publishes `SHA256SUMS.txt`. Verify a download before running it:

```powershell
Get-FileHash .\tmewai-windows-x64.zip -Algorithm SHA256
# compare with the SHA256SUMS.txt attached to the same release
```

Releases are Windows x64 only for now; other platforms need a local build (see the [development guide](docs/DEVELOPMENT.md)). How a release is cut and verified is described in the [release guide](docs/RELEASE.md).

### If your antivirus flags the download

Some engines have flagged the bundled `sqlite3.dll` — an unmodified SQLite
3.54.1 library that ships inside every app using the same Dart package — as
`Trojan:Win32/Bearfoos.A!ml`. It is a false positive: the file matches the
upstream published hash exactly, imports nothing but `KERNEL32`, and has no
network, process or shell APIs. The evidence, the hashes of every shipped file
and the report we file with Microsoft live in
[`security/av-false-positive/`](security/av-false-positive/README.md).

If your engine still flags it, update its definitions first; if it persists,
send us the engine name and version.


## Privacy by design

The project is local-first: archive inspection, import, storage and search run on the user's device. No account is required. Optional AI features are gated behind an explicit consent step that shows the exact bounded evidence first; AI dispatch itself is not implemented yet, and no provider is configured.

## Project documentation

- [Implementation plan and architecture](docs/IMPLEMENTATION_PLAN.md)
- [User interface specification](docs/UI_SPEC.md)
- [Data model and import design](docs/DATA_MODEL_AND_IMPORT.md)
- [Open-source dependencies and privacy principles](docs/OPEN_SOURCE_AND_PRIVACY.md)
- [Development and CI guide](docs/DEVELOPMENT.md)
- [Release guide](docs/RELEASE.md)
- [Changelog](CHANGELOG.md)

---

# Tmewai (العربية)

**قل لي من أنا بالضبط.**

استكشف نسخ بياناتك من منصات التواصل بخصوصية، وعلى جهازك.

Tmewai هو تطبيق لسطح المكتب لفتح أرشيفات البيانات الشخصية التي تنزّلها من منصات التواصل وفهم محتواها. يفحص التطبيق ملفات ZIP محليًا، ويتعرّف على الملفات التي يستطيع قراءتها، ويجري تطويره لمساعدتك على استكشاف سجلك مع إظهار مصادر البيانات. يجري التخطيط لتحليل اختياري بالذكاء الاصطناعي يستند إلى أدلة يمكنك مراجعتها؛ النموذج الأولي لا يرفع أرشيفك.

> **الحالة الحالية:** الإصدار 0.2.0. يفتح التطبيق مساحة عمل محلية، ويستورد مجموعة مدعومة من تصدير Facebook ضمن معاملة واحدة، ويتيح البحث فيها وتصفّح الخط الزمني ومراجعة لوحة عامة قابلة للتدقيق. لم يُنفّذ التحليل بالذكاء الاصطناعي بعد، ويبقى دعم صادرات Facebook جزئيًا.

## ما الذي يفعله الآن؟

- ينشئ مساحة عمل محلية بدورة فتح/إغلاق واضحة وحذف آمن وقابل للتكرار دون أثر جانبي.
- يفحص ملفات ZIP على جهازك من دون استخراج محتوياتها إلى مجلد.
- يطبّق حدودًا للسلامة ويرفض المسارات غير الآمنة والملفات المكررة والروابط الرمزية.
- يستورد الأشكال المدعومة من تصدير Facebook - الرسائل والتعليقات والتفاعلات والمنشورات - ضمن معاملة واحدة، مع كشف التكرار والإلغاء الآمن.
- يخزّن بيانات المرفقات الوصفية وبصمات SHA-256 مع عدم نسخ محتوى المرفقات إلى مساحة العمل.
- يصنّف كل ملف في الأرشيف ضمن تقرير تغطية لكل ملف، لترى ما استُورد وما لم يُستورد.
- يبحث في الأحداث المستوردة عبر SQLite FTS5 بمُقطّع نصي مناسب للعربية، مع تصفية حسب النوع والتاريخ.
- يتيح تصفّح خط زمني مجمّع، ولوحة عامة بأعداد قابلة للتدقيق، وشاشة إعدادات لضوابط الخصوصية.
- يوفّر واجهة بالعربية والإنجليزية مع تخطيط RTL ودلالات وصول، إضافة إلى كتالوج ثنائي اللغة لرسائل أخطاء آمنة.
- يُبقي فحص الأرشيف والاستيراد والتخزين والبحث على جهازك؛ ولا يفتح أي مستورد اتصالًا بالشبكة.

تختلف صيغ تصدير Facebook حسب إصدار المنصة وإعدادات التصدير، لذلك الدعم جزئي: تُقرأ الأشكال المعروفة من JSON فقط، وتُبلَّغ الملفات غير المعروفة بدل التخمين. واجهة مزوّد الذكاء الاصطناعي وبوابة الموافقة موجودتان، لكن لا يُرسَل أي طلب ولا يُهيّأ أي مزوّد - فلا يغادر محتوى الأرشيف الجهاز.

## التنزيل

تُنشر حزم Windows x64 الجاهزة على [صفحة الإصدارات](../../releases). نزّل `tmewia-vX.Y.Z-windows-x64.zip`، ثم استخرجه وشغّل `personal_data_agent.exe`. أبقِ ملفات DLL ومجلد `data` إلى جانب الملف التنفيذي: هذه حزمة محمولة وليست مثبّتًا.

الإصدارات الحالية مخصّصة لـ Windows x64 فقط؛ أما المنصات الأخرى فتحتاج إلى بناء محلي (راجع [دليل التطوير](docs/DEVELOPMENT.md)). وتُوضّح [دليل الإصدار](docs/RELEASE.md) طريقة إصدار نسخة والتحقق منها.

## الخصوصية في التصميم

يركّز المشروع على المعالجة المحلية: فحص الأرشيف والاستيراد والتخزين والبحث تجري على جهاز المستخدم، ولا تتطلب حسابًا. ميزات الذكاء الاصطناعي الاختيارية محكومة بخطوة موافقة صريحة تعرض الأدلة المحدودة بدقة قبل أي إرسال؛ أما الإرسال الفعلي فغير منفّذ بعد ولا يوجد مزوّد مهيّأ.

## وثائق المشروع

- [الخطة التنفيذية والمعمارية](docs/IMPLEMENTATION_PLAN.md)
- [مواصفات واجهة المستخدم](docs/UI_SPEC.md)
- [نموذج البيانات وتصميم الاستيراد](docs/DATA_MODEL_AND_IMPORT.md)
- [المكتبات مفتوحة المصدر ومبادئ الخصوصية](docs/OPEN_SOURCE_AND_PRIVACY.md)
- [دليل التطوير والتكامل المستمر](docs/DEVELOPMENT.md)
- [دليل الإصدار](docs/RELEASE.md)
- [سجل التغييرات](CHANGELOG.md)
