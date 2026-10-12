import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/route_share.dart';

/// 저장된 조깅 경로를 작은 지도로 보여줍니다. (Android는 가벼운 lite 모드)
class RouteMapPreview extends StatefulWidget {
  final List<RoutePoint> points;
  final double height;

  const RouteMapPreview({super.key, required this.points, this.height = 140});

  @override
  State<RouteMapPreview> createState() => _RouteMapPreviewState();
}

class _RouteMapPreviewState extends State<RouteMapPreview> {
  GoogleMapController? _controller;

  List<LatLng> get _latLngs => [for (final p in widget.points) LatLng(p.lat, p.lng)];

  @override
  void didUpdateWidget(RouteMapPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 지도는 initialCameraPosition 변경을 무시하므로, 경로가 바뀌면 직접 다시 맞춥니다.
    if (!listEquals(oldWidget.points, widget.points)) {
      _fitToRoute();
    }
  }

  Future<void> _fitToRoute() async {
    final controller = _controller;
    final latLngs = _latLngs;
    if (controller == null || latLngs.length < 2) return;
    try {
      await controller.moveCamera(CameraUpdate.newLatLngBounds(_boundsOf(latLngs), 24));
    } catch (_) {
      // 지도 크기가 아직 정해지지 않았거나 화면에서 사라진 경우는 무시
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || widget.points.length < 2) {
      return _placeholder(kIsWeb ? '웹에서는 지도를 표시하지 않습니다' : '저장된 경로가 없습니다');
    }

    final latLngs = _latLngs;
    final bounds = _boundsOf(latLngs);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: GoogleMap(
          liteModeEnabled: true,
          initialCameraPosition: CameraPosition(
            target: LatLng(
              (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
              (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
            ),
            zoom: 14,
          ),
          onMapCreated: (controller) async {
            _controller = controller;
            // 지도 크기가 정해진 뒤에 경로 전체가 보이도록 맞춥니다.
            await Future<void>.delayed(const Duration(milliseconds: 300));
            await _fitToRoute();
          },
          polylines: {
            Polyline(
              polylineId: const PolylineId('route'),
              color: Colors.blue,
              width: 4,
              points: latLngs,
            ),
          },
          markers: {
            Marker(
              markerId: const MarkerId('start'),
              position: latLngs.first,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            ),
            Marker(
              markerId: const MarkerId('end'),
              position: latLngs.last,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
            ),
          },
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }

  Widget _placeholder(String message) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        height: widget.height,
        color: Colors.grey[100],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 32, color: Colors.grey[500]),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      ),
    );
  }

  static LatLngBounds _boundsOf(List<LatLng> points) {
    var minLat = points.first.latitude, maxLat = minLat;
    var minLng = points.first.longitude, maxLng = minLng;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }
}
