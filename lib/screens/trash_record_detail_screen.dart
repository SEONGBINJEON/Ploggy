import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';
import '../models/trash_record.dart';
import '../services/firebase_service.dart';
import '../utils/trash_labels.dart';

class TrashRecordDetailScreen extends StatefulWidget {
  final TrashRecord record;

  const TrashRecordDetailScreen({super.key, required this.record});

  @override
  State<TrashRecordDetailScreen> createState() => _TrashRecordDetailScreenState();
}

class _TrashRecordDetailScreenState extends State<TrashRecordDetailScreen> {
  final Set<Marker> _markers = {};

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
            title: koreanTrashLabel(widget.record.trashType),
            snippet: widget.record.locationDesc,
          ),
        ),
      );
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
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
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
    Widget fallback(BuildContext context, Object error, StackTrace? stackTrace) {
      return Container(
        color: Colors.grey[200],
        child: Icon(Icons.image, color: Colors.grey[400], size: 64),
      );
    }

    if (widget.record.imageBytes != null) {
      return Image.memory(widget.record.imageBytes!, fit: BoxFit.cover, errorBuilder: fallback);
    } else if (widget.record.imageUrl.startsWith('local://')) {
      final localPath = widget.record.imageUrl.replaceFirst('local://', '');
      return Image.file(File(localPath), fit: BoxFit.cover, errorBuilder: fallback);
    } else {
      return Image.network(widget.record.imageUrl, fit: BoxFit.cover, errorBuilder: fallback);
    }
  }

  Widget _buildInfoSection() {
    // 저장된 기록에는 분리수거 유형이 없어서 라벨로 다시 구합니다.
    final bin = binInfoFor(disposalTypeForLabel(widget.record.trashType));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.lightGreen[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  koreanTrashLabel(widget.record.trashType),
                  style: TextStyle(
                    color: Colors.lightGreen[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${widget.record.date.year}-${widget.record.date.month.toString().padLeft(2, '0')}-${widget.record.date.day.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 위치 정보
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.record.locationDesc,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 시간 정보
          Row(
            children: [
              const Icon(Icons.access_time, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                '${widget.record.date.hour.toString().padLeft(2, '0')}:${widget.record.date.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 분리수거 가이드
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bin.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: bin.color.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '분리수거 가이드 · ${bin.name}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: bin.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  disposalGuide(widget.record.trashType),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
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
              const SizedBox(height: 8),
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
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
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
        title: const Text('쓰레기 기록 상세'),
        backgroundColor: Colors.lightGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _showDeleteDialog(),
            tooltip: '삭제',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageSection(),
            const SizedBox(height: 16),
            _buildInfoSection(),
            const SizedBox(height: 16),

            const Text(
              '저장된 위치',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
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
        title: const Text('기록 삭제'),
        content: const Text('이 쓰레기 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
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
