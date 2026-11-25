import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

// حركة الهوية — مؤشر تحميل، رفع بطاقة عند المرور، ونبض خفيف لحين التحميل.
//
// قواعد الملف: كل لون من TmColors، وكل مقاس من TmSpace/TmSize/TmRadius.
// الحركة فقط هي المضافة؛ لا خلفية داكنة ولا تدرّج مضيء ولا لون خارج التوكنز.
// كل حركة هنا تحترم MediaQuery.disableAnimations (تقليل الحركة).

/// مؤشر تحميل بهوية التطبيق: قوس أصلي يتدرّج بين [TmColors.primary] و
/// [TmColors.primarySoft]، دورة كاملة كل [revolution].
///
/// عند طلب تقليل الحركة يُرسم القوس ثابتاً (بلا دوران) بلا أي إطار نابض.
class TmLoader extends StatefulWidget {
  const TmLoader({
    super.key,
    this.size = defaultSize,
    this.strokeWidth = defaultStrokeWidth,
  });

  /// القطر الافتراضي (28) وسماكة الخط (3) — قيم المكوّن لا للشاشات.
  static const defaultSize = 28.0;
  static const defaultStrokeWidth = 3.0;

  /// زمن دورة كاملة: 1.1 ثانية.
  static const revolution = Duration(milliseconds: 1100);

  final double size;
  final double strokeWidth;

  @override
  State<TmLoader> createState() => _TmLoaderState();
}

class _TmLoaderState extends State<TmLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TmLoader.revolution,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _TmLoaderPainter(
            turns: _controller.value,
            strokeWidth: widget.strokeWidth,
          ),
        ),
      ),
    ),
  );
}

class _TmLoaderPainter extends CustomPainter {
  const _TmLoaderPainter({required this.turns, required this.strokeWidth});

  /// جزء الدورة المكتمل (0–1) والقوس المرئي من الدورة (0.7 ≈ 252°).
  final double turns;
  final double strokeWidth;

  static const _arcTurns = 0.7;

  @override
  void paint(Canvas canvas, Size size) {
    final arcRect = (Offset.zero & size).deflate(strokeWidth / 2);
    if (arcRect.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [TmColors.primarySoft, TmColors.primary, TmColors.primarySoft],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(arcRect);

    canvas.drawArc(
      arcRect,
      -math.pi / 2 + turns * 2 * math.pi,
      _arcTurns * 2 * math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_TmLoaderPainter oldDelegate) =>
      oldDelegate.turns != turns || oldDelegate.strokeWidth != strokeWidth;
}

/// يرفع البطاقة 2px عند المرور بالمؤشر، ويدفّئ حدّها من [TmColors.border]
/// إلى [TmColors.primarySoft]، ويضيف ظلاً خفيفاً — كل ذلك في [duration].
///
/// على أجهزة اللمس لا يوجد مرور مؤشر، فيُعاد الطفل كما هو بلا أي التفاف.
class TmCardHover extends StatefulWidget {
  const TmCardHover({
    super.key,
    required this.child,
    this.borderRadius = TmRadius.card,
  });

  /// مقدار الرفع بالبكسل وزمن الانتقال.
  static const lift = 2.0;
  static const duration = Duration(milliseconds: 140);

  final Widget child;
  final double borderRadius;

  @override
  State<TmCardHover> createState() => _TmCardHoverState();
}

class _TmCardHoverState extends State<TmCardHover> {
  bool _hovered = false;

  static const _shadowBlur = 10.0;
  static const _shadowOffset = 2.0;
  static const _shadowOpacity = 0.06;

  /// مؤشر المرور موجود على سطح المكتب؛ ومع تقليل الحركة لا نحرّك شيئاً أصلاً.
  static bool _supportsHover(BuildContext context) =>
      !(MediaQuery.maybeOf(context)?.disableAnimations ?? false) &&
      switch (Theme.of(context).platform) {
        TargetPlatform.linux ||
        TargetPlatform.macOS ||
        TargetPlatform.windows => true,
        _ => false,
      };

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_supportsHover(context)) return widget.child;
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedContainer(
        duration: TmCardHover.duration,
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(
          0,
          _hovered ? -TmCardHover.lift : 0,
          0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: Border.all(
            color: _hovered ? TmColors.primarySoft : TmColors.border,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: TmColors.text.withValues(alpha: _shadowOpacity),
                    blurRadius: _shadowBlur,
                    offset: const Offset(0, _shadowOffset),
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: widget.child,
      ),
    );
  }
}

/// نبض شفافية خفيف جداً (0.55 → 1.0 خلال 1.6 ثانية، ذهاباً وإياباً) لمربّعات
/// العناصر النائبة أثناء تحميل البيانات. عند تقليل الحركة يُعاد الطفل كاملاً.
class TmPulse extends StatefulWidget {
  const TmPulse({super.key, required this.child, this.lowestOpacity = 0.55});

  /// مدة النبضة الكاملة وأدنى شفافية.
  static const duration = Duration(milliseconds: 1600);

  final Widget child;
  final double lowestOpacity;

  @override
  State<TmPulse> createState() => _TmPulseState();
}

class _TmPulseState extends State<TmPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TmPulse.duration,
  );

  late final Animation<double> _opacity = Tween<double>(
    begin: widget.lowestOpacity,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return widget.child;
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}
