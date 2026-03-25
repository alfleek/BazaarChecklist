import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mobile/features/runs/run_record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Persists runs for the current user (guest: local; signed-in: Firestore).
abstract class RunsRepository {
  Stream<List<RunRecord>> watchRuns();
  Future<void> addRun(RunRecord run);
  Future<void> updateRun(RunRecord run);
  Future<void> deleteRun(String id);
}

const _uuid = Uuid();

GuestRunsRepository? _guestRunsSingleton;

/// Clears guest singleton (for tests).
@visibleForTesting
void resetGuestRunsRepositoryForTest() {
  _guestRunsSingleton?.dispose();
  _guestRunsSingleton = null;
}

/// Creates the appropriate repository for guest vs signed-in flows.
/// Guest mode uses a singleton so list and add-run share the same stream updates.
RunsRepository createRunsRepository({
  required bool isGuest,
  String? userId,
  FirebaseFirestore? firestore,
}) {
  if (isGuest || userId == null || userId.isEmpty) {
    _guestRunsSingleton ??= GuestRunsRepository();
    return _guestRunsSingleton!;
  }
  return FirestoreRunsRepository(userId: userId, firestore: firestore);
}

class FirestoreRunsRepository implements RunsRepository {
  FirestoreRunsRepository({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore;

  final String userId;
  final FirebaseFirestore? _firestore;

  CollectionReference<Map<String, dynamic>> get _runs {
    if (Firebase.apps.isEmpty && _firestore == null) {
      throw StateError('Firebase is not initialized.');
    }
    return (_firestore ?? FirebaseFirestore.instance)
        .collection('users')
        .doc(userId)
        .collection('runs');
  }

  @override
  Stream<List<RunRecord>> watchRuns() {
    return _runs
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(RunRecord.fromFirestore)
              .toList(growable: false),
        );
  }

  @override
  Future<void> addRun(RunRecord run) async {
    await _runs.doc(run.id).set(run.toFirestore());
  }

  @override
  Future<void> updateRun(RunRecord run) async {
    await _runs.doc(run.id).set(run.toFirestore());
  }

  @override
  Future<void> deleteRun(String id) async {
    await _runs.doc(id).delete();
  }
}

const _guestRunsKey = 'guest_runs_v1';

class GuestRunsRepository implements RunsRepository {
  GuestRunsRepository({SharedPreferences? prefs}) : _prefsOverride = prefs;

  SharedPreferences? _prefsOverride;
  final _changed = StreamController<void>.broadcast();

  Future<SharedPreferences> _prefs() async {
    return _prefsOverride ??= await SharedPreferences.getInstance();
  }

  List<RunRecord> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(RunRecord.fromJson)
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  Future<List<RunRecord>> _loadSorted() async {
    final p = await _prefs();
    final runs = _decode(p.getString(_guestRunsKey));
    runs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return runs;
  }

  @override
  Stream<List<RunRecord>> watchRuns() async* {
    yield await _loadSorted();
    await for (final _ in _changed.stream) {
      yield await _loadSorted();
    }
  }

  @override
  Future<void> addRun(RunRecord run) async {
    final p = await _prefs();
    final runs = List<RunRecord>.from(_decode(p.getString(_guestRunsKey)));
    runs.add(run);
    runs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await p.setString(
      _guestRunsKey,
      jsonEncode(runs.map((r) => r.toJson()).toList()),
    );
    if (!_changed.isClosed) {
      _changed.add(null);
    }
  }

  @override
  Future<void> updateRun(RunRecord run) async {
    final p = await _prefs();
    final runs = List<RunRecord>.from(_decode(p.getString(_guestRunsKey)));
    final idx = runs.indexWhere((r) => r.id == run.id);
    if (idx < 0) {
      throw StateError('Run not found: ${run.id}');
    }
    runs[idx] = run;
    runs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await p.setString(
      _guestRunsKey,
      jsonEncode(runs.map((r) => r.toJson()).toList()),
    );
    if (!_changed.isClosed) {
      _changed.add(null);
    }
  }

  @override
  Future<void> deleteRun(String id) async {
    final p = await _prefs();
    final runs = _decode(p.getString(_guestRunsKey))
        .where((r) => r.id != id)
        .toList();
    await p.setString(
      _guestRunsKey,
      jsonEncode(runs.map((r) => r.toJson()).toList()),
    );
    if (!_changed.isClosed) {
      _changed.add(null);
    }
  }

  void dispose() {
    _changed.close();
  }
}

/// Generates a unique id for new runs (guest or Firestore doc id).
String newRunId() => _uuid.v4();
