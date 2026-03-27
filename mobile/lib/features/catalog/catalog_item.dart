import 'package:cloud_firestore/cloud_firestore.dart';

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.typeTags,
    required this.heroTag,
    required this.startingRarity,
    required this.size,
    required this.active,
    this.hiddenTags = const [],
    this.updatedAt,
    this.imageThumbUrl,
    this.imageFullUrl,
  });

  final String id;
  final String name;
  final List<String> typeTags;
  final List<String> hiddenTags;
  final String heroTag;
  final String startingRarity;
  final String size;
  final bool active;
  final DateTime? updatedAt;
  final String? imageThumbUrl;
  final String? imageFullUrl;

  /// Placeholder when a stored id is missing from the live catalog (e.g. inactive item).
  factory CatalogItem.unknown(String id) {
    return CatalogItem(
      id: id,
      name: 'Unknown item',
      typeTags: const [],
      hiddenTags: const [],
      heroTag: '',
      startingRarity: '',
      size: '',
      active: false,
    );
  }

  factory CatalogItem.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return CatalogItem(
      id: doc.id,
      name: _asString(data['name']),
      typeTags: _asStringList(data['typeTags']),
      hiddenTags: _asStringList(data['hiddenTags']),
      heroTag: _asString(data['heroTag']),
      startingRarity: _asString(data['startingRarity']),
      size: _asString(data['size']),
      active: _asBool(data['active'], fallback: true),
      updatedAt: _asDateTime(data['updatedAt']),
      imageThumbUrl: _asNullableString(data['imageThumbUrl'] ?? data['imageUrl']),
      imageFullUrl: _asNullableString(data['imageFullUrl']),
    );
  }

  factory CatalogItem.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists) return CatalogItem.unknown(doc.id);
    final data = doc.data();
    if (data == null) return CatalogItem.unknown(doc.id);
    return CatalogItem(
      id: doc.id,
      name: _asString(data['name']),
      typeTags: _asStringList(data['typeTags']),
      hiddenTags: _asStringList(data['hiddenTags']),
      heroTag: _asString(data['heroTag']),
      startingRarity: _asString(data['startingRarity']),
      size: _asString(data['size']),
      active: _asBool(data['active'], fallback: true),
      updatedAt: _asDateTime(data['updatedAt']),
      imageThumbUrl: _asNullableString(data['imageThumbUrl'] ?? data['imageUrl']),
      imageFullUrl: _asNullableString(data['imageFullUrl']),
    );
  }

  static String _asString(Object? value) {
    if (value is String) {
      return value.trim();
    }
    if (value != null) {
      return value.toString().trim();
    }
    return '';
  }

  static String? _asNullableString(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static List<String> _asStringList(Object? value) {
    if (value is Iterable) {
      return value
          .whereType<String>()
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  static bool _asBool(Object? value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    return fallback;
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}
