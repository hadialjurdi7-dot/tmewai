# الاتجاه البصري وGoogle Stitch

> الهدف ليس «واجهة أجمل»، بل واجهة لا تُشبه لوحات SaaS ولا تطبيقات المحادثة. المنتج أرشيف شخصي، فالشكل يجب أن يقول: **هذا مكتب أدلة، لا صندوق محادثة.**

## 1. الفكرة المركزية: «مكتب الأدلة»

ثلاث استعارات تحكم كل قرار:

1. **ملف تحقيق**: كل رقم وكل بطاقة قابلة للفتح حتى السجل الذي أنتجها.
2. **دفتر أرشيف**: ورق دافئ، حبر داكن، خط أحمر واحد للعلامات. لا ألوان بهيجة.
3. **سجل رسمي**: التواريخ والمعرّفات بخط أحادي المسافة (mono) في هوامش الصفحة، كأنها مراجع.

ما نرفضه صراحة: تدرجات بنفسجية، glassmorphism، بطاقات ChatGPT، فقاعات محادثة، رسوم «AI سحرية»، أرقام بلا مصدر، ظلال ناعمة كثيرة.

## 2. نظام الألوان

| الدور | فاتح | داكن | ملاحظة |
|---|---|---|---|
| الورق (خلفية) | `#F6F2E9` | `#14130F` | دافئ، لا أبيض ناصع |
| السطح (بطاقة) | `#FFFDF7` | `#1C1B17` | فرق بسيط عن الورق |
| الحبر (نص) | `#1C1B18` | `#EDE7D9` | لا أسود مطلق |
| نص ثانوي | `#6B665B` | `#A39C8C` | 4.5:1 على الأقل |
| الخط الفاصل | `#E2DCCD` | `#33302A` | 1px دائمًا |
| العلامة (accent) | `#A63D2F` | `#D97757` | أحمر أرشيفي، للتركيز فقط |
| علامة باهتة | `#F3E0DA` | `#3A2621` | خلفية شارات |
| نجاح | `#3F6B4A` | `#8FBF9A` | |
| تحذير | `#8A6A1F` | `#D9B65E` | |
| خطأ | `#9F2F2D` | `#E08A83` | |

قاعدة: لا لون بلا معنى. كل لون دلالي يجب أن يعمل أيضًا مع رمز أو نص (لا الاعتماد على اللون وحده).

## 3. الخطوط

- **العربي والواجهة**: `IBM Plex Sans Arabic` (رخصة OFL). أوزان 400/500/600.
- **اللاتيني التحريري للعناوين الكبيرة**: `Fraunces` أو `Newsreader` (OFL)، اختياري.
- **الأرقام والمعرّفات والمسارات**: `IBM Plex Mono` (OFL).

السبب: Plex Sans Arabic له شخصية هندسية واضحة، ويعمل مع Plex Mono كعائلة واحدة. لا Inter/Roboto/Open Sans.

مقياس الأحجام (Desktop):

| الدور | الحجم/الارتفاع | الوزن |
|---|---|---|
| عنوان شاشة | 28/36 | 600 |
| عنوان قسم | 18/26 | 600 |
| نص | 14/22 | 400 |
| ثانوي | 12.5/18 | 400 |
| شارة/تسمية | 11/14، تباعد 0.04em | 500 |
| رقم إحصاء كبير | 34/40، mono | 500 |

## 4. المسافات والشكل

- شبكة 4px. المسافات المسموحة: 4، 8، 12، 16، 24، 32، 48، 64.
- زوايا: 2px للوسوم، 6px للأزرار، 10px للبطاقات. لا pill للأزرار الكبيرة.
- حدود 1px بدل الظلال. الظل الوحيد المسموح: `0 1px 2px rgba(28,27,24,0.04)`.
- عرض القراءة 760–1040px، والشريط الجانبي 232px.
- خلفية الورق تحمل نويز خفيفًا جدًا (opacity 0.02) لتفادي التسطّح، لا صور.

