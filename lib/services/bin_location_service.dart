import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../models/bin_location.dart';

/// OpenStreetMap(Overpass API)에서 현재 위치 주변의 쓰레기통·재활용 수거함을 가져옵니다.
///
/// 데이터 © OpenStreetMap contributors (ODbL) — 지도 화면에 출처를 표시합니다.
class BinLocationService {
  static const List<String> _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  final http.Client? _client;

  BinLocationService({http.Client? client}) : _client = client;

  static String buildQuery(double lat, double lng, {int radiusMeters = 1000}) {
    final around = 'around:$radiusMeters,$lat,$lng';
    return '[out:json][timeout:20];('
        'node["amenity"="waste_basket"]($around);'
        'node["amenity"="recycling"]($around);'
        ');out body 300;';
  }

  static List<BinLocation> parseResponse(String body) {
    final data = jsonDecode(body);
    final elements = data is Map ? data['elements'] : null;
    if (elements is! List) return const [];
    return elements
        .whereType<Map>()
        .map((e) => BinLocation.fromOverpassElement(e.cast<String, dynamic>()))
        .whereType<BinLocation>()
        .toList();
  }

  Future<List<BinLocation>> fetchNearby(double lat, double lng, {int radiusMeters = 1000}) async {
    final query = buildQuery(lat, lng, radiusMeters: radiusMeters);
    // 브라우저는 User-Agent 헤더를 직접 바꿀 수 없어서 모바일에서만 지정합니다.
    final headers = kIsWeb ? null : {'User-Agent': 'Ploggy/1.0 (student capstone project)'};

    Object? lastError;
    for (final endpoint in _endpoints) {
      try {
        final uri = Uri.parse(endpoint);
        final body = {'data': query};
        final response = await (_client?.post(uri, headers: headers, body: body) ??
                http.post(uri, headers: headers, body: body))
            .timeout(const Duration(seconds: 25));
        if (response.statusCode == 200) {
          return parseResponse(utf8.decode(response.bodyBytes));
        }
        lastError = 'HTTP ${response.statusCode}';
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('쓰레기통 위치를 불러오지 못했습니다: $lastError');
  }
}
