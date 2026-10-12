import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../services/trash_classification_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../models/trash_record.dart';
import '../screens/trash_record_detail_screen.dart';

class TrashClassifier extends StatefulWidget {
  @override
  State<TrashClassifier> createState() => _TrashClassifierState();
}

class _TrashClassifierState extends State<TrashClassifier> {
  XFile? _image;
  Uint8List? _imageBytes;
  TrashClassificationResult? _classificationResult;
  bool _isClassifying = false;
  bool _isSaving = false;
  bool _showHistory = false;
  final TrashClassificationService _classificationService = TrashClassificationService();
  final FirebaseService _firebaseService = FirebaseService();
  final LocationService _locationService = LocationService();
  final Uuid _uuid = Uuid();
  
  List<TrashRecord> _trashRecords = [];

  @override
  void initState() {
    super.initState();
    _initializeService();
    _checkFirebaseConnection();
    _loadTrashRecords();
  }

  Future<void> _initializeService() async {
    try {
      await _classificationService.initialize();
    } catch (e) {
      print('서비스 초기화 실패: $e');
    }
  }

  Future<void> _checkFirebaseConnection() async {
    try {
      final isConnected = await _firebaseService.checkFirebaseConnection();
      if (mounted) {
        if (!isConnected) {
          // 연결 실패 시에도 앱은 계속 실행 (휴대폰 환경 고려)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Firebase 연결에 일시적인 문제가 있습니다. 일부 기능이 제한될 수 있습니다.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          // 연결 성공 시 알림
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Firebase 연결 성공!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Firebase 연결 확인 실패: $e');
      // 에러가 발생해도 앱은 계속 실행
    }
  }

  Future<void> _loadTrashRecords() async {
    final user = _firebaseService.currentUser;
    if (user != null) {
      _firebaseService.getTrashRecords(user.uid).listen((records) {
        setState(() {
          _trashRecords = records;
        });
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _image = picked;
        _imageBytes = bytes;
        _classificationResult = null;
      });
      
      // 이미지 분류 실행
      await _classifyImage();
    }
  }

  Future<void> _classifyImage() async {
    if (_imageBytes == null) return;
    
    setState(() {
      _isClassifying = true;
    });
    
    try {
      final result = await _classificationService.classifyImage(_imageBytes!);
      
      setState(() {
        _classificationResult = result;
        _isClassifying = false;
      });
    } catch (e) {
      setState(() {
        _isClassifying = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 분류 실패: $e')),
      );
    }
  }

  Future<void> _uploadImage() async {
    // TODO: 갤러리에서 이미지 업로드 구현
  }

  Future<void> _saveTrashRecord() async {
    if (_imageBytes == null || _classificationResult == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지와 분류 결과가 필요합니다.')),
        );
      }
      return;
    }

    final user = _firebaseService.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인이 필요합니다.')),
        );
      }
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 현재 위치 정보 가져오기
      final locationInfo = await _locationService.getCurrentLocationInfo();
      
      // 이미지 업로드
      final fileName = '${_uuid.v4()}.jpg';
      final imageUrl = await _firebaseService.uploadImageBytes(_imageBytes!, fileName);
      
      // 쓰레기 기록 생성
      final trashRecord = TrashRecord(
        id: _uuid.v4(),
        userId: user.uid,
        imageUrl: imageUrl,
        trashType: _classificationResult!.topResult.label,
        date: DateTime.now(),
        locationDesc: locationInfo['address'],
        latitude: locationInfo['latitude'],
        longitude: locationInfo['longitude'],
        imageBytes: _imageBytes,
      );
      
