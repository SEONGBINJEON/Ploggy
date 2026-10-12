class PloggingUser {
  final String id;
  final String name;
  final String email;
  final String profileImageUrl;
  final int totalDistance;
  final int totalTrash;
  final List<String> badges;

  PloggingUser({
    required this.id,
    required this.name,
    required this.email,
    required this.profileImageUrl,
    required this.totalDistance,
    required this.totalTrash,
    required this.badges,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'profileImageUrl': profileImageUrl,
    'totalDistance': totalDistance,
    'totalTrash': totalTrash,
    'badges': badges,
  };

  factory PloggingUser.fromMap(Map<String, dynamic> map) => PloggingUser(
    id: map['id'],
    name: map['name'],
    email: map['email'],
    profileImageUrl: map['profileImageUrl'],
    totalDistance: map['totalDistance'],
    totalTrash: map['totalTrash'],
    badges: List<String>.from(map['badges']),
  );
} 