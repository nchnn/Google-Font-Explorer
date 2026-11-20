import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:type_studio/services/catalogue_store.dart';
import 'package:type_studio/services/font_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MemoryCatalogueStore', () {
    late MemoryCatalogueStore store;

    setUp(() {
      store = MemoryCatalogueStore();
    });

    test('read returns null when empty', () async {
      expect(await store.read(FontSortOrder.popularity), isNull);
    });

    test('write retains last-used sort only', () async {
      await store.write(FontSortOrder.popularity, 'body-popularity');
      expect(await store.read(FontSortOrder.popularity), 'body-popularity');

      // Writing a different sort should overwrite / clear the previous one
      await store.write(FontSortOrder.alphabetical, 'body-alpha');
      expect(await store.read(FontSortOrder.alphabetical), 'body-alpha');
      expect(await store.read(FontSortOrder.popularity), isNull);
    });

    test('clear empties store', () async {
      await store.write(FontSortOrder.trending, 'body-trending');
      await store.clear();
      expect(await store.read(FontSortOrder.trending), isNull);
    });
  });

  group('SharedPreferencesCatalogueStore', () {
    late SharedPreferencesCatalogueStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      store = SharedPreferencesCatalogueStore();
    });

    test('read returns null when empty', () async {
      expect(await store.read(FontSortOrder.popularity), isNull);
    });

    test('write stores last-used sort only under versioned key', () async {
      await store.write(FontSortOrder.popularity, '{"items":["pop"]}');
      expect(await store.read(FontSortOrder.popularity), '{"items":["pop"]}');

      // Switching sort clears other sort keys
      await store.write(FontSortOrder.trending, '{"items":["trend"]}');
      expect(await store.read(FontSortOrder.trending), '{"items":["trend"]}');
      expect(await store.read(FontSortOrder.popularity), isNull);
    });

    test('clear removes all versioned sort keys', () async {
      await store.write(FontSortOrder.alphabetical, '{"items":["alpha"]}');
      await store.clear();
      expect(await store.read(FontSortOrder.alphabetical), isNull);
    });
  });
}
