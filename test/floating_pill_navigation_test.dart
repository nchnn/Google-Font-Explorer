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

/// Expected total pill width: innerWidth + padding + border.
/// innerWidth(3) = 116 + 52*2 = 220. Padding = 8. Total = 228.
const _expectedPillWidth = 228.0;

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
  testWidgets('renders a compact, centred capsule with all three destinations', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    final pill = find.byType(FloatingPillNavigation);
    expect(pill, findsOneWidget);

    final pillRect = tester.getRect(pill);
    expect(pillRect.width, closeTo(_expectedPillWidth, 1));
    expect(pillRect.width, lessThan(320));
    expect(pillRect.center.dx, closeTo(400, 1));

    // Active tab (Home) label is visible; inactive labels exist in tree
    // but have zero opacity / zero width.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
  });

  testWidgets('active indicator slides smoothly between tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const _Harness());
    await tester.pumpAndSettle();

    final indicator = find.byKey(FloatingPillNavigation.activeIndicatorKey);
    final startX = tester.getCenter(indicator).dx;
    final pillCenter = tester.getCenter(find.byType(FloatingPillNavigation)).dx;
    expect(startX, lessThan(pillCenter));

    // Home -> Explore: tap the icon (labels for inactive tabs are hidden
    // behind zero-width ClipRect, so tap by icon).
    await tester.tap(find.byIcon(Icons.grid_view_rounded).first);
    await tester.pump();

    // Mid-animation: indicator moves between the two slots.
    await tester.pump(const Duration(milliseconds: 150));
    final midX = tester.getCenter(indicator).dx;
    expect(midX, greaterThan(startX));

    await tester.pumpAndSettle();
    final exploreX = tester.getCenter(indicator).dx;
    expect(exploreX, greaterThan(startX));

    // Explore -> Preview
    await tester.tap(find.byIcon(Icons.text_fields_rounded).first);
    await tester.pumpAndSettle();
    final previewX = tester.getCenter(indicator).dx;
    expect(previewX, greaterThan(exploreX));

    // Preview -> Home (slides back across the whole pill)
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(tester.getCenter(indicator).dx, closeTo(startX, 1));
  });

  testWidgets('respects the reduced-motion preference', (tester) async {
    await tester.pumpWidget(const _Harness(reduceMotion: true));
    await tester.pumpAndSettle();

    final indicator = find.byKey(FloatingPillNavigation.activeIndicatorKey);
    final startX = tester.getCenter(indicator).dx;

    // Switching tabs jumps instantly with no animation frames.
    await tester.tap(find.byIcon(Icons.grid_view_rounded).first);
    await tester.pump();
    final afterX = tester.getCenter(indicator).dx;
    expect(afterX, isNot(closeTo(startX, 1)));
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
    expect(pillRect.width, closeTo(_expectedPillWidth, 1));
    expect(pillRect.left, greaterThanOrEqualTo(0));
    expect(find.text('Home'), findsOneWidget);
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
    expect(pillRect.width, closeTo(_expectedPillWidth, 1));
    expect(pillRect.center.dx, closeTo(400, 1));
    expect(pillRect.height, lessThan(80));
  });
}
