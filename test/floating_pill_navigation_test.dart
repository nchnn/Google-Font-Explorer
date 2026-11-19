import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:type_studio/theme/app_theme.dart';
import 'package:type_studio/widgets/floating_pill_navigation.dart';

const _destinations = [
  FloatingPillDestination(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    label: 'Home',
  ),
  FloatingPillDestination(
    icon: Icons.grid_view_rounded,
    selectedIcon: Icons.grid_view_rounded,
    label: 'Explore',
  ),
  FloatingPillDestination(
    icon: Icons.text_fields_rounded,
    selectedIcon: Icons.text_fields_rounded,
    label: 'Preview',
  ),
];

class _Harness extends StatefulWidget {
  const _Harness({this.reduceMotion = false, this.textScale = 1.0});

  final bool reduceMotion;
  final double textScale;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context).copyWith(
          disableAnimations: widget.reduceMotion,
          textScaler: TextScaler.linear(widget.textScale),
        );
        return MediaQuery(data: mediaQuery, child: child!);
      },
      home: Scaffold(
        body: Center(
          child: FloatingPillNavigation(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            destinations: _destinations,
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('renders a short, centred capsule with all three destinations', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    final pill = find.byType(FloatingPillNavigation);
    expect(pill, findsOneWidget);

    final pillRect = tester.getRect(pill);
    // 3 destinations x 76px + 8px of inner padding = 236px, well below the
    // 800px test viewport and never full-width.
    expect(pillRect.width, 236);
    expect(pillRect.width, lessThan(320));
    expect(pillRect.center.dx, closeTo(400, 0.5));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
  });

  testWidgets('active indicator slides smoothly in both directions', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    final indicator = find.byKey(FloatingPillNavigation.activeIndicatorKey);
    final pillRect = tester.getRect(find.byType(FloatingPillNavigation));
    final startX = tester.getCenter(indicator).dx;
    expect(startX, lessThan(pillRect.center.dx));

    final animatedAlign = find.ancestor(
      of: indicator,
      matching: find.byType(AnimatedAlign),
    );
    expect(
      tester.widget<AnimatedAlign>(animatedAlign).duration,
      const Duration(milliseconds: 300),
    );
    expect(
      tester.widget<AnimatedAlign>(animatedAlign).curve,
      Curves.easeInOutCubic,
    );

    // Home -> Explore
    await tester.tap(find.text('Explore'));
    await tester.pump();
    expect(
      tester.widget<AnimatedAlign>(animatedAlign).alignment,
      Alignment.center,
    );

    // Mid-animation the indicator must physically be between the two slots.
    await tester.pump(const Duration(milliseconds: 150));
    final midX = tester.getCenter(indicator).dx;
    expect(midX, greaterThan(startX));
    expect(midX, lessThan(pillRect.center.dx));

    await tester.pumpAndSettle();
    expect(tester.getCenter(indicator).dx, closeTo(pillRect.center.dx, 1));

    // Explore -> Preview
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    final previewX = tester.getCenter(indicator).dx;
    expect(previewX, greaterThan(pillRect.center.dx));

    // Preview -> Home (slides back across the whole pill)
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(tester.getCenter(indicator).dx, closeTo(startX, 1));
  });

  testWidgets('respects the reduced-motion preference', (tester) async {
    await tester.pumpWidget(const _Harness(reduceMotion: true));
    await tester.pumpAndSettle();

    final animatedAlign = find.ancestor(
      of: find.byKey(FloatingPillNavigation.activeIndicatorKey),
      matching: find.byType(AnimatedAlign),
    );
    expect(tester.widget<AnimatedAlign>(animatedAlign).duration, Duration.zero);
  });

  testWidgets('provides labelled semantics and 48px touch targets', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Home'), findsOneWidget);
    expect(find.bySemanticsLabel('Explore'), findsOneWidget);
    expect(find.bySemanticsLabel('Preview'), findsOneWidget);

    final itemSize = tester.getSize(find.byType(InkWell).first);
    expect(itemSize.width, greaterThanOrEqualTo(48));
    expect(itemSize.height, greaterThanOrEqualTo(48));

    handle.dispose();
  });

  testWidgets('fits small phones with large text scaling without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const _Harness(textScale: 2.0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final pillRect = tester.getRect(find.byType(FloatingPillNavigation));
    expect(pillRect.width, 236);
    expect(pillRect.left, greaterThanOrEqualTo(16));
    expect(pillRect.right, lessThanOrEqualTo(304));
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
  });

  testWidgets('stays compact and centred in landscape orientation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final pillRect = tester.getRect(find.byType(FloatingPillNavigation));
    expect(pillRect.width, 236);
    expect(pillRect.center.dx, closeTo(400, 0.5));
    expect(pillRect.height, lessThan(80));
  });
}
