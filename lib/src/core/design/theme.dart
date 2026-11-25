import 'package:flutter/material.dart';

import 'tokens.dart';

/// ثيم التطبيق المبني على توكنز [TmColors]/[TmType].
///
/// Flat Design: بلا ظلال، بلا خطوط سميكة. سطح واحد أبيض على رمادي فاتح،
/// وحدّ 1px يفصل البطاقات. الاتجاه RTL يُدار من التطبيق عبر
/// `Directionality`/`flutter_localizations`، وليس من هنا.
ThemeData buildTmewaiTheme({bool rtl = true}) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: TmColors.primary,
      primary: TmColors.primary,
      surface: TmColors.card,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: TmColors.bg,
    fontFamily: 'IBMPlexSansArabic',
    visualDensity: VisualDensity.standard,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: TmColors.text, displayColor: TmColors.text)
        .copyWith(
          displaySmall: TmType.displayStyle,
          headlineSmall: TmType.h1Style,
          titleMedium: TmType.h2Style,
          bodyMedium: TmType.bodyStyle,
          bodySmall: TmType.bodyMuted,
          labelMedium: TmType.captionStyle,
        ),
    dividerTheme: const DividerThemeData(
      color: TmColors.border,
      thickness: 1,
      space: 1,
    ),
    cardTheme: const CardThemeData(
      color: TmColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(TmRadius.card)),
        side: BorderSide(color: TmColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TmColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(TmHit.min, TmHit.min),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(TmRadius.chip)),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TmColors.primary,
        minimumSize: const Size(TmHit.min, TmHit.min),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: TmColors.card,
      indicatorColor: TmColors.primaryTint,
      elevation: 0,
      height: 64,
      labelTextStyle: const WidgetStatePropertyAll(TmStyleCaption.text),
    ),
    iconTheme: const IconThemeData(color: TmColors.text2, size: 24),
    splashFactory: InkSparkle.splashFactory,
  );
}

/// اختصار لستايل التسميات داخل الثيم (يُستعمل أعلاه فقط).
abstract final class TmStyleCaption {
  static const text = TextStyle(
    fontSize: TmType.caption,
    fontWeight: FontWeight.w600,
    color: TmColors.text2,
    height: TmType.height,
  );
}
