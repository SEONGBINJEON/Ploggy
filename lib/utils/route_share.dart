import 'dart:math' as math;

typedef RoutePoint = ({double lat, double lng});

/// [위도, 경도, 위도, 경도, ...]로 펼친 리스트를 좌표 목록으로 바꿉니다.
List<RoutePoint> routePointsFromFlat(List<double> flat) => [
      for (var i = 0; i + 1 < flat.length; i += 2) (lat: flat[i], lng: flat[i + 1]),
    ];

/// 조깅 경로를 Google 지도 길찾기 링크로 만듭니다.
///
/// Google 지도 URL은 경유지 개수가 제한되어 있어서 출발·도착 지점과
/// 경로에서 고르게 뽑은 중간 지점 최대 [maxWaypoints]개만 사용합니다.
/// 좌표가 2개 미만이면 null을 돌려줍니다.
String? buildGoogleMapsRouteUrl(List<RoutePoint> points, {int maxWaypoints = 8}) {
  if (points.length < 2) return null;

  String format(RoutePoint p) => '${p.lat.toStringAsFixed(6)},${p.lng.toStringAsFixed(6)}';

  final count = math.min(maxWaypoints, points.length - 2);
  final waypoints = <String>[];
  for (var k = 1; k <= count; k++) {
    final idx = (k * (points.length - 1) / (count + 1)).round();
    waypoints.add(format(points[idx]));
  }

  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'origin': format(points.first),
    'destination': format(points.last),
    if (waypoints.isNotEmpty) 'waypoints': waypoints.join('|'),
    'travelmode': 'walking',
  }).toString();
}
