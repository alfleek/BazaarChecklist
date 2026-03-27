import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mobile/features/catalog/catalog_item.dart';

class CatalogItemsPage {
  const CatalogItemsPage({
    required this.items,
    required this.lastDoc,
    required this.hasMore,
  });

  final List<CatalogItem> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
}

class CatalogRepository {
  CatalogRepository({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  Stream<List<CatalogItem>> watchActiveCatalogItems() {
    if (Firebase.apps.isEmpty && _firestore == null) {
      return Stream<List<CatalogItem>>.error(
        StateError('Firebase is not initialized.'),
      );
    }

    return (_firestore ?? FirebaseFirestore.instance)
        .collection('catalog_items')
        .where('active', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(CatalogItem.fromFirestore).toList(growable: false),
        );
  }

  Future<CatalogItemsPage> fetchActiveCatalogItemsPage({
    required int pageSize,
    required DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    if (Firebase.apps.isEmpty && _firestore == null) {
      return Future.error(
        StateError('Firebase is not initialized.'),
      );
    }

    final db = _firestore ?? FirebaseFirestore.instance;

    Query<Map<String, dynamic>> q = db
        .collection('catalog_items')
        .where('active', isEqualTo: true)
        // Stable ordering for pagination.
        .orderBy('name')
        .orderBy(FieldPath.documentId)
        .limit(pageSize);

    if (startAfter != null) {
      q = q.startAfterDocument(startAfter);
    }

    final snap = await q.get();
    final docs = snap.docs;
    final items = docs
        .map((d) => CatalogItem.fromFirestore(d))
        .toList(growable: false);
    final lastDoc =
        docs.isNotEmpty ? docs[docs.length - 1] : null;

    return CatalogItemsPage(
      items: items,
      lastDoc: lastDoc,
      hasMore: docs.length == pageSize,
    );
  }

  Future<CatalogItem?> fetchCatalogItemById(String itemId) async {
    if (Firebase.apps.isEmpty && _firestore == null) {
      return Future.error(
        StateError('Firebase is not initialized.'),
      );
    }

    final db = _firestore ?? FirebaseFirestore.instance;
    final doc = await db.collection('catalog_items').doc(itemId).get();
    if (!doc.exists) return null;
    return CatalogItem.fromSnapshot(doc);
  }
}

final catalogRepository = CatalogRepository();
