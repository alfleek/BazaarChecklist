import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mobile/features/catalog/catalog_item.dart';

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
}

final catalogRepository = CatalogRepository();
