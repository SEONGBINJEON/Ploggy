import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bin_location.dart';
import '../models/jog_record.dart';
import '../services/badge_service.dart';
import '../services/bin_location_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../widgets/badge_unlock_popup.dart';
import 'jog_history_screen.dart';

class JoggingScreen extends StatefulWidget {
  const JoggingScreen({super.key});

  @override
  State<JoggingScreen> createState() => _JoggingScreenState();
}

class _JoggingScreenState extends State<JoggingScreen> {
  // 이보다 오차가 큰 GPS 값은 거리가 튀는 원인이라 버립니다.
  static const double _maxAccuracyMeters = 35;
  // 실수로 시작·정지를 바로 누른 빈 기록은 저장하지 않습니다.
  static const int _minSavedSeconds = 10;
  static const LatLng _defaultCenter = LatLng(-37.8136, 144.9631); // 멜버른 중심

  final Stopwatch _stopwatch = Stopwatch();
  final LocationService _locationService = LocationService();
  final BinLocationService _binService = BinLocationService();
  final WeatherService _weatherService = WeatherService();
  final FirebaseService _firebaseService = FirebaseService();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _timer;
  Position? _lastPosition;
  double _totalDistance = 0.0; // m
  bool _isJogging = false;
  // 권한 확인을 기다리는 동안 버튼을 또 눌러 세션이 두 개 생기지 않도록 막습니다.
  bool _isStarting = false;
  // 정지하면 기록이 저장되고, 다음 시작은 새 세션으로 시작합니다.
  bool _sessionFinished = false;
  // 오차가 큰 위치만 들어와서 기록을 건너뛰는 중인지 (화면에 안내)
  bool _weakGps = false;

  GoogleMapController? _mapController;
  // 지도 플러그인은 지도가 만들어질 때 권한이 없으면 내 위치 표시를 켜지 않으므로,
  // 권한을 받은 뒤 값을 바꿔서 다시 적용되게 합니다.
  bool _hasLocationPermission = false;
  LatLng? _currentLatLng;
  final List<LatLng> _routePoints = [];
  final Set<Marker> _binMarkers = {};
  Marker? _startMarker;
  Marker? _endMarker;
  String? _binStatus;

