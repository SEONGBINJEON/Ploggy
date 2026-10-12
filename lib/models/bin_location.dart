enum BinType { wasteBasket, recycling }

class BinLocation {
  final int id;
  final double latitude;
  final double longitude;
  final BinType type;
  final String description;

  const BinLocation({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.description,
  });

  static const Map<String, String> _materialNames = {
    'cans': '캔',
    'glass_bottles': '유리병',
    'glass': '유리',
    'plastic_bottles': '페트병',
    'plastic': '플라스틱',
    'plastic_packaging': '플라스틱 포장재',
    'beverage_cartons': '음료팩',
    'paper': '종이',
    'cardboard': '박스',
    'clothes': '의류',
    'batteries': '건전지',
  };

  /// OpenStreetMap Overpass API 응답의 node 하나를 변환합니다. 좌표가 없으면 null.
  static BinLocation? fromOverpassElement(Map<String, dynamic> element) {
    final id = element['id'];
    final lat = element['lat'];
    final lon = element['lon'];
    if (id is! num || lat is! num || lon is! num) return null;

    final rawTags = element['tags'];
    final tags = rawTags is Map ? rawTags.cast<String, dynamic>() : const <String, dynamic>{};
    final isRecycling = tags['amenity'] == 'recycling';

    return BinLocation(
      id: id.toInt(),
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      type: isRecycling ? BinType.recycling : BinType.wasteBasket,
      description: isRecycling ? _recyclingDescription(tags) : '일반 쓰레기통',
    );
  }

  static String _recyclingDescription(Map<String, dynamic> tags) {
    final materials = <String>[
      for (final entry in tags.entries)
        if (entry.key.startsWith('recycling:') && entry.value == 'yes')
          _materialNames[entry.key.substring('recycling:'.length)] ??
              entry.key.substring('recycling:'.length),
    ];
    final kind = tags['recycling_type'] == 'centre' ? '재활용 센터' : '재활용 수거함';
    return materials.isEmpty ? kind : '$kind: ${materials.join(', ')}';
  }
}
