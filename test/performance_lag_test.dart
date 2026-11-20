import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:type_studio/models/catalogue_entry.dart';
import 'package:type_studio/models/font_model.dart';
import 'package:type_studio/services/catalogue_store.dart';
import 'package:type_studio/services/font_service.dart';
import 'package:type_studio/state/app_state.dart';
import 'package:type_studio/widgets/font_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Performance & Warm Start Tests', () {
    late FontService service;
    late MemoryCatalogueStore memoryStore;

    setUp(() {
      service = FontService.instance;
      service.clearCache();
      memoryStore = MemoryCatalogueStore();
      service.debugCatalogueStore = memoryStore;
      service.debugHttpClient = null;
    });

    tearDown(() {
      service.clearCache();
      service.debugCatalogueStore = null;
      service.debugHttpClient = null;
    });

    test('warm launch returns cached catalogue with isFromCache: true', () async {
      final sampleCatalogueJson = json.encode({
        'items': [
          {
            'family': 'WarmFont1',
            'category': 'sans-serif',
            'variants': ['regular'],
            'files': {'regular': 'https://example.com/warm1.ttf'},
          },
          {
            'family': 'WarmFont2',
            'category': 'serif',
            'variants': ['regular'],
            'files': {'regular': 'https://example.com/warm2.ttf'},
          },
        ],
      });

      await memoryStore.write(FontSortOrder.popularity, sampleCatalogueJson);

      final catalogue = await service.fetchCatalogue(
        sort: FontSortOrder.popularity,
        forceRefresh: false,
      );

      expect(catalogue.isFromCache, isTrue);
      expect(catalogue.entries.length, 2);
      expect(catalogue.entries[0].name, 'WarmFont1');
      expect(catalogue.entries[1].name, 'WarmFont2');
    });

    test('prefetchPreviewBytes caches regular weight without FontLoader.load', () async {
      var downloadCount = 0;
      service.debugHttpClient = MockClient((request) async {
        downloadCount++;
        return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
      });

      const font = FontModel(
        name: 'PrefetchTestFont',
        category: 'Sans Serif',
        description: 'Test prefetch',
        weights: [FontWeight.w400],
        files: {'regular': 'https://example.com/prefetch.ttf'},
      );

      expect(service.isFontLoaded(font.name), isFalse);
      expect(service.cachedFontFileCount, 0);

      await service.prefetchPreviewBytes(font);

      expect(downloadCount, 1);
      expect(service.cachedFontFileCount, 1);
      // Ensure FontLoader.load was NOT called
      expect(service.isFontLoaded(font.name), isFalse);

      // Repeat prefetch is a cache hit and does not download again
      await service.prefetchPreviewBytes(font);
      expect(downloadCount, 1);
    });

    test('ensureFontLoaded routes through FontLoader per-family when file URL exists', () async {
      service.debugHttpClient = MockClient((request) async {
        return http.Response.bytes(Uint8List.fromList([0, 1, 2, 3]), 200);
      });

      // Roboto has a file URL in bundled fonts and API catalogue
      const fontWithUrl = FontModel(
        name: 'IndependentFontABC',
        category: 'Sans Serif',
        description: 'Test',
        weights: [FontWeight.w400],
        files: {'regular': 'https://example.com/fontabc.ttf'},
      );

      service.registerFonts([fontWithUrl]);

      expect(service.isFontLoaded(fontWithUrl.name), isFalse);
      await service.ensureFontLoaded(fontWithUrl.name, font: fontWithUrl);
      expect(service.isFontLoaded(fontWithUrl.name), isTrue);
    });

    test('two preview families load independently; slow or failed does not block other', () async {
      final slowGate = Completer<http.Response>();

      service.debugHttpClient = MockClient((request) async {
        if (request.url.path.contains('slow')) {
          return await slowGate.future;
        }
        if (request.url.path.contains('fail')) {
          return http.Response('Server Error', 500);
        }
        return http.Response.bytes(Uint8List.fromList([1, 2, 3]), 200);
      });

      const slowFont = FontModel(
        name: 'SlowFamily',
        category: 'Sans Serif',
        description: 'Slow',
        weights: [FontWeight.w400],
        files: {'regular': 'https://example.com/slow.ttf'},
      );
      const fastFont = FontModel(
        name: 'FastFamily',
        category: 'Sans Serif',
        description: 'Fast',
        weights: [FontWeight.w400],
        files: {'regular': 'https://example.com/fast.ttf'},
      );
      const failFont = FontModel(
        name: 'FailFamily',
        category: 'Sans Serif',
        description: 'Fail',
        weights: [FontWeight.w400],
        files: {'regular': 'https://example.com/fail.ttf'},
      );

      service.registerFonts([slowFont, fastFont, failFont]);

      final slowFuture = service.ensureFontLoaded(slowFont.name);
      final fastFuture = service.ensureFontLoaded(fastFont.name);

      // Fast family completes even while slow family is waiting
      await fastFuture;
      expect(service.isFontLoaded(fastFont.name), isTrue);
      expect(service.isFontLoaded(slowFont.name), isFalse);

      // Failing family does not block another successful family
      expect(service.ensureFontLoaded(failFont.name), throwsA(isA<FontApiException>()));

      // Clean up slow future
      slowGate.complete(http.Response('abort', 404));
      await slowFuture.catchError((_) {});
    });
  });

  group('Preview interaction cost', () {
    test('typing in the preview controller does not notify PreviewState', () {
      final state = PreviewState();
      addTearDown(state.dispose);
      var notifications = 0;
      state.addListener(() => notifications++);

      state.controller.text = 'Typing should stay local';
      expect(notifications, 0);

      state.fontSize = 40;
      expect(notifications, 1);
    });

    test('previewStyle uses the FontLoader family for the regular face', () {
      final service = FontService.instance;
      service.clearCache();

      const font = FontModel(
        name: 'LoaderRegularFont',
        category: 'Sans Serif',
        description: 'Test',
        weights: [FontWeight.w400],
        files: {'regular': 'https://example.com/regular.ttf'},
      );

      final style = service.previewStyle(
        font,
        const TextStyle(fontSize: 32),
        weight: FontWeight.w400,
        italic: false,
      );

      expect(style.fontFamily, 'LoaderRegularFont');
      expect(style.fontSize, 32);
    });
  });

  group('Static Placeholder & UI Tests', () {
    testWidgets('FontText waiting state renders static text without spinner or stack', (tester) async {
      final entry = CatalogueEntry.fromJson({
        'family': 'PendingSlowFont',
        'category': 'sans-serif',
        'variants': ['regular'],
        'files': {'regular': 'https://example.com/slow.ttf'},
      });
      FontService.instance.registerEntries([entry]);

      final gate = Completer<http.Response>();
      FontService.instance.debugHttpClient = MockClient((request) => gate.future);

      addTearDown(() {
        if (!gate.isCompleted) {
          gate.complete(http.Response('abort', 404));
        }
        FontService.instance.clearCache();
        FontService.instance.debugHttpClient = null;
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FontText(
              fontFamily: 'PendingSlowFont',
              text: 'Preview Text',
            ),
          ),
        ),
      );

      // Verify that during waiting:
      // 1. One Text widget is displayed with preview text
      expect(find.text('Preview Text'), findsOneWidget);

      // 2. No CircularProgressIndicator is built inside FontText
      expect(
        find.descendant(
          of: find.byType(FontText),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );

      // 3. No Stack with transparent duplicate is built inside FontText
      expect(
        find.descendant(
          of: find.byType(FontText),
          matching: find.byType(Stack),
        ),
        findsNothing,
      );

      // Finish the pending request and settle
      gate.complete(http.Response('not found', 404));
      await tester.pumpAndSettle();
    });
  });
}
