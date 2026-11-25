# TASKS — الشاشات الست المعتمدة (بناء كامل، 29/10/2026)

> الجلسة 1 (الهيكل) **خلصت ومدموجة بالكود**: `lib/src/app/app_shell.dart` + الثيم + الشاشات النائبة،
> و`flutter analyze` نظيف + 147 اختبار أخضر. ما تعيد بناءها.

## الحالة الحالية
- الهيكل: `AppShell` بـ7 أقسام + `IndexedStack` كسول + شريط علوي (مارك + «تمواي» + بحث).
- الشاشات المنفَّذة: `features/{overview,search,settings,timeline}`.
- النائبة (placeholder): `home`, `analytics`, `messages`, `media`, `people` (شوف `app_shell.dart`).
- التوكنز: `lib/src/core/design/tokens.dart` (`TmColors`/`TmSpace`/`TmType`/`TmRadius`/`TmHit`) + `theme.dart`.
- الخدمات الجاهزة للقراءة: `overview_service`, `overview_repository` (topPeople, countsByDay, countsByEventType),
  `timeline_service` (`load(...)`), `attachment_repository`, `event_search_repository`, `ai_consent_repository`.

## ⚠️ المرجع البصري الملزِم — الصق تصميم المستخدم، لا تُولّد بديلاً

**الأول والأخير: `design/reference/user-2026-10-30/`** — ست صور صدّرها صاحب المشروع بنفسه (30/10 2026).
- `01-home.jpg` · `02-story.jpg` · `03-analytics.jpg` · `04-messages.jpg` · `05-media.jpg` · `06-person.jpg`
- `manifest.json` — لكل شاشة: التخطيط بالتفصيل، الأعمدة، العناصر، والترتيب الإلزامي.

**قاعدة التنفيذ:** لكل شاشة تبدأها، **افتح صورتها** (الصورة أو `manifest.json`) قبل أول سطر كود. الشكل = المرجع، والأرقام = محتوى تجريبي يُستبدل بقيم الخدمات.

**ملفات مساعدة (ثانوية، أقدم):** `design/reference/stitch/` — `home.html` + `stitch-*.png`. استعملها فقط لتفاصيل لونية/تباعدية دقيقة **لا تخالف** صور المستخدم. عند أي تعارض، **صور المستخدم هي الحاكمة**.

**ممنوع:** اختراع تخطيط أو قسم أو بطاقة غير موجودة بالصورة، أو إعادة تصميم الشاشة بـ«ستايل أفضل»، أو استبدال المرجع بمخرجات Stitch/توليد جديد.

## قيود صارمة
1. **ممنوع أي dependency جديدة** — `pubspec.yaml` dependencies ما تتغيّر. الأيقونات `Icons.*` فقط، والرسوم بـ`Container`/`FractionallySizedBox`.
2. **قراءة فقط** لـ`lib/src/data/**`, `lib/src/domain/**`, `lib/src/services/**`. لو احتجت استعلام تجميع جديد، اكتبه بـ`lib/src/data/repositories/` **بعد** ما تقرأ النمط الموجود، وسمّه `// ponytail:` مع سبب الحاجة.
3. **ممنوع `git push` وممنوع لمس `main`** — أنت تعمل `git checkout -b` + `git commit` فقط. الدفع والـPR مسؤولية المنسّق.
4. **فرع لكل شاشة** — بالترتيب أدناه، وكل فرع مبني على الفرع اللي قبله (stacked).
5. **لا أسئلة** — قرّر وسجّل القرار بـ`PROGRESS.md`.
6. كل لون/فراغ/خط من التوكنز — ممنوع أرقام سحرية (`EdgeInsets.all(16)` ممنوع؛ `TmSpace.l`).
7. RTL إلزامي، لا نص أصغر من `TmType.caption`، كل هدف نقر ≥ `TmHit.min`، و`ValueKey` لكل عنصر قائمة.
8. **ممنوع `pumpAndSettle`** بأي widget test لشاشة فيها مؤقّت/تحديث دوري — استعمل `await tester.pump(const Duration(milliseconds: 300))` ثم `await tester.pump()`.
9. **ممنوع تكبير `app.dart`** — كل شاشة بملفها تحت `lib/src/features/<name>/`.

## التحقّق (إلزامي بعد كل شاشة — Flutter مثبّت على هذا الجهاز)
```bash
export PATH=$FLUTTER_ROOT/bin:$PATH
flutter analyze && flutter test
```
معيار القبول لكل شاشة: `No issues found!` + `All tests passed!` + اختبار widget جديد للشاشة + `git commit`.

---