## 5. المكوّنات المميّزة (هوية المنتج)

1. **EvidenceCard** — بطاقة بحدّ أيسر 2px بلون العلامة، عنوان، رقم mono، وسطر «كيف حُسب؟». النقر يفتح السجلات الداخلة في الحساب.
2. **SourceLocator** — شريحة mono باتجاه LTR داخل جملة RTL، مثل `messages/inbox/1.json#4`. قابلة للنسخ، ولا تُكسر.
3. **LedgerTimeline** — خط يوم أفقي، التاريخ في الهامش الأيمن mono، الأحداث صفوف لا فقاعات.
4. **CoverageMeter** — شريط مقسّم: مقروء / تم تخطيه / غير مدعوم، وأسفله جدول دائم. لا نسبة واحدة مبهمة.
5. **ConsentSheet** — لوح جانبي (لا نافذة وسطية) يعرض حرفيًا ما سيغادر الجهاز: المزوّد، عدد المقاطع، الحجم، السياسة، والتكلفة. زر الإرسال معطّل حتى المراجعة.
6. **DossierHeader** — ترويسة كل شاشة: رقم القسم `03 /`, العنوان، وسطر «ما لا تقوله هذه البيانات».
7. **LocalBadge** — «محلي» ثابت؛ يتحول إلى «اتصال خارجي» فقط عند وجود طلب فعلي، مع سبب.

## 6. الحركة

- 120–180ms، `easeOutCubic`. لا حركة زخرفية.
- انتقال الشاشة: fade + 8px، لا slide أفقي.
- احترام `MediaQuery.disableAnimations` (تقليل الحركة).
- لا skeletons نابضة؛ استخدم تقدمًا حقيقيًا أو حالة «قيد القراءة» نصية.

## 7. الشاشات: ترتيب بصري

| الشاشة | العنصر المهيمن | ما يجب ألا يظهر |
|---|---|---|
| البداية | جملة خصوصية + زر اختيار ملف | بطاقات ميزات تسويقية |
| تقرير الاستيراد | CoverageMeter + جدول ملفات | نسبة اكتمال وهمية |
| النظرة العامة | 4 EvidenceCards + فترة النشاط | رسوم بلا جدول بديل |
| البحث | حقل + شرائح مرشحات + نتائج كثيفة | فقاعات دردشة |
| الخط الزمني | LedgerTimeline | رسوم «سوشيال» ملوّنة |
| المحادثة | نص المصدر كما ورد | إعادة صياغة صامتة |
| الوكيل | ConsentSheet أولًا، ثم الرد بأدلة | شعار «AI» لامع |
| الإعدادات | مساحة العمل والحجم + حذف | إعدادات مخفية |

## 8. الوصولية

- تباين 4.5:1 للنص و3:1 للحدود التفاعلية.
- أهداف لمس/نقر ≥ 40px.
- focus ring واضح: 2px `#A63D2F` مع إزاحة 2px.
- كل رسم له جدول أو وصف بديل.
- ترتيب Tab منطقي: شريط جانبي → ترويسة → محتوى → شريط الإجراءات.
- لا تعتمد الحالة على اللون وحده.

## 9. Google Stitch: كيف نستخدمه بذكاء

Stitch ممتاز لتوليد **تركيب الشاشة والتسلسل البصري**، وضعيف في العربية/RTL والتفاصيل الدقيقة. لذلك:

1. ولّد الشاشة بالإنجليزية أولًا لضبط الشبكة والهرمية.
2. أعِد توليد نسخة عربية للتحقق من الطول والالتفاف، ولا تعتمد عليها للـRTL النهائي.
3. نفّذ RTL والتخطيط في Flutter، لا في Stitch.
4. لا تستخدم ناتج Stitch ككود إنتاج؛ استخدمه كمرجع بصري وقيم تصميم.

### برومبت البداية (انسخه في Stitch)

