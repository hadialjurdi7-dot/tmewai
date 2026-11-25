# GitHub Actions والأدوات المجانية — دليل تشغيلي

## 1) الوضع الحالي للمستودع

| البند | القيمة |
|---|---|
| الرؤية | **private** |
| Actions | 2000 دقيقة/شهر مجاناً (Linux ×1، Windows ×2، macOS ×10) |
| التخزين | 500 MB artifacts/شهر |
| v0.2.1 | منشور تلقائياً بملف `tmewia-v0.2.1-windows-x64.zip` |
| Workflows | `windows-build.yml` · `release-windows.yml` · **جديد:** `ci.yml` · `release-drafter.yml` · `gitleaks.yml` · `stale.yml` |

> **القيد الأهم:** على مستودع **خاص** لا تحصل مجاناً على CodeQL ولا Dependency Review ولا Dependabot security advisories (كلها تحتاج GitHub Advanced Security — مدفوع).
> على مستودع **عام**: Actions بلا حدود + CodeQL + Dependency Review + Dependabot security + كل أدوات المصادر المفتوحة مجاناً. لو الهدف مضاعفة الفائدة، **النشر العام أهم قرار** — وهو مرتبط بقرار الترخيص المفتوح.

## 2) كيف تعمل Actions هنا (بالأرقام)

1. كل PR يشغّل `CI` = analyze + test + coverage على Linux ≈ **2–3 دقائق ×1**.
2. Windows build يعمل فقط على **tag** أو يدوياً → لا يستهلك دقائق مع كل PR (Windows ×2).
3. `concurrency: cancel-in-progress` يلغي التشغيل القديم عند push جديد → يوفّر ~40% دقائق.
4. `subosito/flutter-action` مع `cache: true` + `pubspec.lock` مثبّت → تثبيت التبعيات من ثانية إلى ~15 ثانية.
5. تغيير مسار `docs/**` لا يشغّل CI (فلترة `paths`) → لا دقائق مهدورة.

**ميزانية عملية للمستودع الخاص:** ~150 PR شهرياً × 2.5 دقيقة = 375 دقيقة Linux + إصدارين × 12 دقيقة Windows×2 = 48 → أقل من ربع الحصة المجانية.

## 3) ما أُضيف في هذه الدفعة

| الملف | الفائدة الفعلية |
|---|---|
| `.github/workflows/ci.yml` | بوابة analyze+test على كل PR إلى main مع تقرير تغطية في Summary + artifact |
| `.github/dependabot.yml` | تحديثات `pub` و`actions` أسبوعية مجمّعة (5 PR حد أقصى) |
| `.github/workflows/release-drafter.yml` + `release-drafter.yml` | ملاحظات إصدار تلقائية مصنّفة (ميزات/تشفير/إصلاحات) |
| `.github/workflows/gitleaks.yml` | فحص أسرار مع فشل صريح عند اكتشاف سر |
| `.github/workflows/stale.yml` | تنظيف تلقائي مع استثناء P1/security |
| `.github/pull_request_template.md` | قائمة تحقق تمنع دمج PR بلا اختبار حقيقي |
| `.github/ISSUE_TEMPLATE/*.yml` | بلاغ خلل + طلب ميزة بمعيار قبول إلزامي |

## 4) أدوات مجانية — ما يعمل على مستودع خاص وما يحتاج عام

### تعمل على المستودع الخاص مجاناً
| الأداة | ماذا تعطي | التركيب |
|---|---|---|
| **Dependabot** | تحديثات أمنية واعتماديات | مضمّن (ملف `dependabot.yml` ✅) |
| **gitleaks-action** | كشف أسرار في التاريخ | workflow ✅ |
| **release-drafter** | ملاحظات إصدار من تلقاء نفسها | workflow ✅ |
| **actions/stale** | إدارة تلقائية للمهام الميتة | workflow ✅ |
| **actions/attest-build-provenance** | إثبات بناء (provenance) للملفات — متاح عبر Actions | يُضاف في workflow الإصدار |
| **Codecov** | تغطية + تعليق على PR | يحتاج توكن؛ الخطة المجانية للمستودعات العامة بالأساس |
| **Qubik / Cubic** (المستخدم حالياً) | مراجعة كود آلية على PRs | مثبَّت |
| **GitHub Codespaces** | 120 ساعة/شهر مجاناً (2-core) | مدمج |
| **GitHub Pages** | نشر صفحة تعريف/وثائق | يحتاج تحويل الرؤية للعام |

### تحتاج مستودعاً عاماً لتكون مجانية
| الأداة | ما تعطي |
|---|---|
| **CodeQL** | تحليل ثابت أمني (Semgrep-like) على كل PR + أسبوعي |
| **Dependency Review Action** | رفض PR يضيف تبعية بثغرة معروفة |
| **OpenSSF Scorecard** | درجة أمان المستودع + نصائح |
| **StepSecurity Harden-Runner** | رصد سلوك الشبكة في الـCI (يكشف تسريب توكن) |
| **CodeRabbit / Greptile** | مراجعة PR بلغة طبيعية مجاناً للمصادر المفتوحة |
| **Snyk / Socket** | فحص ثغرات وتبعيات خبيثة |
| **Renovate** | بديل Dependabot أقوى (rules مرنة) |
| **Codecov / Coveralls** | تغطية كاملة مجاناً |

### توصية عملية
1. ابدأ بالقرار: **هل نصير public؟** لو نعم → CodeQL + Dependency Review + Scorecard في نفس اليوم (تغطية أمنية كانت مستحيلة على الخاص).
2. قبل النشر العام: قرار الترخيص (AGPL-3.0 يلائم تطبيق خصوصية محلي-first ويمنع نسخة SaaS مغلقة) — البند مفتوح في `docs/RELEASE.md`.
3. لا تُثبّت أدوات كثيرة قبل الحاجة: كل أداة تضيف وقت CI وضجيج. الترتيب: Dependabot ✅ → CodeQL (إن عام) → gitleaks ✅ → الباقي عند وجود مشكلة فعلية.

## 5) تشغيل يدوي

```bash
# تفعيل طرفية Actions محلياً (act) لاختبار الـworkflow دون دفع
gh workflow run CI            # يدوي
gh run list --limit 5         # آخر التشغيلات
gh run view <id> --log-failed # سجل الفشل
```
`workflow_dispatch` مضاف إلى `ci.yml` و`gitleaks.yml` و`stale.yml` لتشغيلها يدوياً عند الحاجة.
