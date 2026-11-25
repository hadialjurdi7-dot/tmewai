import 'package:flutter/material.dart';

/// Tmewai design tokens — مصدر الحقيقة الوحيد للون والقياس.
///
/// مصدرها: `docs/DESIGN.md` (لوحة الهوية المعتمدة، 29/10/2026).
/// قاعدة: لا hex ولا مقاس مكتوب يدوياً داخل الشاشات — كل شيء من هنا.
abstract final class TmColors {
  /// خلفية الصفحة #F0F2F5 — رمادي فيسبوك المألوف، بلا وهج.
  static const bg = Color(0xFFF0F2F5);

  /// سطح البطاقة #FFFFFF مع حدّ [border] 1px وبلا ظلّ.
  static const card = Color(0xFFFFFFFF);

  /// Fully transparent paint for stateful borders and empty fills.
  static const transparent = Color(0x00000000);

  /// حدّ البطاقات والفواصل #E4E6EB.
  static const border = Color(0xFFE4E6EB);

  /// اللون الأساسي #1877F2 — زر/تاب واحد فقط في الشاشة، تباينه 4.6:1 مع الأبيض.
  static const primary = Color(0xFF1877F2);

  /// تظليل العنصر المحدَّد #E7F3FF.
  static const primaryTint = Color(0xFFE7F3FF);

  /// درجة أزرق أفتح لأعمدة المخططات الثانوية #A8C7FA — مع [primary] فقط.
  static const primarySoft = Color(0xFFA8C7FA);

  /// الذكريات والـhero فقط #F59E0B.
  static const warm = Color(0xFFF59E0B);

  /// تأكيد «كل شي على جهازك» #16A34A.
  static const success = Color(0xFF16A34A);

  /// نص أساسي #050505 (17.4:1).
  static const text = Color(0xFF050505);

  /// نص ثانوي #65676B (5.7:1) — يصحّ للنص الصغير.
  static const text2 = Color(0xFF65676B);

  /// خلفية تأكيد «محلي وآمن» #DCFCE7 — مع [success] فقط.
  static const successTint = Color(0xFFDCFCE7);

  /// حبّة «محلي على جهازك 100%» في الشريط العلوي — أفتح من [successTint]
  /// كما في `design/reference/user-2026-10-30/03-analytics.jpg`.
  static const successSurfaceSoft = Color(0xFFEAF9EF);

  /// خلفية الذكريات/التنبيه الهادئ #FEF3C7 — مع [warm] فقط.
  static const warmTint = Color(0xFFFEF3C7);

  /// خلفية بانر «هالصور من سنة» #FEFBEC — أفتح من [warmTint] كما بالمرجع.
  static const warmSurface = Color(0xFFFEFBEC);

  /// حدّ بانر الذكريات #F4E6BB.
  static const warmBorder = Color(0xFFF4E6BB);

  /// عنوان بانر الذكريات #7A3E00 — تباينه 8:1 على [warmSurface].
  static const warmText = Color(0xFF7A3E00);

  /// السطر الثانوي داخل البانر #8A5A35 — تباينه 5.6:1 على [warmSurface].
  static const warmTextSoft = Color(0xFF8A5A35);

  /// خلفية بطاقات الخصوصية الخضراء #F5FDF8 — مع [success] فقط.
  static const successSurface = Color(0xFFF5FDF8);

  /// حدّ بطاقة الخصوصية #D5F2DE.
  static const successBorder = Color(0xFFD5F2DE);

  /// Muted avatar tints used by the archive's people and conversation rows.
  static const avatarTints = <Color>[
    primaryTint,
    Color(0xFFFFF2CC),
    Color(0xFFFCE4EC),
    Color(0xFFE5E7EB),
    successTint,
    Color(0xFFF3E5F5),
    Color(0xFFE0F2FE),
    Color(0xFFECEFF1),
  ];
  static const avatarForegrounds = <Color>[
    primary,
    Color(0xFFB77900),
    Color(0xFFC2185B),
    text2,
    success,
    Color(0xFF7B1FA2),
    Color(0xFF0277BD),
    Color(0xFF546E7A),
  ];

  /// خطأ/حدّ أقصى #E41E3F — نفس أحمر المرجع، تباينه 4.9:1 مع الأبيض.
  static const error = Color(0xFFE41E3F);

