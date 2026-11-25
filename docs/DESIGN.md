# Tmewai — الهوية البصرية ونظام التصميم

> معتمد 29/10/2026. المصدر البصري: `design/brand/brand-board.png` (لوحة الهوية الكاملة)
> والملف القابل للتعديل `design/brand/brand-board.figcraft` (يفتح بFigCraft).
> التوكنز بالكود: `lib/src/core/design/tokens.dart` + `theme.dart`.

## 1. الشعار — «Drawer T»
التاء مسكّة الدرج: الأرشيف درج، والتاء مقبضه. شكلان أبيضان على مربّع بلون الثيم.

| النسخة | الملف | الاستخدام |
|---|---|---|
| أساسي (أزرق #1877F2) | `design/brand/tmewai_mark_primary.svg` · PNG 512 بـ`assets/branding/` | التطبيق، الفافيكون، الهيدر |
| أبيض على داكن | نفس الهندسة، المربّع `#FFFFFF` والتاء `#111418` | خلفيات داكنة |
| أحادي (`#050505`) | نفس الهندسة بلا لون | طباعة، علامة مائية |

- هندسة المارك: مربّع 256×256 بزاوية 44 · عارضة (50,52,156×44) · ساق (108,96,40×56) · شقّ الدرج (50,176,156×26).
- المقاسات الدنيا: 16 / 24 / 32 / 48 — يُقرأ عند 16px، ولا يُصغَّر تحته.
- ممنوع: تدوير، تدرّج، ظلّ، أو تفريغ الشقّ بلون غير الأبيض.

## 2. الألوان
| التوكن | القيمة | الدور | ملاحظة |
|---|---|---|---|
| `TmColors.bg` | `#F0F2F5` | خلفية الصفحة | رمادي فيسبوك المألوف |
| `TmColors.card` | `#FFFFFF` | سطح البطاقة | حدّ 1px `#E4E6EB`، **بلا ظلّ** |
| `TmColors.border` | `#E4E6EB` | الفواصل والحدود | — |
| `TmColors.primary` | `#1877F2` | اللون الأساسي | 4.6:1 مع الأبيض — زر/تاب **واحد** بالشاشة |
| `TmColors.primaryTint` | `#E7F3FF` | العنصر المحدَّد | خلفية الصف النشط |
| `TmColors.warm` | `#F59E0B` | الذكريات والـhero | لا يُستخدم لغيره |
| `TmColors.success` | `#16A34A` | تأكيد محلي | «كل شي على جهازك» |
| `TmColors.text` | `#050505` | نص أساسي | 17.4:1 |
| `TmColors.text2` | `#65676B` | نص ثانوي | 5.7:1 — يصحّ للنص الصغير |

## 3. الخطوط
IBM Plex Sans Arabic (وزن بصري متساوٍ للعربي واللاتيني). المقياس: 32 / 22 / 17 / 15 / 13.
**لا نص أصغر من 13px**، وارتفاع السطر 1.5، وطول السطر ≤ 75 حرفاً، وممنوع `word-break: break-all` للنص العربي.

## 4. الأيقونات
38 أيقونة [Lucide](https://github.com/lucide-icons/lucide) (ISC) في `design/icons/lucide/` — خطّية 24px، stroke 2، cap/join round. الإشعار الكامل للرخصة وحقوق النشر موجود بجانب الأيقونات في `design/icons/lucide/LICENSE`.
الكود يستعمل `Icons.*` من Material بنفس الوزن البصري؛ الخريطة:

| الاستخدام | Lucide | Material |
|---|---|---|
| الرئيسية | `house` | `Icons.home_outlined` |
| قصتك / التحليلات | `chart-column` · `chart-bar` | `Icons.bar_chart` · `Icons.insights` |
| الرسائل | `messages-square` | `Icons.forum_outlined` |
| الصور | `image` | `Icons.image_outlined` |
| الأشخاص | `users` · `user-round` | `Icons.people_outline` · `Icons.person_outline` |
| الإعدادات | `settings` | `Icons.settings_outlined` |
| البحث | `search` | `Icons.search` |
| استيراد / تصدير | `upload` · `download` | `Icons.upload_file` · `Icons.download_outlined` |
| تنقّل | `chevron-right` · `chevron-left` | `Icons.chevron_right` · `Icons.chevron_left` |
| حالة | `check` · `x` · `clock` | `Icons.check` · `Icons.close` · `Icons.schedule` |

> لا إيموجي كأيقونة، ولا اسم أيقونة Material كنص (صار سابقاً مع Stitch).

## 5. القوانين الملزمة
- لا قسم مخبّى بالمنيو: 7 أقسام ظاهرة (الرئيسية · قصتك بالأرقام · التحليلات · الرسائل · الصور · الأشخاص · الإعدادات).
- كل رقم على الشاشة معه وحدة/نص وصفي، وكل عمود رسم بياني مكتوب فوقه رقمه — اللون لا يحمل معنى لحاله.
- هدف نقر ≥ 44px، `ValueKey` لكل عنصر قائمة متغيّر، بلا `Stack` لقوائم عمودية.
- مصدر بيانات لكل قسم: لا شاشة بلا خدمة موجودة أو استعلام واحد مجمّع.

## 6. الشاشات المعتمدة
`الرئيسية` · `قصتك بالأرقام` · `التحليلات` · `الرسائل` · `الصور` · `الأشخاص` · `الإعدادات`
اللقطات: `design/figcraft/png/` — الملف القابل للتعديل: `design/figcraft/tmewai-v1.figcraft`.
