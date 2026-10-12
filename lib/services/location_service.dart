import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LocationService {
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('위치 서비스가 비활성화되어 있습니다.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('위치 권한이 거부되었습니다.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 영구적으로 거부되었습니다.');
    }
    return await Geolocator.getCurrentPosition();
  }

  // 위도, 경도로 주소 정보 가져오기
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      // 실제 구현시에는 Google Maps API 키가 필요합니다
      // 현재는 간단한 좌표 정보를 반환합니다
      return '위도: ${latitude.toStringAsFixed(6)}, 경도: ${longitude.toStringAsFixed(6)}';
    } catch (e) {
      return '위치 정보를 가져올 수 없습니다.';
    }
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