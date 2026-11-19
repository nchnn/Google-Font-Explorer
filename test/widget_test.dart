import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:type_studio/app.dart';
import 'package:type_studio/config/google_fonts_config.dart';
import 'package:type_studio/models/font_model.dart';
import 'package:type_studio/screens/preview_screen.dart';
import 'package:type_studio/services/font_service.dart';
import 'package:type_studio/state/app_state.dart';
import 'package:type_studio/widgets/floating_pill_navigation.dart';

void main() {
  group('FontModel Tests', () {
    test('FontModel.fromJson parses Google Fonts Developer API item correctly', () {
      final sampleJson = {
        'family': 'Exo 2',
        'variants': ['100', '100italic', '300', 'regular', 'italic', '700', '900'],
        'subsets': ['latin', 'latin-ext'],
        'version': 'v20',
        'lastModified': '2023-05-02',
        'files': {
          '100': 'http://fonts.gstatic.com/s/exo2/v20/7cHrv4okm5zmbt6PFND-.ttf',
          'regular': 'http://fonts.gstatic.com/s/exo2/v20/7cHrv4okm5zmbt5jFND-.ttf',
          '700': 'http://fonts.gstatic.com/s/exo2/v20/7cHrv4okm5zmbt5FFtD-.ttf',
        },
        'category': 'sans-serif',
      };

      final font = FontModel.fromJson(sampleJson);

      expect(font.name, 'Exo 2');
      expect(font.category, 'Sans Serif');
      expect(font.variants.length, 7);
      expect(font.weights, containsAll([
        FontWeight.w100,
        FontWeight.w300,
        FontWeight.w400,
        FontWeight.w700,
        FontWeight.w900,
      ]));

      // Verify HTTP URLs were converted to HTTPS
      expect(font.files['regular'], startsWith('https://'));
      expect(font.getFileUrl(weight: FontWeight.w700), startsWith('https://'));
      expect(font.getFileUrl(weight: FontWeight.w400), startsWith('https://'));
      expect(font.getFileUrl(weight: FontWeight.w200), isNotNull);
    });

    test('FontModel weightsLabel and variantsLabel formatting', () {
      const font = FontModel(
        name: 'TestFont',
        category: 'Display',
        description: 'Test description',
        weights: [FontWeight.w300, FontWeight.w400, FontWeight.w700],
        variants: ['300', 'regular', '700'],
      );

      expect(font.weightsLabel, contains('Light'));
      expect(font.weightsLabel, contains('Regular'));
      expect(font.weightsLabel, contains('Bold'));
      expect(font.variantsLabel, contains('3 variants'));
    });
  });

  group('FontService Tests', () {
    test('isGoogleFontsSupported correctly distinguishes known fonts', () {
      expect(FontService.isGoogleFontsSupported('Roboto'), isTrue);
      expect(FontService.isGoogleFontsSupported('Open Sans'), isTrue);
      expect(FontService.isGoogleFontsSupported('NonExistentCustomFont12345'), isFalse);
    });

    test('Registry initializes with bundled availableFonts', () {
      final service = FontService.instance;
      expect(service.getFont('Roboto'), isNotNull);
      expect(service.getFont('Poppins'), isNotNull);
      expect(service.getFont('Playfair Display'), isNotNull);
    });

    test('Catalogue sort enum has expected API values', () {
      expect(FontSortOrder.popularity.apiValue, 'popularity');
      expect(FontSortOrder.alphabetical.apiValue, 'alpha');
      expect(FontSortOrder.trending.apiValue, 'trending');
    });

    test('FontApiConfig has clearly documented API key location', () {
      expect(FontApiConfig.apiBaseUrl, 'https://www.googleapis.com/webfonts/v1/webfonts');
      expect(FontApiConfig.apiKey, isNotEmpty);
    });
  });

  group('TypeStudioApp Widget Tests', () {
    testWidgets('App renders Home screen with TypeStudio title and theme toggle', (tester) async {
      await tester.pumpWidget(const TypeStudioApp());
      await tester.pump();

      expect(find.text('TypeStudio'), findsWidgets);
      expect(find.text('GOOGLE FONTS EXPLORER'), findsOneWidget);
      expect(find.text('Make every word'), findsOneWidget);
      expect(find.text('Your current font'), findsOneWidget);

      // Verify theme toggle button is present
      expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);

      // Tap theme toggle to switch to Dark Mode
      await tester.tap(find.byIcon(Icons.wb_sunny_rounded));
      await tester.pumpAndSettle();

      // Verify icon changed to Moon for Dark Mode
      expect(find.byIcon(Icons.nightlight_round), findsOneWidget);

      // Tap again to switch back to Light Mode
      await tester.tap(find.byIcon(Icons.nightlight_round));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
    });

    testWidgets('Bottom navigation is a compact floating pill with three tabs', (tester) async {
      await tester.pumpWidget(const TypeStudioApp());
      await tester.pump();

      // The full-width Material navigation bar has been replaced by the pill.
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(FloatingPillNavigation), findsOneWidget);

      // Exactly 3 navigation destinations.
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('About'), findsNothing);

      // The pill is short, centred, and lifted above the bottom edge.
      final pillRect = tester.getRect(find.byType(FloatingPillNavigation));
      final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(pillRect.width, lessThan(screenSize.width * 0.6));
      expect(pillRect.center.dx, closeTo(screenSize.width / 2, 1));
      expect(pillRect.bottom, lessThan(screenSize.height));

      // Navigate to Explore tab
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      expect(find.text('Explore fonts'), findsOneWidget);

      // Navigate to Preview tab
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.text('Typography tester'), findsOneWidget);
      expect(find.text('LIVE PREVIEW'), findsOneWidget);

      // Navigate back Home
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Make every word'), findsOneWidget);

      // Verify fixed preview and scrollbar in controls section
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      expect(find.byType(Scrollbar), findsOneWidget);
      expect(find.text('Typography controls'), findsOneWidget);
      expect(find.text('Font size'), findsOneWidget);
      // Bring the weight control into view instead of hiding the fact that it
      // starts below the fold; the assertion must prove it is reachable.
      await tester.dragUntilVisible(
        find.text('Font weight'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('Font weight'), findsOneWidget);
      expect(find.text('Text alignment', skipOffstage: false), findsOneWidget);
    });

    testWidgets('Switching tabs preserves Explore search state', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TypeStudioApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Roboto');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Roboto'), findsWidgets);

      // Leave and return; IndexedStack keeps the Explore state alive.
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();

      final restoredField = tester.widget<TextField>(find.byType(TextField).first);
      expect(restoredField.controller?.text, 'Roboto');
      expect(find.text('Roboto'), findsWidgets);
    });

    testWidgets('scrolled content stays clear of the floating pill', (tester) async {
      await tester.pumpWidget(const TypeStudioApp());
      await tester.pumpAndSettle();

      final pillTop =
          tester.getTopLeft(find.byType(FloatingPillNavigation)).dy;

      // Home: the final typography sample must rest above the pill.
      for (var i = 0; i < 3; i++) {
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -20000),
        );
        await tester.pumpAndSettle();
      }
      final lastHomeItem =
          find.textContaining('Bold / Italic', skipOffstage: false);
      expect(lastHomeItem, findsOneWidget);
      expect(tester.getBottomLeft(lastHomeItem).dy, lessThan(pillTop));

      // Preview: the final reset button must also clear the pill.
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -20000));
        await tester.pumpAndSettle();
      }
      final resetButton =
          find.text('Reset preview settings', skipOffstage: false);
      expect(resetButton, findsOneWidget);
      expect(tester.getBottomLeft(resetButton).dy, lessThan(pillTop));
    });

    testWidgets('floating pill respects the bottom safe area', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);

      await tester.pumpWidget(const TypeStudioApp());
      await tester.pumpAndSettle();

      final pillRect = tester.getRect(find.byType(FloatingPillNavigation));
      // 12px design gap + 24px system inset above the bottom edge.
      expect(pillRect.bottom, closeTo(900 - 24 - 12, 0.5));
    });

    testWidgets('programmatic navigation keeps the indicator in sync', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TypeStudioApp());
      await tester.pumpAndSettle();

      Alignment indicatorAlignment() {
        final animatedAlign = find.ancestor(
          of: find.byKey(FloatingPillNavigation.activeIndicatorKey),
          matching: find.byType(AnimatedAlign),
        );
        return tester.widget<AnimatedAlign>(animatedAlign).alignment as Alignment;
      }

      // Home's call-to-action navigates to Explore without tapping the pill.
      await tester.tap(find.text('Explore fonts'));
      await tester.pumpAndSettle();
      expect(
        find.text('Discover typography from the live Google Fonts catalogue.'),
        findsOneWidget,
      );
      expect(indicatorAlignment(), Alignment.center);

      // Preview's "Customize preview" shortcut navigates back home then to
      // Preview; the indicator follows the actual screen in both cases.
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customize preview'));
      await tester.pumpAndSettle();
      expect(find.text('Typography tester'), findsOneWidget);
      expect(indicatorAlignment(), const Alignment(1, 0));
    });

    testWidgets('navigation overlay adds no background behind the pill', (tester) async {
      await tester.pumpWidget(const TypeStudioApp());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);

      // Walk from the pill up to the app's body Stack and make sure no wrapper
      // paints a rectangle behind it. Only the pill itself may draw a surface.
      final pillElement = tester.element(find.byType(FloatingPillNavigation));
      final wrappers = <Type>{};
      pillElement.visitAncestorElements((element) {
        final widget = element.widget;
        if (widget is Stack) return false;
        wrappers.add(widget.runtimeType);
        return true;
      });

      expect(wrappers.contains(Container), isFalse);
      expect(wrappers.contains(ColoredBox), isFalse);
      expect(wrappers.contains(Material), isFalse);
      expect(wrappers.contains(DecoratedBox), isFalse);
      expect(wrappers.contains(PhysicalModel), isFalse);
      expect(wrappers.contains(BottomAppBar), isFalse);
    });

    testWidgets('Explore tab allows debounced searching and filtering fonts', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TypeStudioApp());
      await tester.pumpAndSettle();

      // Navigate to Explore
      await tester.tap(find.byIcon(Icons.grid_view_rounded).first);
      await tester.pumpAndSettle();

      // Enter search query
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Roboto');
      // Wait for debounce timer (300ms)
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Roboto'), findsWidgets);

      // Enter search query with no matches
      await tester.enterText(searchField, 'NonExistentZyxwv');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('No matching font families found', skipOffstage: false), findsOneWidget);

      // Clear search
      await tester.tap(find.text('Clear search & filters', skipOffstage: false));
      await tester.pumpAndSettle();

      expect(find.text('No matching font families found', skipOffstage: false), findsNothing);
    });

    testWidgets('Typography controls render all options and update state', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TypeStudioApp());
      await tester.pumpAndSettle();

      // Navigate to Preview tab
      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();

      // Check header and badge
      expect(find.text('Typography controls'), findsOneWidget);
      expect(find.text('REAL-TIME'), findsOneWidget);

      // Verify live preview is editable and can be typed into directly
      final previewField = find.byType(TextField).first;
      await tester.enterText(previewField, 'Hello TypeStudio');
      await tester.pumpAndSettle();
      expect(find.text('Hello TypeStudio'), findsOneWidget);

      // Verify clear text feature
      expect(find.text('Clear text'), findsOneWidget);
      await tester.tap(find.text('Clear text'));
      await tester.pumpAndSettle();
      expect(find.text('Clear text'), findsNothing);

      // Check Font size and checkpoints
      expect(find.text('Font size'), findsOneWidget);
      expect(find.text('32 px'), findsOneWidget);

      // Check Weight Vector
      await tester.dragUntilVisible(
        find.text('700'),
        find.byType(ListView),
        const Offset(0, -150),
      );
      expect(find.text('Font weight'), findsOneWidget);
      expect(find.text('300'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('700'), findsOneWidget);

      // Tap weight 700
      await tester.tap(find.text('700'));
      await tester.pumpAndSettle();
      expect(find.text('Bold (700)'), findsOneWidget);

      // Check Leading & Tracking
      await tester.dragUntilVisible(
        find.text('Letter spacing'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('Line spacing'), findsOneWidget);
      expect(find.text('1.30'), findsOneWidget);
      expect(find.text('Tight (1.0)'), findsOneWidget);
      expect(find.text('Loose (2.0)'), findsOneWidget);

      expect(find.text('Letter spacing'), findsOneWidget);
      expect(find.text('+0.00 em'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);

      // Test reset
      await tester.dragUntilVisible(
        find.text('Reset preview settings'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.tap(find.text('Reset preview settings'));
      await tester.pumpAndSettle();

      // Verify reset back to 32px and Regular (400)
      expect(find.text('32 px'), findsOneWidget);
      expect(find.text('Regular (400)'), findsOneWidget);
    });

    testWidgets('Typography controls dynamically reflect font weights from font model', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const TypeStudioApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Preview'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(PreviewScreen));
      final appState = AppState.read(context);
      final preview = PreviewState.read(context);

      const customFont = FontModel(
        name: 'SingleWeightFont',
        category: 'Serif',
        description: 'Test single weight font',
        weights: [FontWeight.w400],
      );

      appState.selectFont(customFont, preview: preview);
      await tester.pumpAndSettle();

      expect(find.text('400'), findsOneWidget);
      expect(find.text('300'), findsNothing);
      expect(find.text('700'), findsNothing);
    });
  });
}
