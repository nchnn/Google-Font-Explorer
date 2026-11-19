// test/font_paginator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:type_studio/models/font_model.dart';
import 'package:type_studio/services/font_paginator.dart';

FontModel _font(String name) => FontModel(
      name: name,
      category: 'Sans Serif',
      description: 'd',
      weights: const [FontWeight.w400],
    );

List<FontModel> _fonts(int count) =>
    List.generate(count, (i) => _font('Font ${i + 1}'));

void main() {
  test('first page reveals exactly 5 of 12', () {
    final p = FontPaginator<FontModel>(idOf: (f) => f.name)..reset(_fonts(12));
    expect(p.visibleCount, 5);
    expect(p.visibleItems.length, 5);
    expect(p.totalCount, 12);
    expect(p.hasMore, isTrue);
    expect(p.isEmpty, isFalse);
  });

  test('loadNextPage appends 5 and stops at the end', () async {
    final p = FontPaginator<FontModel>(idOf: (f) => f.name)..reset(_fonts(12));
    await p.loadNextPage();
    expect(p.visibleCount, 10);
    await p.loadNextPage();
    expect(p.visibleCount, 12);
    expect(p.hasMore, isFalse);
  });

  test('loadNextPage on an exhausted paginator throws and does not grow', () async {
    final p = FontPaginator<FontModel>(idOf: (f) => f.name)..reset(_fonts(5));
    expect(p.hasMore, isFalse);
    await expectLater(p.loadNextPage(), throwsStateError);
    expect(p.visibleCount, 5);
  });

  test('reset rewinds and discards the previous source', () async {
    final p = FontPaginator<FontModel>(idOf: (f) => f.name)..reset(_fonts(12));
    await p.loadNextPage();
    expect(p.visibleCount, 10);
    p.reset(_fonts(3));
    expect(p.visibleCount, 3);
    expect(p.totalCount, 3);
    expect(p.hasMore, isFalse);
  });

  test('duplicate family names are dropped, first wins', () {
    final p = FontPaginator<FontModel>(idOf: (f) => f.name)
      ..reset([_font('Roboto'), _font('Lato'), _font('Roboto')]);
    expect(p.totalCount, 2);
    expect(p.visibleItems.map((f) => f.name), ['Roboto', 'Lato']);
  });

  test('empty and short sources behave', () {
    final empty = FontPaginator<FontModel>(idOf: (f) => f.name)..reset(const []);
    expect(empty.isEmpty, isTrue);
    expect(empty.hasMore, isFalse);
    final short = FontPaginator<FontModel>(idOf: (f) => f.name)..reset(_fonts(2));
    expect(short.visibleCount, 2);
    expect(short.hasMore, isFalse);
  });

  test('custom page size is honoured', () async {
    final p = FontPaginator<FontModel>(idOf: (f) => f.name, pageSize: 3)
      ..reset(_fonts(7));
    expect(p.visibleCount, 3);
    await p.loadNextPage();
    expect(p.visibleCount, 6);
  });

  test('default page size is 5', () {
    expect(FontPaginator.defaultPageSize, 5);
  });

  test('reset during a pending batch discards the stale batch', () async {
    final p = FontPaginator<FontModel>(idOf: (f) => f.name)..reset(_fonts(20));
    final pending = p.loadNextPage(); // yields before advancing
    p.reset(_fonts(9)); // newer source wins
    final slice = await pending;
    expect(slice, isEmpty);
    expect(p.visibleCount, 5,
        reason: 'the stale batch must not advance the new cursor');
    expect(p.totalCount, 9);
  });
}
