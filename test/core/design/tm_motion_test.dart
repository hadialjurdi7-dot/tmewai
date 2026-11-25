import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_data_agent/src/core/design/tm_motion.dart';

/// Wrap [child] the way the app does, with knobs for the two flags the motion
/// widgets read: the platform and the OS "reduce motion" setting.
Widget _host(
  Widget child, {
  TargetPlatform platform = TargetPlatform.linux,
  bool reduceMotion = false,
}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduceMotion),
  child: Theme(
    data: ThemeData(platform: platform),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Center(child: child),
    ),
  ),
);

void main() {
  testWidgets('TmCardHover animates on a desktop pointer', (tester) async {
    await tester.pumpWidget(_host(const TmCardHover(child: Text('بطاقة'))));
    expect(find.byType(AnimatedContainer), findsOneWidget);
  });

  testWidgets('TmCardHover is inert when the OS asks for reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const TmCardHover(child: Text('بطاقة')), reduceMotion: true),
    );
    expect(find.byType(AnimatedContainer), findsNothing);
    expect(find.text('بطاقة'), findsOneWidget);
  });

  testWidgets('TmCardHover is inert on a touch platform', (tester) async {
    await tester.pumpWidget(
      _host(
        const TmCardHover(child: Text('بطاقة')),
        platform: TargetPlatform.android,
      ),
    );
    expect(find.byType(AnimatedContainer), findsNothing);
  });

  testWidgets('TmLoader keeps a static ring under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const TmLoader(), reduceMotion: true));
    await tester.pump(const Duration(seconds: 2));
    // Nothing scheduled to repaint: the arc is drawn once and left alone.
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.byType(TmLoader), findsOneWidget);
  });

  testWidgets('TmPulse renders its child untouched under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const TmPulse(child: Text('نائب')), reduceMotion: true),
    );
    expect(find.byType(FadeTransition), findsNothing);
    expect(find.text('نائب'), findsOneWidget);
  });
}
