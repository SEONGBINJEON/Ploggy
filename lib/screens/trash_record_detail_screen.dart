import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';
import '../models/trash_record.dart';
import '../services/firebase_service.dart';

class TrashRecordDetailScreen extends StatefulWidget {
  final TrashRecord record;

  const TrashRecordDetailScreen({Key? key, required this.record}) : super(key: key);

  @override
  State<TrashRecordDetailScreen> createState() => _TrashRecordDetailScreenState();
}

class _TrashRecordDetailScreenState extends State<TrashRecordDetailScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  void _initializeMap() {
    if (widget.record.latitude != null && widget.record.longitude != null) {
      _markers.add(
        Marker(
          markerId: MarkerId(widget.record.id),
          position: LatLng(widget.record.latitude!, widget.record.longitude!),
          infoWindow: InfoWindow(
            title: _getKoreanLabel(widget.record.trashType),
            snippet: widget.record.locationDesc,
          ),
        ),
      );
    }
  }

  String _getKoreanLabel(String label) {
    switch (label.toLowerCase()) {
      case 'glass': return '유리류';
      case 'metal': return '금속류';
      case 'organics': return '음식물류';
      case 'paper': return '종이류';
      case 'plastic': return '플라스틱류';
      case 'trash': return '일반쓰레기';
      default: return label;
    }
  }

  String _getDisposalGuide(String label) {
    switch (label.toLowerCase()) {
      case 'glass':
        return '유리류는 깨끗이 씻은 후 투명한 봉투에 담아 배출하세요.';
      case 'metal':
        return '금속류는 깨끗이 씻은 후 압축하여 배출하세요.';
      case 'organics':
        return '음식물류는 물기를 제거하고 전용 봉투에 담아 배출하세요.';
      case 'paper':
        return '종이류는 깨끗하고 평평하게 펴서 묶어 배출하세요.';
      case 'plastic':
        return '플라스틱류는 깨끗이 씻은 후 압축하여 배출하세요.';
      case 'trash':
        return '일반쓰레기는 전용 봉투에 담아 배출하세요.';
      default:
        return '분리수거 방법을 확인해주세요.';
    }
  }

  Widget _buildImageSection() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _buildRecordImage(),
      ),
    );
  }

  Widget _buildRecordImage() {
    if (widget.record.imageBytes != null) {
      return Image.memory(
        widget.record.imageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: Icon(Icons.image, color: Colors.grey[400], size: 64),
          );
        },
      );
    } else if (widget.record.imageUrl.startsWith('local://')) {
      final localPath = widget.record.imageUrl.replaceFirst('local://', '');
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: Icon(Icons.image, color: Colors.grey[400], size: 64),
          );
        },
      );
    } else {
      return Image.network(
        widget.record.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: Icon(Icons.image, color: Colors.grey[400], size: 64),
          );
        },
      );
    }
  }

  Widget _buildInfoSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.lightGreen[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getKoreanLabel(widget.record.trashType),
                  style: TextStyle(
                    color: Colors.lightGreen[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Spacer(),
              Text(
                '${widget.record.date.year}-${widget.record.date.month.toString().padLeft(2, '0')}-${widget.record.date.day.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // 위치 정보
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.record.locationDesc,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          
          // 시간 정보
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                '${widget.record.date.hour.toString().padLeft(2, '0')}:${widget.record.date.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // 분리수거 가이드
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '분리수거 가이드',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _getDisposalGuide(widget.record.trashType),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    if (widget.record.latitude == null || widget.record.longitude == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, color: Colors.grey[400], size: 48),
              SizedBox(height: 8),
              Text(
                '위치 정보가 없습니다',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(widget.record.latitude!, widget.record.longitude!),
            zoom: 15.0,
          ),
          markers: _markers,
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('쓰레기 기록 상세'),
        backgroundColor: Colors.lightGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () => _showDeleteDialog(),
            tooltip: '삭제',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageSection(),
            SizedBox(height: 16),
            _buildInfoSection(),
            SizedBox(height: 16),
            
            Text(
              '저장된 위치',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            _buildMapSection(),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('기록 삭제'),
        content: Text('이 쓰레기 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await FirebaseService().deleteTrashRecord(widget.record.id);
        if (mounted) {
          Navigator.pop(context, true); // true는 삭제됨을 의미
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    }
  }
}
