import 'package:flogging_app/services/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Open-Meteo 응답에서 현재 날씨 코드를 읽는다', () {
    const body = '{"latitude":-37.78,"longitude":144.93,'
        '"current_units":{"time":"iso8601","interval":"seconds","weather_code":"wmo code"},'
        '"current":{"time":"2026-10-01T06:15","interval":900,"weather_code":81}}';
    expect(WeatherService.parseWeatherCode(body), 81);
    expect(WeatherService.parseWeatherCode('{"error":true}'), isNull);
  });

  test('WMO 날씨 코드를 비/눈/기타로 나눈다', () {
    for (final code in [51, 61, 65, 80, 82, 95, 99]) {
      expect(WeatherService.conditionFromCode(code), WeatherCondition.rain, reason: '$code');
    }
    for (final code in [71, 75, 77, 85, 86]) {
      expect(WeatherService.conditionFromCode(code), WeatherCondition.snow, reason: '$code');
    }
    for (final code in [0, 1, 3, 45, 48]) {
      expect(WeatherService.conditionFromCode(code), WeatherCondition.other, reason: '$code');
    }
    expect(WeatherService.conditionFromCode(null), WeatherCondition.other);
  });
}
