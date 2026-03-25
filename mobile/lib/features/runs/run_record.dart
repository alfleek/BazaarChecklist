import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile/features/runs/run_result_tier.dart';

class RunRecord {
  const RunRecord({
    required this.id,
    required this.itemIds,
    required this.createdAt,
    required this.mode,
    required this.heroId,
    required this.wins,
    required this.perfect,
    required this.resultTier,
    this.notes = '',
    this.screenshotPath = '',
    this.screenshotUrl = '',
  });

  final String id;
  final List<String> itemIds;
  final DateTime createdAt;
  final String mode;
  final String heroId;
  final int wins;
  final bool perfect;
  final RunResultTier resultTier;
  final String notes;
  final String screenshotPath;
  final String screenshotUrl;

  factory RunRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return RunRecord(
      id: doc.id,
      itemIds: _asStringList(data['itemIds']),
      createdAt: _asDateTime(data['createdAt']) ?? DateTime.now(),
      mode: _asString(data['mode']),
      heroId: _asString(data['heroId']),
      wins: _asInt(data['wins'], fallback: 0).clamp(0, 10),
      perfect: data['perfect'] == true,
      resultTier: runResultTierFromFirestore(_asString(data['resultTier'])),
      notes: _asString(data['notes']),
      screenshotPath: _asString(data['screenshotPath']),
      screenshotUrl: _asString(data['screenshotUrl']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'itemIds': itemIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'mode': mode,
      'heroId': heroId,
      'wins': wins,
      'perfect': perfect,
      'resultTier': runResultTierToFirestore(resultTier),
      'notes': notes,
      'screenshotPath': screenshotPath,
      'screenshotUrl': screenshotUrl,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemIds': itemIds,
      'createdAt': createdAt.toIso8601String(),
      'mode': mode,
      'heroId': heroId,
      'wins': wins,
      'perfect': perfect,
      'resultTier': runResultTierToFirestore(resultTier),
      'notes': notes,
      'screenshotPath': screenshotPath,
      'screenshotUrl': screenshotUrl,
    };
  }

  factory RunRecord.fromJson(Map<String, dynamic> json) {
    return RunRecord(
      id: _asString(json['id']),
      itemIds: _asStringList(json['itemIds']),
      createdAt: DateTime.tryParse(_asString(json['createdAt'])) ?? DateTime.now(),
      mode: _asString(json['mode']),
      heroId: _asString(json['heroId']),
      wins: _asInt(json['wins'], fallback: 0).clamp(0, 10),
      perfect: json['perfect'] == true,
      resultTier: runResultTierFromFirestore(_asString(json['resultTier'])),
      notes: _asString(json['notes']),
      screenshotPath: _asString(json['screenshotPath']),
      screenshotUrl: _asString(json['screenshotUrl']),
    );
  }

  static String _asString(Object? value) {
    if (value is String) return value.trim();
    return '';
  }

  static List<String> _asStringList(Object? value) {
    if (value is Iterable) {
      return value
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  static int _asInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  static DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
