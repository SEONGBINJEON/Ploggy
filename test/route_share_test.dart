import 'package:flogging_app/utils/route_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildGoogleMapsRouteUrl', () {
    test('좌표가 2개 미만이면 링크를 만들지 않는다', () {
      expect(buildGoogleMapsRouteUrl([]), isNull);
      expect(buildGoogleMapsRouteUrl([(lat: -37.8, lng: 144.9)]), isNull);
    });

    test('출발·도착과 걷기 모드가 들어간 Google 지도 길찾기 링크를 만든다', () {
      final url = buildGoogleMapsRouteUrl([
        (lat: -37.818300, lng: 144.967100),
        (lat: -37.820000, lng: 144.968000),
      ])!;
      final uri = Uri.parse(url);
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['origin'], '-37.818300,144.967100');
      expect(uri.queryParameters['destination'], '-37.820000,144.968000');
      expect(uri.queryParameters['travelmode'], 'walking');
      expect(uri.queryParameters.containsKey('waypoints'), isFalse);
    });

    test('경유지는 최대 개수만큼 경로에서 고르게 뽑는다', () {
      final points = [for (var i = 0; i < 100; i++) (lat: -37.8 - i * 0.0001, lng: 144.9)];
      final uri = Uri.parse(buildGoogleMapsRouteUrl(points, maxWaypoints: 8)!);
      final waypoints = uri.queryParameters['waypoints']!.split('|');
      expect(waypoints, hasLength(8));
      // 출발·도착 지점은 경유지에 다시 들어가지 않는다
      expect(waypoints, isNot(contains(uri.queryParameters['origin'])));
      expect(waypoints, isNot(contains(uri.queryParameters['destination'])));
      expect(waypoints.toSet(), hasLength(8));
    });

    test('중간 지점이 적으면 모두 경유지로 쓴다', () {
      final points = [for (var i = 0; i < 4; i++) (lat: -37.8 - i * 0.001, lng: 144.9)];
      final uri = Uri.parse(buildGoogleMapsRouteUrl(points)!);
      expect(uri.queryParameters['waypoints']!.split('|'), hasLength(2));
    });
  });

  test('routePointsFromFlat은 [위도, 경도, ...]를 좌표 목록으로 바꾼다', () {
    expect(routePointsFromFlat([1.0, 2.0, 3.0, 4.0]), [(lat: 1.0, lng: 2.0), (lat: 3.0, lng: 4.0)]);
    expect(routePointsFromFlat([1.0, 2.0, 3.0]), [(lat: 1.0, lng: 2.0)]);
  });
}
