import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PloggingMap extends StatelessWidget {
  const PloggingMap({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Center(child: Text('웹에서는 지도 기능이 지원되지 않습니다.'));
    }
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(-37.8136, 144.9631), // 멜버른 중심
        zoom: 14,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }
} 