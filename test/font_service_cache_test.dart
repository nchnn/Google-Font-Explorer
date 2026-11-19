import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:type_studio/services/font_service.dart';

void main() {
  test('font file cache limit is 64', () {
    expect(FontService.fontFileCacheLimit, 64);
  });

  test('previewFont returns the same future for the same family', () {
    // A family that is not in google_fonts and has no file URL, so this never
    // touches the network: ensureFontLoaded fails fast instead.
    final a = FontService.instance.previewFont('DefinitelyNotAFontXYZ');
    final b = FontService.instance.previewFont('DefinitelyNotAFontXYZ');
    expect(identical(a, b), isTrue);
    return a.catchError((_) {});
  });

  test('previewFont memoises separately per family', () {
    final a = FontService.instance.previewFont('DefinitelyNotAFontXYZ');
    final b = FontService.instance.previewFont('AnotherMissingFontXYZ');
    expect(identical(a, b), isFalse);
    return Future.wait([a.catchError((_) {}), b.catchError((_) {})]);
  });

  test('a failed stale load does not evict a newer memoised future', () {
    // Regression: clearCache() while a preview load is in flight lets a second
    // previewFont() call store a newer future under the same key. When the
    // stale future fails, its cleanup must only remove its own entry.
    final service = FontService.instance;
    service.clearCache();

    // Not in google_fonts and no file URL, so both loads fail fast without
    // touching the network.
    const family = 'DefinitelyNotAFontXYZ';

    final first = service.previewFont(family);
    service.clearCache();
    final second = service.previewFont(family);
    expect(identical(first, second), isFalse);

    // Swallow both failures; only the memoisation bookkeeping matters here.
    first.catchError((Object _) {});
    second.catchError((Object _) {});

    var newerFutureStillMemoised = false;
    return first
        .then<void>(
          (_) {},
          onError: (Object _) {
            // Runs while `second` is still the entry for this family (its own
            // failure cleanup is queued strictly after this callback).
            newerFutureStillMemoised =
                identical(service.previewFont(family), second);
          },
        )
        .then((_) {
          expect(newerFutureStillMemoised, isTrue);
        });
  });

  test('clearCache empties the byte cache', () {
    FontService.instance.clearCache();
    expect(FontService.instance.cachedFontFileCount, 0);
  });

  test('byte cache evicts past the cap while clearCache empties it', () {
    final service = FontService.instance;
    service.clearCache();
    for (var i = 0; i < FontService.fontFileCacheLimit + 3; i++) {
      service.debugCacheFontBytes('https://example.com/$i.ttf', Uint8List.fromList([i]));
    }
    expect(service.cachedFontFileCount, FontService.fontFileCacheLimit);
    service.clearCache();
    expect(service.cachedFontFileCount, 0);
  });
}