  /// رابط ثانوي «شوف الكل» #0D9488 — تباينه 4.8:1 مع الأبيض.
  static const teal = Color(0xFF0D9488);
}

/// إيقاع 4/8 — لا فراغ خارج هذه القيم.
abstract final class TmSpace {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

/// Home-screen dimensions, tuned to the owner reference at desktop widths.
abstract final class TmSize {
  static const homeContentMaxWidth = 1380.0;
  static const homeThreeColumnMinWidth = 900.0;
  static const homeOverviewWrapWidth = 760.0;
  static const homeGreetingIcon = 48.0;
  static const homeFeedImageHeight = 238.0;
  static const homeHeaderIcon = 20.0;
  static const homeSmallAvatar = 32.0;
  static const homeAvatar = 40.0;
  static const homeKpiMinWidth = 84.0;
  static const homeDividerHeight = 44.0;
  static const homeStatusDot = 8.0;
  static const homeProgressHeight = 6.0;
  static const homeSearchWidth = 240.0;
  static const homeBrandMark = 32.0;

  /// The shared top bar of every owner-reference screen (01–06).
  static const shellTopBarHeight = 56.0;
  static const shellBrandMark = 36.0;
  static const shellBrandIcon = 20.0;
  static const shellTabIcon = 18.0;
  static const shellTabGap = 6.0;
  static const shellTabUnderline = 3.0;
  static const shellBell = 40.0;
  static const shellBellDot = 8.0;
  static const shellBellDotRing = 2.0;
  static const shellAvatar = 36.0;
  static const shellAvatarIcon = 20.0;
  static const shellLocalPillHeight = 44.0;
  static const shellLocalIcon = 14.0;

  /// From this width the reference puts the search field next to the brand and
  /// the local-only pill before the notifications bell.
  static const shellWideMinWidth = 1100.0;

  /// Owner-reference story and analytics desktop layouts.
  static const storyContentMaxWidth = 1380.0;
  static const storyColumnMinWidth = 900.0;
  static const storyIcon = 20.0;
  static const storyDot = 8.0;
  static const storyHeroIconBox = 44.0;
  static const storyMainFlex = 7;
  static const storySideFlex = 3;
  static const storyChartHeight = 220.0;
  static const storyBarWidth = 22.0;
  static const storyAvatar = 32.0;
  static const storyProgressHeight = 6.0;
  static const storyMemoryHeight = 180.0;
  static const storyYearCardMinHeight = 44.0;
  static const storyStatusBarHeight = 6.0;
  static const analyticsContentMaxWidth = 1380.0;
  static const analyticsColumnMinWidth = 900.0;
  static const analyticsKpiWrapWidth = 660.0;
  static const analyticsEvidenceMaxWidth = 250.0;
  static const analyticsBottomWrapWidth = 620.0;
  static const analyticsIcon = 20.0;
  static const analyticsDot = 8.0;
  static const analyticsMainFlex = 8;
  static const analyticsSideFlex = 3;
  static const analyticsChartHeight = 210.0;
  static const analyticsBarWidth = 22.0;
  static const analyticsAvatar = 32.0;
  static const analyticsProgressHeight = 8.0;
  static const analyticsFooterMinHeight = 44.0;
  static const analyticsKpiMinWidth = 150.0;
  static const analyticsKpiHeight = 76.0;
  static const analyticsKpiIcon = 40.0;

  /// Owner-reference message archive dimensions.
  static const messagesContentMaxWidth = 1380.0;
  static const messagesSidebarFlex = 3;
  static const messagesInboxFlex = 4;
  static const messagesThreadFlex = 6;
  static const messagesThreeColumnMinWidth = 1000.0;
  static const messagesAvatar = 40.0;
  static const messagesUnreadBadge = 24.0;
  static const messagesUnreadMaxCount = 99;
  static const messagesBubbleMaxWidth = 520.0;
  static const messagesThreadAvatar = 56.0;
  static const messagesInboxAvatar = 44.0;
  static const messagesIcon = 18.0;
  static const messagesAttachmentPreviewHeight = 120.0;
  static const messagesAttachmentPreviewWidth = 260.0;
  static const messagesSelectedRailWidth = 3.0;
  static const hairline = 1.0;

