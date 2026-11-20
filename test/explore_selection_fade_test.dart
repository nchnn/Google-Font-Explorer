// test/explore_selection_fade_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:type_studio/app.dart';
import 'package:type_studio/models/font_model.dart';
import 'package:type_studio/services/font_service.dart';
import 'package:type_studio/widgets/fade_in_batch.dart';
import 'package:type_studio/widgets/font_text.dart';

// The home screen blob animation uses repeat(), preventing pumpAndSettle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _openExplore(
  WidgetTester tester, {
  Size size = const Size(1080, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const TypeStudioApp());
  await _settle(tester);
  await tester.tap(find.byIcon(Icons.grid_view_rounded).first);
  await _settle(tester);
}

Future<void> _pumpFadeInBatch(
  WidgetTester tester, {
  required int index,
  required int fadeFrom,
  bool disableAnimations = false,
}) async {
  // copyWith, not a bare MediaQueryData: a bare one would zero the size.
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
        child: FadeInBatch(
          index: index,
          fadeFrom: fadeFrom,
          child: const Text('card'),
        ),
      ),
    ),
  ));
  await tester.pump();
}

Finder _fadeInside() => find.descendant(
      of: find.byType(FadeInBatch),
      matching: find.byType(FadeTransition),
    );

/// Test-only model whose missing file URL fails a load before any network
/// request, while counting each attempt to resolve one.
class _CountingFont extends FontModel {
  _CountingFont(String name)
      : super(
          name: name,
          category: 'Sans Serif',
          description: 'Test-only font used to count load attempts.',
          weights: const [FontWeight.w400],
        );

  int fileUrlLookups = 0;

  @override
  String? getFileUrl({
    FontWeight weight = FontWeight.w400,
    bool italic = false,
  }) {
    fileUrlLookups++;
    return null;
  }
}

