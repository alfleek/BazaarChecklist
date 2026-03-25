import 'package:cloud_firestore/cloud_firestore.dart';

class HeroItem {
  const HeroItem({
    required this.id,
    required this.name,
    required this.active,
    this.updatedAt,
  });

  final String id;
  final String name;
  final bool active;
  final DateTime? updatedAt;

  factory HeroItem.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return HeroItem(
      id: doc.id,
      name: _asString(data['name']),
      active: data['active'] != false,
      updatedAt: _asDateTime(data['updatedAt']),
    );
  }

  static String _asString(Object? value) {
    if (value is String) return value.trim();
    return '';
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