  /// Owner-reference media archive dimensions (05-media.jpg).
  static const mediaContentMaxWidth = 1380.0;
  static const mediaShortcutsFlex = 3;
  static const mediaGalleryFlex = 6;
  static const mediaPeopleFlex = 3;
  static const mediaThreeColumnMinWidth = 1000.0;
  static const mediaPeopleCardMaxWidth = 360.0;
  static const mediaAvatar = 40.0;
  static const mediaGridColumns = 4;
  static const mediaGridRows = 3;
  static const mediaMaxVisibleTiles = mediaGridColumns * mediaGridRows;
  /// 05-media.jpg tiles are 163×135 — slightly wider than tall.
  static const mediaTileAspectRatio = 1.2;
  static const mediaIcon = 20.0;
  static const mediaGridIcon = 32.0;
  static const mediaSelectionMark = 28.0;
  static const mediaSelectionIcon = 18.0;
  static const mediaSelectedBorderWidth = 2.0;
  static const mediaTileOverlayHeight = 32.0;
  static const mediaBannerIcon = 40.0;
  static const mediaNoteIcon = 40.0;
  static const mediaTopPeopleCount = 5;

  /// Owner-reference person profile dimensions (06-person.jpg).
  static const personContentMaxWidth = 1380.0;
  static const personThreeColumnMinWidth = 1000.0;
  static const personShortcutsFlex = 3;
  static const personMainFlex = 6;
  static const personSideFlex = 3;
  static const personCoverHeight = 160.0;
  static const personAvatar = 88.0;
  static const personAvatarRing = 3.0;
  static const personAvatarSmall = 40.0;
  static const personIcon = 20.0;
  static const personStatIconBox = 40.0;
  static const personPhotoColumns = 4;
  static const personPhotoAspectRatio = 4 / 3;
  static const personPhotoIcon = 32.0;
  static const personChartHeight = 210.0;
  static const personBarWidth = 20.0;
  static const personChartValueCount = 2;
  static const personDot = 8.0;
  static const personNoteIcon = 40.0;
  static const personInfoRowMinHeight = 44.0;
}

abstract final class TmRadius {
  static const chip = 8.0;
  static const card = 12.0;
  static const pill = 999.0;
}

/// مقياس الخط — 13px هو الحد الأدنى المسموح، ولا شيء أصغر.
abstract final class TmType {
  static const display = 32.0;

  /// رقم KPI كبير (26) — أكبر من [h1] وأصغر من [display].
  static const metric = 26.0;

  static const h1 = 22.0;
  static const h2 = 17.0;
  static const body = 15.0;
  static const caption = 13.0;

  /// ارتفاع السطر الموحّد (1.5) — يمنع تقارب النص العربي.
  static const height = 1.5;

  /// العائلة مكتوبة هنا وليس في الثيم فقط: ستايلات التوكنز تتجاوز
  /// `ThemeData.fontFamily`، فبدونها كان نص الشاشات يُرسم بخط النظام بينما
  /// المرجع (IBM Plex Sans Arabic) لا يُستعمل إلا في عناصر الثيم العامة.
  static const fontFamily = 'IBMPlexSansArabic';

  static TextStyle _s(double size, FontWeight w, Color c) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    fontWeight: w,
    color: c,
    height: height,
  );

  static TextStyle get displayStyle =>
      _s(display, FontWeight.w700, TmColors.text);
  static TextStyle get h1Style => _s(h1, FontWeight.w700, TmColors.text);
  static TextStyle get metricStyle =>
      _s(metric, FontWeight.w700, TmColors.text);
  static TextStyle get h2Style => _s(h2, FontWeight.w600, TmColors.text);
  static TextStyle get bodyStyle => _s(body, FontWeight.w400, TmColors.text);
  static TextStyle get bodyMuted => _s(body, FontWeight.w400, TmColors.text2);
  static TextStyle get captionStyle =>
      _s(caption, FontWeight.w600, TmColors.text2);
}

/// هدف النقر الأدنى (44) — يُستعمل في أزرار الأيقونة والقوائم.
abstract final class TmHit {
  static const min = 44.0;
}
