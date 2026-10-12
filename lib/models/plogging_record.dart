class PloggingRecord {
  final String id;
  final String userId;
  final double distance; // km
  final double duration; // minutes
  final double avgSpeed; // km/h
  final DateTime date;
  final List<Map<String, double>> route; // [{lat, lng}, ...]

  PloggingRecord({
    required this.id,
    required this.userId,
    required this.distance,
    required this.duration,
    required this.avgSpeed,
    required this.date,
    required this.route,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'distance': distance,
    'duration': duration,
    'avgSpeed': avgSpeed,
    'date': date.toIso8601String(),
    'route': route,
  };

  factory PloggingRecord.fromMap(Map<String, dynamic> map) => PloggingRecord(
    id: map['id'],
    userId: map['userId'],
    distance: map['distance'],
    duration: map['duration'],
    avgSpeed: map['avgSpeed'],
    date: DateTime.parse(map['date']),
    route: List<Map<String, double>>.from(map['route'].map((e) => Map<String, double>.from(e))),
  );
} 