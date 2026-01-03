import 'package:cloud_firestore/cloud_firestore.dart';

class AIParsed {
  final String? level;
  final String? gate;
  final String? slot;
  final String? zone;
  final String? landmark;

  AIParsed({
    this.level,
    this.gate,
    this.slot,
    this.zone,
    this.landmark,
  });

  factory AIParsed.fromJson(Map<String, dynamic> json) {
    return AIParsed(
      level: json['level'] as String?,
      gate: json['gate'] as String?,
      slot: json['slot'] as String?,
      zone: json['zone'] as String?,
      landmark: json['landmark'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'gate': gate,
      'slot': slot,
      'zone': zone,
      'landmark': landmark,
    };
  }
}

class AIConfidence {
  final int score; // 1-5
  final String reason;

  AIConfidence({
    required this.score,
    required this.reason,
  });

  factory AIConfidence.fromJson(Map<String, dynamic> json) {
    return AIConfidence(
      score: json['score'] as int,
      reason: json['reason'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'reason': reason,
    };
  }
}

class Place {
  final String? label;
  final String? address;

  Place({
    this.label,
    this.address,
  });

  factory Place.fromJson(Map<String, dynamic>? json) {
    if (json == null) return Place();
    return Place(
      label: json['label'] as String?,
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'address': address,
    };
  }
}

class ParkingSession {
  final String? id;
  final double lat;
  final double lng;
  final double accuracy; // meters
  final double? altitude;
  final DateTime savedAt;
  final bool active;

  final double geofenceRadiusM;
  final String source; // 'manual' or 'autosense'

  final String? photoUrl;
  final String? rawNote;

  // AI-enriched fields
  final AIParsed? aiParsed;
  final AIConfidence? aiConfidence;

  final Place? place;

  ParkingSession({
    this.id,
    required this.lat,
    required this.lng,
    required this.accuracy,
    this.altitude,
    required this.savedAt,
    this.active = true,
    this.geofenceRadiusM = 30.0,
    this.source = 'manual',
    this.photoUrl,
    this.rawNote,
    this.aiParsed,
    this.aiConfidence,
    this.place,
  });

  factory ParkingSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ParkingSession(
      id: doc.id,
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      accuracy: (data['accuracy'] as num).toDouble(),
      altitude: data['altitude'] != null ? (data['altitude'] as num).toDouble() : null,
      savedAt: (data['savedAt'] as Timestamp).toDate(),
      active: data['active'] ?? true,
      geofenceRadiusM: (data['geofenceRadiusM'] as num?)?.toDouble() ?? 30.0,
      source: data['source'] ?? 'manual',
      photoUrl: data['photoUrl'] as String?,
      rawNote: data['rawNote'] as String?,
      aiParsed: data['aiParsed'] != null
          ? AIParsed.fromJson(data['aiParsed'] as Map<String, dynamic>)
          : null,
      aiConfidence: data['aiConfidence'] != null
          ? AIConfidence.fromJson(data['aiConfidence'] as Map<String, dynamic>)
          : null,
      place: Place.fromJson(data['place'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'altitude': altitude,
      'savedAt': Timestamp.fromDate(savedAt),
      'active': active,
      'geofenceRadiusM': geofenceRadiusM,
      'source': source,
      'photoUrl': photoUrl,
      'rawNote': rawNote,
      'aiParsed': aiParsed?.toJson(),
      'aiConfidence': aiConfidence?.toJson(),
      'place': place?.toJson(),
    };
  }

  ParkingSession copyWith({
    String? id,
    double? lat,
    double? lng,
    double? accuracy,
    double? altitude,
    DateTime? savedAt,
    bool? active,
    double? geofenceRadiusM,
    String? source,
    String? photoUrl,
    String? rawNote,
    AIParsed? aiParsed,
    AIConfidence? aiConfidence,
    Place? place,
  }) {
    return ParkingSession(
      id: id ?? this.id,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      savedAt: savedAt ?? this.savedAt,
      active: active ?? this.active,
      geofenceRadiusM: geofenceRadiusM ?? this.geofenceRadiusM,
      source: source ?? this.source,
      photoUrl: photoUrl ?? this.photoUrl,
      rawNote: rawNote ?? this.rawNote,
      aiParsed: aiParsed ?? this.aiParsed,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      place: place ?? this.place,
    );
  }
}