```text
Desktop app for a private, local-first personal archive. Visual language: an
archival evidence desk, not a SaaS dashboard. Warm bone paper background
(#F6F2E9), off-black ink (#1C1B18), one archival red accent (#A63D2F), 1px
hairline borders (#E2DCCD), almost no shadows, 6-10px radii. Editorial
typography: IBM Plex Sans Arabic for UI, IBM Plex Mono for dates, counts and
source paths. Layout: 232px left sidebar with numbered sections (01 Overview,
02 Search, 03 Timeline, 04 Conversations, 05 Sources, 06 Settings), 1040px
reading column, generous margins. No gradients, no glassmorphism, no chat
bubbles, no purple. Every statistic card has a small mono reference and a
"How was this calculated?" line. Show a right-aligned date gutter like a
ledger. Screen: import coverage report with a segmented meter (parsed, skipped,
unsupported) and a dense table of relative file paths. Arabic-first labels.
```

كرّر مع استبدال آخر سطرين بالشاشة المطلوبة: Overview / Search results / Timeline / Consent sheet.

### إعداد MCP Stitch

Stitch يوفّر MCP بعيدًا على `https://stitch.googleapis.com/mcp` ويُصادق بمفتاح API في هيدر `X-Goog-Api-Key`.

1. أنشئ مفتاحًا من إعدادات Stitch (API key). **لا تضعه في الشات ولا في المستودع.**
2. صدّر المفتاح في بيئتك:

```bash
export STITCH_API_KEY="..."   # محليًا فقط
```

3. الملف `.mcp.json` في جذر المستودع جاهز، ويقرأ المتغير ولا يحتوي أي سر:

```json
{
  "mcpServers": {
    "stitch": {
      "type": "http",
      "url": "https://stitch.googleapis.com/mcp",
      "headers": { "X-Goog-Api-Key": "${STITCH_API_KEY}" }
    }
  }
}
```

أو عبر Claude Code:

```bash
claude mcp add stitch --transport http https://stitch.googleapis.com/mcp \
  --header "X-Goog-Api-Key: $STITCH_API_KEY"
```

Gemini CLI: أضف الخادم في `~/.gemini/settings.json` بنفس الشكل. Cursor: `.cursor/mcp.json`.

> جلسة Freebuff هذه لا تُحمّل خوادم MCP؛ الملف جاهز لعميلك المحلي (Claude Code / Cursor / Gemini CLI). لا تضع المفتاح في `.mcp.json` نفسه.

## 10. من التصميم إلى Flutter

1. أنشئ `lib/src/app/theme/` بـ:
   - `app_colors.dart` (ثوابت الألوان أعلاه)
   - `app_typography.dart` (TextTheme مبني على Plex Sans Arabic + Mono)
   - `app_spacing.dart` (شبكة 4)
   - `app_theme.dart` (ThemeData فاتح/داكن، `useMaterial3: true`، حدود 1px)
2. أضف الخطوط إلى `pubspec.yaml` تحت `fonts:` (ملفات OFL فقط، مع LICENSE).
3. استبدل الثيم الحالي في `app.dart` بـ`AppTheme.light` / `AppTheme.dark`، دون تغيير المنطق.
4. نفّذ المكوّنات في `lib/src/app/widgets/` أو `features/<name>/widgets/`.
5. golden tests للشاشات الخمس قبل توسيع أي شاشة جديدة.

## 11. معايير القبول للهوية

- لا لون خارج الجدول أعلاه.
- لا ظل خارج المسموح.
- كل شاشة لها ترويسة DossierHeader وحالة فارغة مكتوبة.
- كل رقم له مصدر أو رابط «كيف حُسب؟».
- RTL وLTR مقروءان في نفس الشاشة.
- لا يشبه أي شاشة قياسية من ChatGPT أو Notion أو Linear؛ الاختبار: أزل الشعار، هل تعرف أنه أرشيف شخصي؟
