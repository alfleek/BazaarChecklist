import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/catalog/catalog_item.dart';
import 'package:mobile/features/catalog/catalog_search_utils.dart';

void main() {
  group('normalizeCatalogSearchQuery', () {
    test('trims and lowercases', () {
      expect(normalizeCatalogSearchQuery('  Fire  '), 'fire');
      expect(normalizeCatalogSearchQuery('VANESSA'), 'vanessa');
    });

    test('folds common Latin diacritics', () {
      expect(normalizeCatalogSearchQuery('José'), 'jose');
      expect(normalizeCatalogSearchQuery('  Crème brûlée  '), 'creme brulee');
    });

    test('treats punctuation as separators', () {
      expect(normalizeCatalogSearchQuery('Fire-Sword'), 'fire sword');
      expect(normalizeCatalogSearchQuery("  O'Brian  "), 'o brian');
    });
  });

  group('CatalogItemSearchFields.matchesLower', () {
    final item = const CatalogItem(
      id: 'i1',
      name: 'Fire Sword',
      typeTags: ['Burn', 'Melee'],
      heroTag: 'Vanessa',
      startingRarity: 'Rare',
      size: 'Large',
      active: true,
    );

    final f = buildCatalogItemSearchFields(item);

    test('matches name substring', () {
      expect(f.matchesLower('fire'), isTrue);
      expect(f.matchesLower('sword'), isTrue);
    });

    test('matches hero tag substring', () {
      expect(f.matchesLower('van'), isTrue);
      expect(f.matchesLower('ness'), isTrue);
    });

    test('matches any type tag substring', () {
      expect(f.matchesLower('burn'), isTrue);
      expect(f.matchesLower('lee'), isTrue);
    });

    test('returns false for non-matching query', () {
      expect(f.matchesLower('ice'), isFalse);
      expect(f.matchesLower(''), isTrue);
    });
  });

  group('computeCatalogItemRelevanceScore', () {
    final item = const CatalogItem(
      id: 'i1',
      name: 'Fire Sword',
      typeTags: ['Burn', 'Melee'],
      heroTag: 'Vanessa',
      startingRarity: 'Rare',
      size: 'Large',
      active: true,
    );
    final fields = buildCatalogItemSearchFields(item);

    test('exact phrase match is highest', () {
      final q = normalizeCatalogSearchQuery('fire sword');
      final s = computeCatalogItemRelevanceScore(fields: fields, queryLower: q);
      expect(s, greaterThanOrEqualTo(300));
    });

    test('name prefix beats tag contains', () {
      final s1 = computeCatalogItemRelevanceScore(
        fields: fields,
        queryLower: normalizeCatalogSearchQuery('fire'),
      );
      final s2 = computeCatalogItemRelevanceScore(
        fields: fields,
        queryLower: normalizeCatalogSearchQuery('lee'),
      );
      expect(s1, greaterThan(s2));
    });

    test('hero prefix ranks above type prefix', () {
      final sHero = computeCatalogItemRelevanceScore(
        fields: fields,
        queryLower: normalizeCatalogSearchQuery('van'),
      );
      final sType = computeCatalogItemRelevanceScore(
        fields: fields,
        queryLower: normalizeCatalogSearchQuery('bu'),
      );
      expect(sHero, greaterThan(sType));
    });

    test('multi-token sums best matches per token', () {
      final s = computeCatalogItemRelevanceScore(
        fields: fields,
        queryLower: normalizeCatalogSearchQuery('fire melee'),
      );
      // fire => name startsWith (180), melee => exact type tag (150)
      expect(s, 330);
    });

    test('no match yields 0', () {
      final s = computeCatalogItemRelevanceScore(
        fields: fields,
        queryLower: normalizeCatalogSearchQuery('ice'),
      );
      expect(s, 0);
    });

    test('fuzzy fallback helps close typos', () {
      final s = computeCatalogItemRelevanceScore(
        fields: fields,
        queryLower: normalizeCatalogSearchQuery('fier'),
      );
      expect(s, greaterThan(0));
    });
  });

  group('bestNameHighlightRange', () {
    test('returns null for empty query', () {
      final item = const CatalogItem(
        id: 'i1',
        name: 'Fire Sword',
        typeTags: ['Burn'],
        heroTag: 'Vanessa',
        startingRarity: 'Rare',
        size: 'Large',
        active: true,
      );
      final f = buildCatalogItemSearchFields(item);
      expect(bestNameHighlightRange(fields: f, query: ''), isNull);
    });

    test('highlights a simple substring match', () {
      final item = const CatalogItem(
        id: 'i1',
        name: 'Fire Sword',
        typeTags: const [],
        heroTag: '',
        startingRarity: '',
        size: '',
        active: true,
      );
      final f = buildCatalogItemSearchFields(item);
      final r = bestNameHighlightRange(fields: f, query: 'swo');
      expect(r, isNotNull);
      expect(item.name.substring(r!.start, r.end).toLowerCase(), 'swo');
    });
  });
}

