import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mobile/features/heroes/hero_item.dart';

class HeroRepository {
  HeroRepository({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  Stream<List<HeroItem>> watchActiveHeroes() {
    if (Firebase.apps.isEmpty && _firestore == null) {
      return Stream<List<HeroItem>>.error(
        StateError('Firebase is not initialized.'),
      );
    }

    return (_firestore ?? FirebaseFirestore.instance)
        .collection('heroes')
        .where('active', isEqualTo: true)
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(HeroItem.fromFirestore).toList(growable: false),
        );
  }
}

final heroRepository = HeroRepository();
