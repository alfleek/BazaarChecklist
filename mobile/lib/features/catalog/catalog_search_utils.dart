import 'package:mobile/features/catalog/catalog_item.dart';

/// Shared utilities for searching the catalog by free-text query.
///
/// Matching is token-based and forgiving against:
/// - item name
/// - hero tag
/// - any type tag
///
/// Normalization is performed to make search feel "premium":
/// - case-insensitive
/// - trims extra whitespace
/// - diacritic-insensitive for common Latin characters (e.g. José == jose)
/// - punctuation-insensitive (treats punctuation as word separators)

String normalizeCatalogSearchQuery(String query) {
  return _normalizeForSearch(query);
}

class CatalogItemSearchFields {
  CatalogItemSearchFields({
    required this.nameNorm,
    required this.heroTagNorm,
    required this.typeTagsNorm,
    required this.nameOriginal,
  });

  /// Normalized values used for matching and relevance.
  final String nameNorm;
  final String heroTagNorm;
  final List<String> typeTagsNorm;

  /// Original display name used for highlighting.
  final String nameOriginal;

  bool matchesLower(String qLower) {
    final qNorm = _normalizeForSearch(qLower);
    if (qNorm.isEmpty) return true;
    return computeCatalogItemRelevanceScore(fields: this, queryLower: qNorm) > 0;
  }
}

/// Computes a relevance score for the current query.
///
/// Higher score means more relevant.
/// This is intentionally lightweight (no backend), but supports a small amount of
/// fuzziness so partial/typo-ish queries still feel helpful.
int computeCatalogItemRelevanceScore({
  required CatalogItemSearchFields fields,
  required String queryLower,
}) {
  final qNorm = _normalizeForSearch(queryLower);
  if (qNorm.isEmpty) return 0;

  // Phrase match: if the full query matches the full name/hero/type tag exactly,
  // it should rank above token-based partial matches.
  if (fields.nameNorm == qNorm) return 400;
  if (fields.heroTagNorm == qNorm) return 320;
  for (final typeTag in fields.typeTagsNorm) {
    if (typeTag == qNorm) return 280;
  }

  final tokens = _tokenizeNormalized(qNorm);
  if (tokens.isEmpty) return 0;

  int total = 0;
  for (final token in tokens) {
    total += _bestTokenScore(fields: fields, token: token);
  }

  return total;
}

CatalogItemSearchFields buildCatalogItemSearchFields(CatalogItem item) {
  final name = item.name.isEmpty ? item.id : item.name;
  final hero = item.heroTag;
  return CatalogItemSearchFields(
    nameNorm: _normalizeForSearch(name),
    heroTagNorm: _normalizeForSearch(hero),
    typeTagsNorm: item.typeTags
        .map(_normalizeForSearch)
        .where((t) => t.isNotEmpty)
        .toList(growable: false),
    nameOriginal: name,
  );
}

/// Best-effort highlight range for the display name, based on the current query.
///
/// Returns a `(start, end)` range (exclusive end) into the original string.
/// If no sensible range can be found, returns `null`.
({int start, int end})? bestNameHighlightRange({
  required CatalogItemSearchFields fields,
  required String query,
}) {
  final qNorm = _normalizeForSearch(query);
  if (qNorm.isEmpty) return null;

  // Highlight using a simple case-insensitive substring on the original name.
  // This won't perfectly align for diacritic-folded matches, but it's fast and
  // gives users a strong visual hint for the common case.
  final origLower = fields.nameOriginal.toLowerCase();
  final needleLower = query.trim().toLowerCase();
  if (needleLower.isEmpty) return null;
  final idx = origLower.indexOf(needleLower);
  if (idx < 0) return null;
  return (start: idx, end: idx + needleLower.length);
}

// --- normalization + scoring internals ---

