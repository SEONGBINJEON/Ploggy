import 'package:hive/hive.dart';
import '../utils/route_share.dart';

part 'jog_record.g.dart';

@HiveType(typeId: 0)
class JogRecord extends HiveObject {
  @HiveField(0)
  final DateTime date;

  @HiveField(1)
  final double distanceKm;

  @HiveField(2)
  final int durationSeconds;

  @HiveField(3)
  final double speedKmph;

  /// 조깅 경로를 [위도, 경도, 위도, 경도, ...] 순서로 펼쳐서 저장합니다.
  /// 경로 저장 기능 이전에 만든 기록은 빈 리스트로 읽힙니다.
  @HiveField(4, defaultValue: <double>[])
  final List<double> routeLatLng;

  JogRecord({
    required this.date,
    required this.distanceKm,
    required this.durationSeconds,
    required this.speedKmph,
    this.routeLatLng = const [],
  });

  Duration get duration => Duration(seconds: durationSeconds);

  List<RoutePoint> get routePoints => routePointsFromFlat(routeLatLng);
}

extension JogRecordShare on JogRecord {
  String toShareText() {
    final routeUrl = buildGoogleMapsRouteUrl(routePoints);
    final routeLine = routeUrl == null ? '' : '🗺 경로 보기: $routeUrl\n';
    return '''
📊 내가 달린 조깅 기록!

📅 날짜: ${date.toLocal().toString().split('.')[0]}
⏱ 시간: ${durationSeconds ~/ 60}분 ${durationSeconds % 60}초
📏 거리: ${distanceKm.toStringAsFixed(2)} km
🚀 평균 속도: ${speedKmph.toStringAsFixed(2)} km/h
$routeLine
#플로깅 #조깅 #운동기록 #건강한습관
''';
  }
}
