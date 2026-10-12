import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// 위치 서비스와 권한을 확인하고 필요하면 권한을 요청합니다.
  /// 사용할 수 없으면 사용자에게 보여줄 수 있는 메시지로 예외를 던집니다.
  Future<void> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('위치 서비스가 비활성화되어 있습니다.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('위치 권한이 거부되었습니다.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.');
    }
  }

  Future<Position> getCurrentPosition() async {
    await ensurePermission();
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } on TimeoutException {
      // 실내 등에서 GPS를 못 잡으면 마지막으로 알려진 위치를 씁니다.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      rethrow;
    }
  }

  // 위도, 경도로 주소 정보 가져오기
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    // 주소 변환(역지오코딩)에는 별도 API 키가 필요해서 지금은 좌표를 그대로 보여줍니다.
    return '위도: ${latitude.toStringAsFixed(6)}, 경도: ${longitude.toStringAsFixed(6)}';
  }

  // 현재 위치의 주소 정보 가져오기
  Future<Map<String, dynamic>> getCurrentLocationInfo() async {
    try {
      final position = await getCurrentPosition();
      final address = await getAddressFromCoordinates(position.latitude, position.longitude);

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address,
        'timestamp': DateTime.now(),
      };
    } catch (e) {
      throw Exception('위치 정보를 가져올 수 없습니다: $e');
    }
  }
}