String _normalizeForSearch(String input) {
  var s = input.trim().toLowerCase();
  if (s.isEmpty) return '';

  // Replace punctuation with spaces so tokens behave like word separators.
  s = s.replaceAll(RegExp(r"[^a-z0-9\u00C0-\u024F]+"), ' ');

  // Fold common Latin diacritics to ASCII equivalents.
  s = _foldLatinDiacritics(s);

  // Collapse whitespace.
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

List<String> _tokenizeNormalized(String normalized) {
  return normalized
      .split(' ')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList(growable: false);
}

int _bestTokenScore({
  required CatalogItemSearchFields fields,
  required String token,
}) {
  if (token.isEmpty) return 0;

  // Ranking buckets (relevance dominates; higher is better):
  // - exact/prefix matches on name
  // - word-start matches on name
  // - substring matches on name
  // - hero/tag matches
  // - tiny fuzzy fallback

  int best = 0;
  best = _max(best, _scoreInText(fields.nameNorm, token, _FieldKind.name));
  best = _max(best, _scoreInText(fields.heroTagNorm, token, _FieldKind.hero));
  for (final tag in fields.typeTagsNorm) {
    best = _max(best, _scoreInText(tag, token, _FieldKind.tag));
  }

  // Fuzzy fallback: if no direct match, allow edit distance 1 for short tokens.
  if (best == 0 && token.length >= 3 && token.length <= 7) {
    final fuzz = _fuzzyScoreIfClose(fields.nameNorm, token);
    best = _max(best, fuzz);
  }

  return best;
}

enum _FieldKind { name, hero, tag }

int _scoreInText(String haystackNorm, String tokenNorm, _FieldKind kind) {
  if (haystackNorm.isEmpty || tokenNorm.isEmpty) return 0;

  final exact = switch (kind) {
    _FieldKind.name => 220,
    _FieldKind.hero => 170,
    _FieldKind.tag => 150,
  };
  final prefix = switch (kind) {
    _FieldKind.name => 180,
    _FieldKind.hero => 140,
    _FieldKind.tag => 120,
  };
  final wordStart = switch (kind) {
    _FieldKind.name => 150,
    _FieldKind.hero => 120,
    _FieldKind.tag => 100,
  };
  final contains = switch (kind) {
    _FieldKind.name => 110,
    _FieldKind.hero => 90,
    _FieldKind.tag => 70,
  };

  if (haystackNorm == tokenNorm) return exact;

  if (haystackNorm.startsWith(tokenNorm)) return prefix;

  // Word-start: token occurs after a space.
  final wordIdx = haystackNorm.indexOf(' $tokenNorm');
  if (wordIdx >= 0) return wordStart;

  // Substring.
  if (haystackNorm.contains(tokenNorm)) return contains;

  return 0;
}

int _fuzzyScoreIfClose(String nameNorm, String tokenNorm) {
  // Use the best (minimum) edit distance vs any word in the name.
  final words = _tokenizeNormalized(nameNorm);
  var bestDist = 99;
  var transpositionHit = false;
  for (final w in words) {
    if (_isAdjacentTransposition(w, tokenNorm)) {
      transpositionHit = true;
      bestDist = 1;
      break;
    }
    final d = _editDistanceLeq2(w, tokenNorm);
    if (d < bestDist) bestDist = d;
    if (bestDist == 0) break;
  }
  if (bestDist == 1) return transpositionHit ? 65 : 60;
  return 0;
}

bool _isAdjacentTransposition(String a, String b) {
  if (a.length != b.length) return false;
  if (a.length < 3) return false;
  var first = -1;
  var second = -1;
  for (var i = 0; i < a.length; i += 1) {
    if (a.codeUnitAt(i) == b.codeUnitAt(i)) continue;
    if (first < 0) {
      first = i;
    } else if (second < 0) {
      second = i;
    } else {
      return false;
    }
  }
  if (first < 0 || second < 0) return false;
  if (second != first + 1) return false;
  return a.codeUnitAt(first) == b.codeUnitAt(second) &&
      a.codeUnitAt(second) == b.codeUnitAt(first);
}

int _editDistanceLeq2(String a, String b) {
  // Small, allocation-light edit distance with early exit for >2.
  final la = a.length;
  final lb = b.length;
  final lenDiff = (la - lb).abs();
  if (lenDiff > 2) return 99;

  // Classic DP for small strings, but with pruning.
  final prev = List<int>.generate(lb + 1, (i) => i, growable: false);
  final curr = List<int>.filled(lb + 1, 0, growable: false);

  for (var i = 1; i <= la; i += 1) {
    curr[0] = i;
    var rowBest = curr[0];
    final ca = a.codeUnitAt(i - 1);
    for (var j = 1; j <= lb; j += 1) {
      final cb = b.codeUnitAt(j - 1);
      final cost = ca == cb ? 0 : 1;
      final del = prev[j] + 1;
      final ins = curr[j - 1] + 1;
      final sub = prev[j - 1] + cost;
      final v = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
      curr[j] = v;
      if (v < rowBest) rowBest = v;
    }
    if (rowBest > 2) return 99;
    for (var j = 0; j <= lb; j += 1) {
      // copy curr -> prev
      // ignore: avoid_setters_without_getters
      prev[j] = curr[j];
    }
  }
  return prev[lb];
}

int _max(int a, int b) => a > b ? a : b;

String _foldLatinDiacritics(String s) {
  // Covers common Latin-1 + Latin Extended-A/B letters. Not exhaustive, but
  // good enough for typical catalog item names and tags.
  const map = <String, String>{
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
    'ç': 'c', 'ć': 'c', 'ĉ': 'c', 'ċ': 'c', 'č': 'c',
    'ď': 'd', 'đ': 'd',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e',
    'ƒ': 'f',
    'ĝ': 'g', 'ğ': 'g', 'ġ': 'g', 'ģ': 'g',
    'ĥ': 'h', 'ħ': 'h',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ĩ': 'i', 'ī': 'i', 'ĭ': 'i', 'į': 'i', 'ı': 'i',
    'ĵ': 'j',
    'ķ': 'k',
    'ĺ': 'l', 'ļ': 'l', 'ľ': 'l', 'ł': 'l',
    'ñ': 'n', 'ń': 'n', 'ņ': 'n', 'ň': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ŏ': 'o', 'ő': 'o',
    'œ': 'oe',
    'ŕ': 'r', 'ŗ': 'r', 'ř': 'r',
    'ś': 's', 'ŝ': 's', 'ş': 's', 'š': 's', 'ß': 'ss',
    'ţ': 't', 'ť': 't', 'ŧ': 't',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ũ': 'u', 'ū': 'u', 'ŭ': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u',
    'ŵ': 'w',
    'ý': 'y', 'ÿ': 'y', 'ŷ': 'y',
    'ź': 'z', 'ż': 'z', 'ž': 'z',
    'æ': 'ae',
  };

  final b = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    final repl = map[ch];
    if (repl != null) {
      b.write(repl);
    } else {
      b.write(ch);
    }
  }
  return b.toString();
}
