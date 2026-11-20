import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:type_studio/models/catalogue_entry.dart';
import 'package:type_studio/models/font_model.dart';

void main() {
  group('CatalogueEntry Tests', () {
    test('fromJson sets precomputed lowercase search keys and lazy model', () {
      final json = {
        'family': 'Roboto Flex',
        'category': 'sans-serif',
        'variants': ['regular', '700'],
        'files': {'regular': 'https://example.com/roboto-flex.ttf'},
      };

      final entry = CatalogueEntry.fromJson(json);

      expect(entry.name, 'Roboto Flex');
      expect(entry.category, 'Sans Serif');
      expect(entry.searchName, 'roboto flex');
      expect(entry.searchCategory, 'sans serif');
      expect(entry.hasFileUrl, isTrue);

      // Verify lazy construction of model
      final model = entry.model;
      expect(model.name, 'Roboto Flex');
      expect(model.category, 'Sans Serif');
      expect(model.weights, contains(FontWeight.w700));
      expect(identical(entry.model, model), isTrue);
    });

    test('fromModel preserves model and precomputes search keys', () {
      const model = FontModel(
        name: 'Playfair Display',
        category: 'Serif',
        description: 'Editorial serif',
        weights: [FontWeight.w400, FontWeight.w700],
        files: {'regular': 'https://example.com/playfair.ttf'},
      );

      final entry = CatalogueEntry.fromModel(model);

      expect(entry.name, 'Playfair Display');
      expect(entry.category, 'Serif');
      expect(entry.searchName, 'playfair display');
      expect(entry.searchCategory, 'serif');
      expect(entry.hasFileUrl, isTrue);
      expect(identical(entry.model, model), isTrue);
    });

    test('FontCatalogue holds entries, rawBody, and isFromCache flag', () {
      final catalogue = FontCatalogue(
        entries: [
          CatalogueEntry.fromJson({
            'family': 'Oswald',
            'category': 'sans-serif',
          }),
        ],
        rawBody: '{"items":[]}',
        isFromCache: true,
      );

      expect(catalogue.entries.length, 1);
      expect(catalogue.entries.first.name, 'Oswald');
      expect(catalogue.rawBody, '{"items":[]}');
      expect(catalogue.isFromCache, isTrue);
    });
  });
}
