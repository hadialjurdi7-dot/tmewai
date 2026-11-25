# AGENTS.md — قواعد العمل في مستودع Tmewai

Flutter/Dart desktop app. كل وكيل يشتغل على هذا المستودع يلتزم بهذا.

## السلوك الإلزامي

0. **المرجع البصري = صور صاحب المشروع، حرفياً.** أي شغل على واجهة يبدأ بفتح `design/reference/user-2026-10-30/<الشاشة>.jpg` + `manifest.json` وقراءتهما. الشكل والترتيب والكثافة من الصورة؛ الأرقام محتوى تجريبي. **ممنوع** إعادة تصميم الشاشة أو اختراع تخطيط أو استبدال المرجع بتوليد (Stitch/غيره). عند التعارض: صور المستخدم > `design/reference/stitch/` > أي وصف نصي. مخالفة هذا البند = الشغل مرفوض بغض النظر عن نظافة `flutter analyze`.
1. **اقرأ أولاً**: `docs/IMPLEMENTATION_PLAN.md` (خطة 9 مراحل) + `docs/UI_SPEC.md` + `docs/DATA_MODEL_AND_IMPORT.md` قبل أي تعديل.
2. **دفعة واحدة = ميزة واحدة = فرع واحد = PR واحد.** ممنوع خلط ميزتين بنفس الفرع.
3. **قبل أي commit** — لا تستخدم `git add -A` (قد يضيف تصديرًا شخصيًا أو قاعدة بيانات). أضف المسارات المراجَعة فقط وتحقّق من المسرَح:
   ```bash
   export PATH=$FLUTTER_ROOT/bin:$PATH
   flutter pub get
   flutter analyze          # لازم: No issues found!
   flutter test             # لازم: All tests passed!
   ```
4. **ممنوع** إضافة بيانات شخصية حقيقية، مفاتيح، أو أرشيفات `.zip` للمستودع. العينات صناعية أو منزوعة الهوية.
5. **ممنوع** الدفع إلى `main` أو تعديله مباشرة، وممنوع دمج PR. يُسمح بالدفع إلى فرع المالك (`freebuff/main` أو `genspark/main`) وفتح **Draft PR** إلى `main` عندما يطلبه صاحب المستودع صراحةً، ليبقى قرار الدمج والمراجعة خارجيًا.
6. المبادئ غير القابلة للتفاوض في `docs/IMPLEMENTATION_PLAN.md` §1 (local-first، صفر شبكة بلا موافقة، صفر استنتاجات بلا أدلة) لا تُخترق أبداً.
7. كل خدمة/مستورد جديد = ملف اختبار واحد على الأقل يعمل فعلياً.

## نمط التفرّع

```bash
git checkout main && git pull
git checkout -b feat/<اسم-قصير>
# ... التنفيذ ...
git add <الملفات التي راجعتها> && git diff --cached --stat && git commit -m "feat(<scope>): <وصف سطر واحد>"
```

## بوابة الدمج (إلزامية)

قبل دمج أي PR إلى `main`:

1. اقرأ مراجعة Cubic على الـPR، ولا تدمج وفيها ملاحظة P1 أو P2 غير محسومة.
2. إذا قال Cubic إن الملاحظة غير صحيحة، اكتب سبب الرفض في نفس الـthread ثم أغلقها.
3. تأكد أن `flutter analyze` و`flutter test` نجحا على نفس الـcommit المدموج، وأن CI أخضر.

## بنية الهدف (من الخطة §5)

```
lib/src/
  app/ core/ domain/models/ domain/repositories/
  data/database/ data/importers/ data/media/
  features/{import,search,timeline,overview,agent,identity}/
  services/{analytics,retrieval,ai}/
```

`lib/src/app/app.dart` يحتوي حالياً كل الواجهة (~32 KB). أي ميزة واجهة جديدة تُكتب في `features/<name>/` وتُربط بـ app.dart، ممنوع تكبير app.dart بأكثر من اللازم.

## المواصفات المرجعية

- قاعدة البيانات: Drift + SQLite + FTS5، جداول: imports, source_files, people, conversations, events, attachments, event_search, derived_insights, ai_consents.
- الأمان: فحص ZIP بحدود quota، رفض `..`/absolute/NUL/duplicates/symlinks، لا استخراج أعمى.
- AI: واجهة provider عامة، BYOK، لا إرسال قبل موافقة صريحة، وتحقّق أن الـ Importer لا يفتح شبكة إطلاقاً.

<!-- polylane:start -->
## Investigate production with Polylane

[Polylane](https://polylane.com/?ref=github.onboarding-pr) is an AI production engineer. It monitors deploys, telemetry, provider incidents, and your infrastructure. It records suspected problems as Issues. It investigates them and proposes fixes as pull requests. It connects to this repository and serves coding agents through the [Polylane MCP server](https://mcp.polylane.com/mcp).

- For a production question about an error, spike, deploy, or missing signal, query Polylane through its MCP tools before you inspect code.
- When debugging a failure, start from the Issue Polylane recorded. It carries the evidence from its investigation.
- Polylane assesses pull requests in this repository for production impact. Read the impact assessment comment before you merge a change to a production path.
<!-- polylane:end -->