void main() {
  testWidgets('selection survives a search and clearing it', (tester) async {
    await _openExplore(tester);
    // Roboto is selected by default (availableFonts.first).
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Lato');
    await tester.pump(const Duration(milliseconds: 350));
    await _settle(tester);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing,
        reason: 'Lato is shown, Roboto is filtered out, but the selection is kept');

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump(const Duration(milliseconds: 350));
    await _settle(tester);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget,
        reason: 'clearing the search restores Roboto and its selected state');
  });

  testWidgets('selection survives a category change and a page reset', (tester) async {
    await _openExplore(tester);

    final serif = find.widgetWithText(FilterChip, 'Serif');
    await tester.ensureVisible(serif);
    await tester.tap(serif);
    await _settle(tester);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing,
        reason: 'Roboto is not a serif, so the selection has no visible card');

    final all = find.widgetWithText(FilterChip, 'All');
    await tester.ensureVisible(all);
    await tester.tap(all);
    await _settle(tester);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('appended batch items are inside a fade range', (tester) async {
    // Taller than the other fixtures: on a 1200-high viewport the first five
    // cards still leave 318 px of scroll extent, which is more than the 240 px
    // viewport-fill threshold, so the fill check legitimately stays idle and
    // no batch is appended. 1400 leaves it too short to scroll, which is the
    // state this test needs.
    await _openExplore(tester, size: const Size(1080, 1400));
    final cards = tester
        .widgetList<FadeInBatch>(find.byType(FadeInBatch, skipOffstage: false))
        .toList();
    expect(cards.length, greaterThan(5),
        reason: 'the viewport fill check must have appended a batch');

    final boundaries = cards.map((card) => card.fadeFrom).toSet();
    expect(boundaries.length, 1, reason: 'every card must share one fade boundary');
    final fadeFrom = boundaries.single;
    expect(fadeFrom, greaterThan(0),
        reason: 'an appended batch must mark where the fade starts');
    expect(cards.where((card) => card.index >= fadeFrom), isNotEmpty,
        reason: 'the newly appended cards must be inside the fade range');
  });

  testWidgets('batch items fade in when animations are enabled', (tester) async {
    await _pumpFadeInBatch(tester, index: 2, fadeFrom: 0);
    expect(_fadeInside(), findsOneWidget);

    final fade = tester.widget<FadeTransition>(_fadeInside());
    expect(fade.opacity.value, 0.0);
    await tester.pump(const Duration(milliseconds: 240));
    expect(fade.opacity.value, 1.0);
  });

  testWidgets('a mid-fade card finishes when the boundary advances', (tester) async {
    await _pumpFadeInBatch(tester, index: 2, fadeFrom: 0);
    final fade = tester.widget<FadeTransition>(_fadeInside());
    await tester.pump(const Duration(milliseconds: 60));
    final midway = fade.opacity.value;
    expect(midway, greaterThan(0.0));
    expect(midway, lessThan(1.0));

    // The viewport fill check appends a batch and moves the boundary past this
    // card while it is still fading. The card was created inside the fade range,
    // so it must finish its entrance rather than snap to full opacity.
    await _pumpFadeInBatch(tester, index: 2, fadeFrom: 3);
    expect(_fadeInside(), findsOneWidget,
        reason: 'an advancing boundary must not drop a mid-fade transition');
    final afterAdvance = tester.widget<FadeTransition>(_fadeInside());
    expect(identical(afterAdvance.opacity, fade.opacity), isTrue,
        reason: 'the same animation must keep running, not a fresh one');

    await tester.pump(const Duration(milliseconds: 240));
    expect(fade.opacity.value, 1.0);
  });

  testWidgets('items before the fade boundary never animate', (tester) async {
    await _pumpFadeInBatch(tester, index: 1, fadeFrom: 2);
    expect(_fadeInside(), findsNothing);
    expect(find.text('card'), findsOneWidget);
  });

  testWidgets('reduced motion renders batch items without a fade', (tester) async {
    await _pumpFadeInBatch(tester, index: 2, fadeFrom: 0, disableAnimations: true);
    expect(_fadeInside(), findsNothing);
    expect(find.text('card'), findsOneWidget);
  });

  testWidgets('list previews request regular weight only', (tester) async {
    await _openExplore(tester);
    // The IndexedStack keeps Home and Preview mounted but marks only the
    // selected page onstage, so the default (onstage-only) finder reaches the
    // Explore cards. skipOffstage: false would return Home's hero preview
    // first, which is a different widget with a different style.
    final preview =
        tester.widgetList<FontText>(find.byType(FontText)).first;
    expect(preview.style.fontWeight, FontWeight.w400,
        reason: 'list previews must not request a heavier variant');
    expect(preview.showErrorNotice, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failing preview is not re-requested on every rebuild', (tester) async {
    // Not in google_fonts and has no catalogue file URL, so the load fails fast
    // without touching the network.
    await tester.pumpWidget(const MaterialApp(
      home: FontText(
        fontFamily: 'DefinitelyNotAFontXYZ',
        text: 'preview',
        showErrorNotice: false,
      ),
    ));
    // An unstable future re-subscribes on every build and never settles.
    await _settle(tester);
    expect(find.text('preview'), findsOneWidget);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.text('preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed preview load is reused across plain rebuilds', (tester) async {
    // The model is registered but has no file URL, so each load attempt fails
    // fast without touching the network and increments fileUrlLookups.
    final font = _CountingFont('CountingFailureFontXYZ');
    FontService.instance.registerFonts([font]);

    late StateSetter rebuild;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          // Not const: a fresh FontText instance is what forces the State to
          // rebuild, which is the production condition under test.
          return FontText(
            fontFamily: font.name,
            text: 'preview',
            showErrorNotice: false,
          );
        },
      ),
    ));
    await _settle(tester);
    expect(font.fileUrlLookups, 1, reason: 'the first build starts one load');

    for (var i = 0; i < 5; i++) {
      rebuild(() {});
      await tester.pump();
    }
    expect(font.fileUrlLookups, 1,
        reason: 'plain rebuilds must reuse the failed future, not re-request the font');
    expect(find.text('preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
