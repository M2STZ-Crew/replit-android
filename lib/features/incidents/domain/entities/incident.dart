class Incident {
  const Incident({
    required this.id,
    required this.citizenId,
    this.photoUrl,
    required this.lat,
    required this.lng,
    required this.description,
    required this.status,
    this.responderId,
    required this.createdAt,
    this.citizenName,
    this.responderName,
  });

  final String id;
  final String citizenId;
  final String? photoUrl;
  final double lat;
  final double lng;
  final String description;
  final String status;
  final String? responderId;
  final DateTime createdAt;
  final String? citizenName;
  final String? responderName;

  bool get isPending => status == 'pending';
  bool get isDispatched => status == 'dispatched';
  bool get isOngoing => status == 'ongoing';
  bool get isResolved => status == 'resolved';

  factory Incident.fromMap(Map<String, dynamic> map) {
    return Incident(
      id: map['id'] as String,
      citizenId: map['citizen_id'] as String,
      photoUrl: map['photo_url'] as String?,
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      description: map['description'] as String,
      status: map['status'] as String,
      responderId: map['responder_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      citizenName: map['citizen_name'] as String?,
      responderName: map['responder_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'citizen_id': citizenId,
      'photo_url': photoUrl,
      'lat': lat,
      'lng': lng,
      'description': description,
      'status': status,
      'responder_id': responderId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Incident copyWith({
    String? id,
    String? citizenId,
    String? photoUrl,
    double? lat,
    double? lng,
    String? description,
    String? status,
    String? responderId,
    DateTime? createdAt,
    String? citizenName,
    String? responderName,
  }) {
    return Incident(
      id: id ?? this.id,
      citizenId: citizenId ?? this.citizenId,
      photoUrl: photoUrl ?? this.photoUrl,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      description: description ?? this.description,
      status: status ?? this.status,
      responderId: responderId ?? this.responderId,
      createdAt: createdAt ?? this.createdAt,
      citizenName: citizenName ?? this.citizenName,
      responderName: responderName ?? this.responderName,
    );
  }
}