## P1 — `feat/screen-home` (من `feat/screens-base`)
`lib/src/features/home/home_screen.dart` — بديل النائب بالـ`IndexedStack` (القسم 1) بدل صفحة الاستيراد المؤقتة.
- شريط علوي داخلي: تحية «أهلاً بك — أرشيفك من … لـ… كله على جهازك» (المدى من `overview_service`).
- شريط «حصيلة سنينك»: 4 بطاقات KPI = رسائل · صور · أشخاص · سنين (`overview_service` / `overview_repository.topPeople`).
- عمود «أكتر ناس حكيت معهن»: `topPeople` — أشرطة أفقية بقيمة رقمية مكتوبة على كل شريط، تنازلي دائماً.
- «آخر النشاط»: أحدث 3 أحداث من `timeline_service` كبطاقات Flat (أبيض + حدّ + بلا ظل).
- زر «استيراد» يضل متاح (ينقل زر الاستيراد من الصفحة القديمة — لا تكسر `test/app_test.dart`).
- حالة فارغة (لا بيانات): بطاقة واحدة «ما في أرشيف بعد» + زر استيراد.
- اختبار: `test/features/home_screen_test.dart` — الحالة الفارغة + حالة فيها بيانات (fake service) + RTL.

## P2 — `feat/screen-story` (من P1)
`lib/src/features/story/story_screen.dart` — «قصتك بالأرقام» (القسم 2). يستبدل `OverviewScreen` بالـshell مع إبقاء الملف القديم شغّال لاختباراته.
- Hero: «سنتك الأغزر: YYYY» + 3 بطاقات (رسائل/صور/أشخاص لتلك السنة) من `countsByDay`/`topPeople`.
- «الرسائل حسب السنة»: أعمدة رأسية بقيمة فوق كل عمود، تنازلي زمنياً من اليسار لليمين بشكل RTL صحيح.
- «أرقام سريعة»: أول حدث · آخر حدث · أكتر شخص · عدد الأيام المغطّاة.
- «أشهر 3 كلمات»: من `event_search_repository` (لو ممكن) وإلا احذف البطاقة وسجّل السبب — لا تعرض أرقاماً وهمية.
- اختبار: `test/features/story_screen_test.dart`.

## P3 — `feat/screen-analytics` (من P2)
`lib/src/features/analytics/analytics_screen.dart` — «التحليلات» (القسم 3).
- فلاتر سنة (الكل + آخر 5 سنوات) — `ChoiceChip`، الحالة بالـcontroller.
- «الرسائل حسب الشهر»: 12 عمود + قيمة فوق كل عمود.
- «الساعات اللي بتحكي فيها»: أعمدة 0..23 (تجميع `GROUP BY` واحد موثَّق بالـrepository إذا لزم).
- «أنواع المشاركة»: أشرطة نسبة من `countsByEventType` + النسبة مكتوبة كنص.
- «الترتيب حسب الشخص»: `topPeople` تنازلي.
- اختبار: `test/features/analytics_screen_test.dart` (تغيير الفلتر يغيّر النتائج).

## P4 — `feat/screen-messages` (من P3)
`lib/src/features/messages/messages_screen.dart` — «الرسائل» (القسم 4).
- يمين: قائمة محادثات (اسم + مقتطف + وقت) — مصدرها `conversations` بالـrepos الموجودة.
- يسار: thread فقاعات (يمين/يسار) + فواصل أيام + حقل إدخال **معطّل** بنص «الرد من تطبيق فيسبوك — غير مفعّل».
- اختيار محادثة يبدّل الـthread؛ `ValueKey` لكل صف وكل فقاعة.
- اختبار: `test/features/messages_screen_test.dart` (اختيار محادثة + وجود حقل معطّل).

## P5 — `feat/screen-media` (من P4)
`lib/src/features/media/media_screen.dart` — «الصور» (القسم 5).
- شبكة 4 أعمدة (`GridView`/`Wrap` مع `Key`)، شارة سنة على كل صورة، اسم/عدّاد فوق.
- البيانات من `attachment_repository` — **بيانات وصفية فقط**؛ لا تحمّل محتوى الملفات، واعرض مربعاً بديلاً عند غياب المسار.
- شريط «ذكريات» فلاتر سنة.
- اختبار: `test/features/media_screen_test.dart`.

## P6 — `feat/screen-person` (من P5)
`lib/src/features/people/person_screen.dart` — «ملف شخص» (القسم 6).
- Cover + avatar + اسم + «حكيتوا من X لـY · N رسالة» + 4 بطاقات أرقام (رسائل/صور/سنين/شهر متواصل).
- «آخر الحكي»: مقتطفات مع السنة. «صور بيناتكم»: شبكة مصغّرة.
- اختيار الشخص من قائمة الأشخاص (القسم 6 بالـshell) — أو صفحة تفاصيل فوقها.
- كل رقم له تسمية؛ ولا استنتاجات بلا مصدر.
- اختبار: `test/features/person_screen_test.dart`.

---

## قاعدة الإغلاق
بعد كل شاشة:
```bash
export PATH=$FLUTTER_ROOT/bin:$PATH
flutter analyze && flutter test          # لازم يمرقوا الاتنين
git add -A && git commit -m "feat(<screen>): <what it adds>"
git checkout -b <الفرع التالي>            # stacked، من الفرع الحالي
```
وسجّل بآخر `PROGRESS.md`: الشاشة · الملفات · نتيجة التحقّق · ما تبقّى. **كمّل شاشاتك كلها بهاد التيرن، ما توقف عند الأولى.**
