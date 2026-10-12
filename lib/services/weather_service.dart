import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum WeatherCondition { rain, snow, other }

/// Open-Meteo(무료, API 키 불필요)로 현재 날씨를 확인합니다. 날씨 뱃지에 사용합니다.
class WeatherService {
  final http.Client? _client;

  WeatherService({http.Client? client}) : _client = client;

  /// 현재 날씨 코드(WMO)를 가져옵니다. 네트워크 오류 등으로 실패하면 null.
  Future<int?> currentWeatherCode(double lat, double lng) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lng.toStringAsFixed(4),
      'current': 'weather_code',
    });
    try {
      final response = await (_client?.get(uri) ?? http.get(uri))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      return parseWeatherCode(utf8.decode(response.bodyBytes));
    } catch (e) {
      debugPrint('날씨 정보를 가져오지 못했습니다: $e');
      return null;
    }
  }

  static int? parseWeatherCode(String body) {
    final data = jsonDecode(body);
    final current = data is Map ? data['current'] : null;
    final code = current is Map ? current['weather_code'] : null;
    return code is num ? code.toInt() : null;
  }

  /// WMO 날씨 코드를 비/눈/기타로 나눕니다.
  /// 51~67 이슬비·비, 80~82 소나기, 95~99 뇌우 → 비 / 71~77, 85~86 → 눈
  static WeatherCondition conditionFromCode(int? code) {
    if (code == null) return WeatherCondition.other;
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95) {
      return WeatherCondition.rain;
    }
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return WeatherCondition.snow;
    }
    return WeatherCondition.other;
  }
}