  @override
  void initState() {
    super.initState();
    _locateAndLoadBins();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _positionSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _markPermissionGranted() {
    if (!_hasLocationPermission && mounted) {
      setState(() => _hasLocationPermission = true);
    }
  }

  // 지도를 현재 위치로 옮기고, 주변 쓰레기통을 불러옵니다.
  Future<void> _locateAndLoadBins() async {
    try {
      await _locationService.ensurePermission();
      _markPermissionGranted();
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() => _currentLatLng = latLng);
      _mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
      await _loadBinLocations(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('현재 위치를 가져오지 못했습니다: $e');
      if (mounted) setState(() => _binStatus = '위치 권한을 허용하면 주변 쓰레기통을 보여드려요');
    }
  }

  Future<void> _loadBinLocations(double lat, double lng) async {
    setState(() => _binStatus = '주변 쓰레기통을 찾는 중...');
    try {
      final bins = await _binService.fetchNearby(lat, lng);
      if (!mounted) return;
      setState(() {
        _binMarkers
          ..clear()
          ..addAll(bins.map((bin) {
            final isRecycling = bin.type == BinType.recycling;
            return Marker(
              markerId: MarkerId('bin_${bin.id}'),
              position: LatLng(bin.latitude, bin.longitude),
              infoWindow: InfoWindow(
                title: isRecycling ? '재활용 수거함' : '쓰레기통',
                snippet: bin.description,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                isRecycling ? BitmapDescriptor.hueYellow : BitmapDescriptor.hueRed,
              ),
            );
          }));
        _binStatus = bins.isEmpty
            ? '주변 1km 안에 등록된 쓰레기통이 없어요'
            : '주변 쓰레기통 ${bins.length}곳';
      });
    } catch (e) {
      debugPrint('쓰레기통 데이터 불러오기 실패: $e');
      if (mounted) setState(() => _binStatus = '쓰레기통 위치를 불러오지 못했어요');
    }
  }

  // Android에서는 카메라를 열거나 화면을 꺼도 경로 기록이 이어지도록
  // 알림이 있는 포그라운드 서비스로 위치를 받습니다.
  LocationSettings _locationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Ploggy 조깅 기록 중',
          notificationText: '조깅 경로를 기록하고 있어요. 앱에서 조깅 정지를 누르면 끝납니다.',
          notificationChannelName: '조깅 기록',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);
  }

  // "대략적인 위치"만 허용하면 오차가 수 km라서 조깅 기록을 할 수 없습니다.
  Future<bool> _hasPreciseLocation() async {
    if (kIsWeb) return true;
    try {
      return await Geolocator.getLocationAccuracy() != LocationAccuracyStatus.reduced;
    } catch (_) {
      return true;
    }
  }

  Future<void> _showPreciseLocationDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('정확한 위치가 꺼져 있어요'),
        content: const Text('대략적인 위치로는 조깅 거리와 경로를 기록할 수 없어요.\n설정에서 이 앱의 "정확한 위치"를 켜 주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Geolocator.openAppSettings();
            },
            child: const Text('설정 열기'),
          ),
        ],
      ),
    );
  }

  Future<void> _startJogging() async {
    if (_isJogging || _isStarting) return;
    setState(() => _isStarting = true);
    try {
      // 위치 권한 확인
      try {
        await _locationService.ensurePermission();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        return;
      }
      _markPermissionGranted();
      if (!await _hasPreciseLocation()) {
        if (mounted) await _showPreciseLocationDialog();
        return;
      }
      if (!mounted) return;

      await _positionSubscription?.cancel();
      _timer?.cancel();

      setState(() {
        if (_sessionFinished) _clearSession();
        _isJogging = true;
        _weakGps = false;
        _stopwatch.start();
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });

      // 세션마다 새 위치 스트림을 구독합니다.
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: _locationSettings(),
      ).listen(
        _onPosition,
        onError: (Object e) => debugPrint('위치 스트림 오류: $e'),
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _onPosition(Position pos) {
    // 정지 버튼을 누른 뒤 늦게 도착한 위치는 무시합니다.
    if (!_isJogging || !mounted) return;
    if (pos.accuracy > _maxAccuracyMeters) {
      if (!_weakGps) setState(() => _weakGps = true);
      return;
    }

    final currentLatLng = LatLng(pos.latitude, pos.longitude);
    final last = _lastPosition;
    setState(() {
      _weakGps = false;
      if (last != null) {
        _totalDistance += Geolocator.distanceBetween(
          last.latitude,
          last.longitude,
          pos.latitude,
          pos.longitude,
        );
      }
      _routePoints.add(currentLatLng);
      _currentLatLng = currentLatLng;

      // 시작 마커
      _startMarker ??= Marker(
        markerId: const MarkerId('start'),
        position: currentLatLng,
        infoWindow: const InfoWindow(title: '출발 지점'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      );
    });
    _lastPosition = pos;

    _mapController?.animateCamera(CameraUpdate.newLatLng(currentLatLng));
  }

  Future<void> _stopJogging() async {
    if (!_isJogging) return;

    // 기다리기 전에 화면 상태와 기록을 먼저 확정합니다. (두 번 눌러도 한 번만 저장)
    final last = _lastPosition;
    setState(() {
      _isJogging = false;
      _weakGps = false;
      _stopwatch.stop();
      _sessionFinished = true;

      // 종료 마커 추가
      if (last != null) {
        _endMarker = Marker(
          markerId: const MarkerId('end'),
          position: LatLng(last.latitude, last.longitude),
          infoWindow: const InfoWindow(title: '도착 지점'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        );
      }
    });
    final record = _currentRecord();

    _timer?.cancel();
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();

    await _saveJogRecord(record, last);
  }

  // 화면에 보이는 기록과 경로를 모두 지웁니다. (조깅 중이면 타이머는 0부터 계속)
  void _clearSession() {
    _stopwatch.reset();
    _totalDistance = 0.0;
    _lastPosition = null;
    _routePoints.clear();
    _startMarker = null;
    _endMarker = null;
    _sessionFinished = false;
  }

  void _resetJogging() {
    setState(_clearSession);
  }

  JogRecord _currentRecord() {
    return JogRecord(
      date: DateTime.now(),
      distanceKm: _totalDistance / 1000,
      durationSeconds: _stopwatch.elapsed.inSeconds,
      speedKmph: _calculateSpeed(),
      routeLatLng: [
        for (final p in _routePoints) ...[p.latitude, p.longitude],
      ],
    );
  }

  Future<void> _saveJogRecord(JogRecord record, Position? last) async {
    if (!mounted) return;
    if (record.durationSeconds < _minSavedSeconds && record.distanceKm == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기록이 너무 짧아서 저장하지 않았어요.')),
      );
      return;
    }

    await Hive.box<JogRecord>('jog_records').add(record);

    // 랭킹용 누적 기록. 오프라인이면 서버 응답이 늦어지므로 기다리지 않습니다.
    unawaited(_firebaseService
        .addJogStats(distanceKm: record.distanceKm, durationSec: record.durationSeconds)
        .catchError((Object e) {
      debugPrint('랭킹 기록 업데이트 실패: $e');
    }));

    // 비/눈 뱃지를 위해 마지막 위치의 현재 날씨를 확인합니다.
    final weatherCode = last == null
        ? null
        : await _weatherService.currentWeatherCode(last.latitude, last.longitude);

    // 뱃지 조건 체크
    if (!mounted) return;
    final newlyUnlocked = await context.read<BadgeService>().checkBadgeConditions(weatherCode: weatherCode);
    if (!mounted) return;
    await showBadgeUnlockPopups(context, newlyUnlocked);
  }

  void _shareJogRecord() {
    Share.share(_currentRecord().toShareText());
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  double _calculateSpeed() {
    final seconds = _stopwatch.elapsed.inSeconds;
    if (seconds == 0) return 0.0;
    final mps = _totalDistance / seconds;
    return mps * 3.6;
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
                    color: Colors.grey.withValues(alpha: 0.2),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _currentLatLng ?? _defaultCenter,
                        zoom: 16,
                      ),
                      myLocationEnabled: _hasLocationPermission,
                      myLocationButtonEnabled: _hasLocationPermission,
                      polylines: {
                        Polyline(
                          polylineId: const PolylineId("route"),
                          color: Colors.blue,
                          width: 5,
                          points: _routePoints,
                        ),
                      },
                      markers: {
                        ..._binMarkers,
                        if (_startMarker != null) _startMarker!,
                        if (_endMarker != null) _endMarker!,
                      },
                      onMapCreated: (controller) {
                        _mapController = controller;
                        final current = _currentLatLng;
                        if (current != null) {
                          controller.moveCamera(CameraUpdate.newLatLng(current));
                        }
                      },
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_binStatus != null) _MapChip(text: _binStatus!),
                          if (_isJogging && _weakGps) ...[
                            const SizedBox(height: 6),
                            const _MapChip(text: 'GPS 신호가 약해요. 하늘이 보이는 곳에서 잡힐 때까지 기다리는 중'),
                          ],
                        ],
                      ),
                    ),
                    // OpenStreetMap 데이터 사용 시 출처 표시가 필요합니다. (ODbL)
                    const Positioned(
                      left: 8,
                      bottom: 28,
                      child: _MapChip(text: '쓰레기통 데이터 © OpenStreetMap contributors', small: true),
                    ),
                  ],
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
                  color: Colors.grey.withValues(alpha: 0.1),
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isStarting ? null : (!_isJogging ? _startJogging : _stopJogging),
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
            color: Colors.grey.withValues(alpha: 0.1),
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

class _MapChip extends StatelessWidget {
  final String text;
  final bool small;
  const _MapChip({required this.text, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 10, vertical: small ? 2 : 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(small ? 4 : 12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: small ? 9 : 12, color: Colors.black87),
      ),
    );
  }
}
