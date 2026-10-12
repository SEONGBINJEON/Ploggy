import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/jog_record.dart';
import 'jog_history_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/bin_location.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../services/badge_service.dart';
import '../widgets/badge_unlock_popup.dart';

class JoggingScreen extends StatefulWidget {
  const JoggingScreen({Key? key}) : super(key: key);

  @override
  State<JoggingScreen> createState() => _JoggingScreenState();
}

class _JoggingScreenState extends State<JoggingScreen> {
  Position? _lastPosition;
  Timer? _timer;
  double _totalDistance = 0.0;
  final Stopwatch _stopwatch = Stopwatch();
  late final Stream<Position> _positionStream;
  StreamSubscription<Position>? _positionSubscription;
  bool _isJogging = false;

  GoogleMapController? _mapController;
  List<LatLng> _routePoints = [];
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
    _loadBinLocations();
  }

  Future<void> _loadBinLocations() async {
    try {
      final bins = await fetchBinLocations();
      setState(() {
        for (var bin in bins) {
          _markers.add(Marker(
            markerId: MarkerId("bin_${bin.latitude}_${bin.longitude}"),
            position: LatLng(bin.latitude, bin.longitude),
            infoWindow: InfoWindow(title: "쓰레기통", snippet: bin.address),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ));
        }
      });
    } catch (e) {
      print("쓰레기통 데이터 불러오기 실패: $e");
    }
  }

  void _startJogging() async {
    // 위치 권한 확인
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('위치 권한이 필요합니다.')),
        );
        return;
      }
    }

    setState(() {
      _isJogging = true;
      _stopwatch.start();
      _routePoints.clear();
      _markers.removeWhere((marker) => 
        marker.markerId.value == "start" || marker.markerId.value == "end");
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {});
    });

    _positionSubscription = _positionStream.listen((Position pos) {
      if (_lastPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          pos.latitude,
          pos.longitude,
        );
        setState(() {
          _totalDistance += distance;
        });
      }

      setState(() {
        final currentLatLng = LatLng(pos.latitude, pos.longitude);
        _routePoints.add(currentLatLng);

        // 시작 마커
        if (_routePoints.length == 1) {
          _markers.add(Marker(
            markerId: const MarkerId("start"),
            position: currentLatLng,
            infoWindow: const InfoWindow(title: "출발 지점"),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ));
        }
      });

      _lastPosition = pos;

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(pos.latitude, pos.longitude),
        ),
      );
    });
  }

  void _stopJogging() async {
    setState(() {
      _isJogging = false;
      _stopwatch.stop();
    });
    
    _positionSubscription?.cancel();
    _timer?.cancel();
    await _saveJogRecord();

    // 종료 마커 추가
    if (_lastPosition != null) {
      final endLatLng = LatLng(_lastPosition!.latitude, _lastPosition!.longitude);
      setState(() {
        _markers.add(Marker(
          markerId: const MarkerId("end"),
          position: endLatLng,
          infoWindow: const InfoWindow(title: "도착 지점"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ));
      });
    }
  }

  void _resetJogging() {
    setState(() {
      _stopwatch.reset();
      _totalDistance = 0.0;
      _lastPosition = null;
      _routePoints.clear();
      _markers.removeWhere((marker) => 
        marker.markerId.value == "start" || marker.markerId.value == "end");
    });
  }

  Future<void> _saveJogRecord() async {
    final record = JogRecord(
      date: DateTime.now(),
      distanceKm: _totalDistance / 1000,
      durationSeconds: _stopwatch.elapsed.inSeconds,
      speedKmph: _calculateSpeed(),
    );
    await Hive.box<JogRecord>('jog_records').add(record);
    
    // 뱃지 조건 체크
    await _checkBadgeConditions();
  }

  Future<void> _checkBadgeConditions() async {
    final badgeService = context.read<BadgeService>();
    final newlyUnlocked = await badgeService.checkBadgeConditions();
    
    if (newlyUnlocked.isNotEmpty && mounted) {
      for (final badgeId in newlyUnlocked) {
        final badge = badgeService.badges.firstWhere((b) => b['id'] == badgeId);
        _showBadgeUnlockPopup(badge);
      }
    }
  }

  void _showBadgeUnlockPopup(Map<String, dynamic> badge) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BadgeUnlockPopup(
        badge: badge,
        onClose: () {
          Navigator.of(context).pop();
          context.read<BadgeService>().clearNewlyUnlockedBadge();
        },
      ),
    );
  }

  void _shareJogRecord() {
    final duration = _formatDuration(_stopwatch.elapsed);
    final speed = _calculateSpeed().toStringAsFixed(2);
    final distanceKm = (_totalDistance / 1000).toStringAsFixed(2);

    final text = '''
📊 내 조깅 기록 공유합니다!

⏱ 시간: $duration
📏 거리: $distanceKm km
🚀 평균 속도: $speed km/h

#조깅기록 #FlutterApp #건강한습관
''';

    Share.share(text);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  double _calculateSpeed() {
    if (_stopwatch.elapsed.inSeconds == 0) return 0.0;
    final seconds = _stopwatch.elapsed.inSeconds;
    final mps = _totalDistance / seconds;
    return mps * 3.6;
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _positionSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = _formatDuration(_stopwatch.elapsed);
    final speed = _calculateSpeed().toStringAsFixed(2);
    final distanceKm = (_totalDistance / 1000).toStringAsFixed(2);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Jogging Tracker', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // 🗺️ 지도 영역
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(37.5665, 126.9780), // 서울 시청
                    zoom: 16,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId("route"),
                      color: Colors.blue,
                      width: 5,
                      points: _routePoints,
                    ),
                  },
                  markers: _markers,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                ),
              ),
            ),
          ),
          // 조깅 정보 카드
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // 정보 카드들
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildInfoCard("⏱ 시간", duration, Colors.blue),
                    _buildInfoCard("📏 거리", "$distanceKm km", Colors.green),
                    _buildInfoCard("🚀 속도", "$speed km/h", Colors.orange),
                  ],
                ),
                const SizedBox(height: 24),
                // 조깅 시작/정지 버튼
                Container(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: !_isJogging ? _startJogging : _stopJogging,
                    icon: Icon(_isJogging ? Icons.stop : Icons.play_arrow),
                    label: Text(_isJogging ? "조깅 정지" : "조깅 시작"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isJogging ? Colors.red : Colors.lightGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // 추가 버튼들
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _resetJogging,
                        icon: const Icon(Icons.refresh),
                        label: const Text("초기화"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const JogHistoryScreen()),
                          );
                        },
                        icon: const Icon(Icons.history),
                        label: const Text("기록 보기"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 공유 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _shareJogRecord,
                    icon: const Icon(Icons.share),
                    label: const Text("조깅 기록 공유"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[50],
                      foregroundColor: Colors.blue[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.blue[200]!),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '실시간',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

Future<List<BinLocation>> fetchBinLocations() async {
  final url = Uri.parse(
      "https://data.melbourne.vic.gov.au/api/explore/v2.1/catalog/datasets/syringe-bin-locations/records?limit=20"
  );

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final records = data['results'] as List;
    return records.map((e) => BinLocation.fromJson(e)).toList();
  } else {
    throw Exception("데이터 불러오기 실패: ${response.statusCode}");
  }
} 