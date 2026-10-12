import 'package:flogging_app/models/bin_location.dart';
import 'package:flogging_app/services/bin_location_service.dart';
import 'package:flutter_test/flutter_test.dart';

// 실제 Overpass API(멜버른 Flinders St 주변) 응답 형식을 줄인 예시
const _sampleResponse = '''
{
  "version": 0.6,
  "elements": [
    {"type": "node", "id": 11, "lat": -37.81831, "lon": 144.966023,
     "tags": {"amenity": "waste_basket", "check_date": "2026-05-21"}},
    {"type": "node", "id": 12, "lat": -37.8179, "lon": 144.9682,
     "tags": {"amenity": "recycling", "recycling_type": "container",
              "recycling:cans": "yes", "recycling:glass_bottles": "yes",
              "recycling:plastic": "no", "recycling:plastic_bottles": "yes"}},
    {"type": "node", "id": 13, "lat": -37.8190, "lon": 144.9690,
     "tags": {"amenity": "recycling", "recycling_type": "centre"}},
    {"type": "node", "id": 14, "tags": {"amenity": "waste_basket"}}
  ]
}
''';

void main() {
  test('Overpass 응답에서 쓰레기통과 재활용 수거함을 구분해 읽는다', () {
    final bins = BinLocationService.parseResponse(_sampleResponse);

    // 좌표가 없는 node는 건너뛴다
    expect(bins, hasLength(3));

    expect(bins[0].type, BinType.wasteBasket);
    expect(bins[0].latitude, -37.81831);
    expect(bins[0].description, '일반 쓰레기통');

    expect(bins[1].type, BinType.recycling);
    expect(bins[1].description, '재활용 수거함: 캔, 유리병, 페트병');

    expect(bins[2].description, '재활용 센터');
  });

  test('형식이 다른 응답은 빈 목록으로 처리한다', () {
    expect(BinLocationService.parseResponse('{"results": []}'), isEmpty);
    expect(BinLocationService.parseResponse('[]'), isEmpty);
  });

  test('반경 안의 쓰레기통·재활용 수거함을 찾는 쿼리를 만든다', () {
    final query = BinLocationService.buildQuery(-37.8183, 144.9671, radiusMeters: 800);
    expect(query, contains('[out:json]'));
    expect(query, contains('node["amenity"="waste_basket"](around:800,-37.8183,144.9671);'));
    expect(query, contains('node["amenity"="recycling"](around:800,-37.8183,144.9671);'));
  });
}