      // Firebase에 저장
      await _firebaseService.saveTrashRecord(trashRecord);
      
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('쓰레기 기록이 저장되었습니다!')),
        );
        
        // 기록 목록 새로고침
        _loadTrashRecords();
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
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

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '저장된 기록',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _showHistory = !_showHistory;
                });
              },
              child: Text(_showHistory ? '접기' : '펼치기'),
            ),
          ],
        ),
        if (_showHistory) ...[
          SizedBox(height: 16),
          if (_trashRecords.isEmpty)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '아직 저장된 기록이 없습니다.',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _trashRecords.length,
              itemBuilder: (context, index) {
                final record = _trashRecords[index];
                return _buildTrashRecordCard(record);
              },
            ),
        ],
      ],
    );
  }

  Widget _buildTrashRecordCard(TrashRecord record) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _showTrashRecordDetail(record),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              // 이미지 섹션
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildRecordImage(record),
                ),
              ),
              SizedBox(width: 16),
              
              // 정보 섹션
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.trashType,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      record.locationDesc,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')} ${record.date.hour.toString().padLeft(2, '0')}:${record.date.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 액션 버튼
              Column(
                children: [
                  IconButton(
                    icon: Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _deleteRecord(record.id),
                    tooltip: '삭제',
                  ),
                  IconButton(
                    icon: Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    onPressed: () => _showTrashRecordDetail(record),
                    tooltip: '상세보기',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordImage(TrashRecord record) {
    if (record.imageBytes != null) {
      return Image.memory(
        record.imageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: Icon(Icons.image, color: Colors.grey[400]),
          );
        },
      );
    } else if (record.imageUrl.startsWith('local://')) {
      // 로컬 이미지
      final localPath = record.imageUrl.replaceFirst('local://', '');
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: Icon(Icons.image, color: Colors.grey[400]),
          );
        },
      );
    } else {
      // 네트워크 이미지
      return Image.network(
        record.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[200],
            child: Icon(Icons.image, color: Colors.grey[400]),
          );
        },
      );
    }
  }

  Future<void> _showTrashRecordDetail(TrashRecord record) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrashRecordDetailScreen(record: record),
      ),
    );

    if (result == true) {
      // 기록이 삭제되었으면 목록에서 제거
      setState(() {
        _trashRecords.removeWhere((r) => r.id == record.id);
      });
    }
  }

  Future<void> _deleteRecord(String recordId) async {
    try {
      await _firebaseService.deleteTrashRecord(recordId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('기록이 삭제되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  Widget _buildImageDisplay() {
    if (_imageBytes == null) {
      return Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Center(child: Text('이미지를 촬영/업로드 해주세요', style: TextStyle(color: Colors.grey))),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        _imageBytes!,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildThumbnailImage(Uint8List imageBytes, {double width = 56, double height = 56}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.memory(
        imageBytes,
        width: width,
        height: height,
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildImageDisplay(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _pickImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text('(재)촬영', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _uploadImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text('업로드', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isClassifying)
              Container(
                padding: const EdgeInsets.all(16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.lightGreen),
                    SizedBox(width: 16),
                    Text('AI가 이미지를 분석하고 있습니다...', style: TextStyle(fontSize: 16)),
                  ],
                ),
              )
            else if (_classificationResult != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildThumbnailImage(_imageBytes!),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('AI Classification Result', style: TextStyle(fontSize: 13, color: Colors.grey)),
                            const SizedBox(height: 4),
                            Text(
                              _classificationResult!.topResult.label.toUpperCase(),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '신뢰도: ${_classificationResult!.topResult.confidencePercentage}',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 상위 3개 결과 표시
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('상위 결과:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ..._classificationResult!.allResults.take(3).map((result) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(result.label, style: const TextStyle(fontSize: 14)),
                              Text('${result.confidencePercentage}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            if (_classificationResult != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      '분리수거 유형: ${_classificationResult!.topResult.disposalType}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getDisposalGuide(_classificationResult!.topResult.label),
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            if (_classificationResult != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveTrashRecord,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('저장 중...', style: TextStyle(color: Colors.white, fontSize: 18)),
                          ],
                        )
                      : Text('저장', style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
            const SizedBox(height: 32),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }
} 