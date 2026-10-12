import 'dart:typed_data';

class TrashRecord {
  final String id;
  final String userId;
  final String imageUrl;
  final String trashType;
  final DateTime date;
  final String locationDesc;
  final double? latitude;
  final double? longitude;
  final Uint8List? imageBytes;

  TrashRecord({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.trashType,
    required this.date,
    required this.locationDesc,
    this.latitude,
    this.longitude,
    this.imageBytes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'imageUrl': imageUrl,
    'trashType': trashType,
    'date': date.toIso8601String(),
    'locationDesc': locationDesc,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory TrashRecord.fromMap(Map<String, dynamic> map) => TrashRecord(
    id: map['id'],
    userId: map['userId'],
    imageUrl: map['imageUrl'],
    trashType: map['trashType'],
    date: DateTime.parse(map['date']),
    locationDesc: map['locationDesc'],
    latitude: map['latitude']?.toDouble(),
    longitude: map['longitude']?.toDouble(),
  );

  // 복사본 생성 메서드
  TrashRecord copyWith({
    String? id,
    String? userId,
    String? imageUrl,
    String? trashType,
    DateTime? date,
    String? locationDesc,
    double? latitude,
    double? longitude,
    Uint8List? imageBytes,
  }) {
    return TrashRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      imageUrl: imageUrl ?? this.imageUrl,
      trashType: trashType ?? this.trashType,
      date: date ?? this.date,
      locationDesc: locationDesc ?? this.locationDesc,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageBytes: imageBytes ?? this.imageBytes,
    );
  }
} 