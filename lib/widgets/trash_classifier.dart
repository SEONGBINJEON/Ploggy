import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/trash_record.dart';
import '../screens/trash_record_detail_screen.dart';
import '../services/badge_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/trash_classification_service.dart';
import '../utils/trash_labels.dart';
import 'badge_unlock_popup.dart';

class TrashClassifier extends StatefulWidget {
  const TrashClassifier({super.key});

  @override
  State<TrashClassifier> createState() => _TrashClassifierState();
}

class _TrashClassifierState extends State<TrashClassifier> {
  // 이 값보다 신뢰도가 낮으면 다시 찍어 보라고 안내합니다.
  static const double _lowConfidenceThreshold = 0.5;

  Uint8List? _imageBytes;
  TrashClassificationResult? _classificationResult;
  bool _isClassifying = false;
  bool _isSaving = false;
  // 같은 사진을 여러 번 저장해 수거 개수·랭킹이 부풀지 않도록 한 번만 저장합니다.
  bool _isSaved = false;
  bool _showHistory = false;
  final TrashClassificationService _classificationService = TrashClassificationService();
  final FirebaseService _firebaseService = FirebaseService();
  final LocationService _locationService = LocationService();
  final Uuid _uuid = const Uuid();

  StreamSubscription<List<TrashRecord>>? _recordsSubscription;
  List<TrashRecord> _trashRecords = [];

  @override
  void initState() {
    super.initState();
    _initializeService();
    _listenTrashRecords();
  }

  @override
  void dispose() {
    _recordsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeService() async {
    try {
      await _classificationService.initialize();
    } catch (e) {
      debugPrint('서비스 초기화 실패: $e');
    }
  }

  // Firestore 스트림은 한 번만 구독합니다. (저장할 때마다 다시 구독하지 않음)
  void _listenTrashRecords() {
    final user = _firebaseService.currentUser;
    if (user == null) return;
    _recordsSubscription = _firebaseService.getTrashRecords(user.uid).listen(
      (records) {
        if (mounted) setState(() => _trashRecords = records);
      },
      onError: (Object error) => debugPrint('쓰레기 기록 조회 에러: $error'),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    // 모델 입력은 224px이라 원본 고해상도 사진이 필요 없습니다.
    // 크기를 줄이면 분석이 빨라지고 업로드 용량도 줄어듭니다.
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _classificationResult = null;
      _isSaved = false;
    });

    // 이미지 분류 실행
    await _classifyImage();
  }

  Future<void> _classifyImage() async {
    final imageBytes = _imageBytes;
    if (imageBytes == null) return;

    setState(() {
      _isClassifying = true;
    });

    try {
      final result = await _classificationService.classifyImage(imageBytes);
      if (!mounted) return;
      setState(() {
        _classificationResult = result;
        _isClassifying = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isClassifying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 분류 실패: $e')),
      );
    }
  }

  Future<void> _saveTrashRecord() async {
    final imageBytes = _imageBytes;
    final result = _classificationResult;
    if (imageBytes == null || result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지와 분류 결과가 필요합니다.')),
      );
      return;
    }
    if (_isSaved || result.isDemo) return;

    final user = _firebaseService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 현재 위치 정보 가져오기 (위치를 못 받아도 기록은 저장합니다)
      Map<String, dynamic> locationInfo;
      try {
        locationInfo = await _locationService.getCurrentLocationInfo();
      } catch (e) {
        debugPrint('위치 없이 저장합니다: $e');
        locationInfo = {'address': '위치 정보 없음', 'latitude': null, 'longitude': null};
      }

      // 이미지 업로드
      final fileName = '${_uuid.v4()}.jpg';
      final imageUrl = await _firebaseService.uploadImageBytes(imageBytes, fileName);

      // 쓰레기 기록 생성
      final trashRecord = TrashRecord(
        id: _uuid.v4(),
        userId: user.uid,
        imageUrl: imageUrl,
        trashType: result.topResult.label,
        date: DateTime.now(),
        locationDesc: locationInfo['address'],
        latitude: locationInfo['latitude'],
        longitude: locationInfo['longitude'],
        imageBytes: imageBytes,
      );

      // Firebase에 저장
      final synced = await _firebaseService.saveTrashRecord(trashRecord);

      // 랭킹용 누적 수거 개수 (기다리지 않고, 실패해도 기록 저장은 성공으로 처리)
      unawaited(_firebaseService.incrementTrashCount().catchError((Object e) {
        debugPrint('수거 개수 업데이트 실패: $e');
      }));

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(synced
              ? '쓰레기 기록이 저장되었습니다!'
              : '오프라인이라 기기에 먼저 저장했어요. 연결되면 자동으로 올라가요.'),
        ),
      );

      // 쓰레기 수거 뱃지 확인
      final newlyUnlocked = await context.read<BadgeService>().recordTrashCollected();
      if (!mounted) return;
      await showBadgeUnlockPopups(context, newlyUnlocked);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
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
              '저장된 기록 (${_trashRecords.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          const SizedBox(height: 16),
          if (_trashRecords.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
              physics: const NeverScrollableScrollPhysics(),
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
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _showTrashRecordDetail(record),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
              const SizedBox(width: 16),

              // 정보 섹션
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      koreanTrashLabel(record.trashType),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.locationDesc,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
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
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _deleteRecord(record.id),
                    tooltip: '삭제',
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.blue, size: 20),
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
    Widget fallback(BuildContext context, Object error, StackTrace? stackTrace) {
      return Container(
        color: Colors.grey[200],
        child: Icon(Icons.image, color: Colors.grey[400]),
      );
    }

    if (record.imageBytes != null) {
      return Image.memory(record.imageBytes!, fit: BoxFit.cover, errorBuilder: fallback);
    } else if (record.imageUrl.startsWith('local://')) {
      // 로컬 이미지
      final localPath = record.imageUrl.replaceFirst('local://', '');
      return Image.file(File(localPath), fit: BoxFit.cover, errorBuilder: fallback);
    } else {
      // 네트워크 이미지
      return Image.network(record.imageUrl, fit: BoxFit.cover, errorBuilder: fallback);
    }
  }

  Future<void> _showTrashRecordDetail(TrashRecord record) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrashRecordDetailScreen(record: record),
      ),
    );

    if (result == true && mounted) {
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
          const SnackBar(content: Text('기록이 삭제되었습니다.')),
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

  Widget _buildResultSection(TrashClassificationResult result) {
    final top = result.topResult;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.isDemo)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: const Text(
              '웹에서는 AI 모델이 동작하지 않아 화면 확인용 임의 결과를 보여줍니다. 실제 분류는 모바일 앱에서 확인하세요.',
              style: TextStyle(fontSize: 13),
            ),
          ),
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
                    '${top.label.toUpperCase()} · ${koreanTrashLabel(top.label)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '신뢰도: ${top.confidencePercentage}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (top.confidence < _lowConfidenceThreshold)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'AI가 확신하지 못하고 있어요. 쓰레기가 화면 가운데에 크게 나오도록 다시 찍어 보세요.',
              style: TextStyle(fontSize: 13, color: Colors.orange[800]),
            ),
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
              ...result.allResults.take(3).map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r.label, style: const TextStyle(fontSize: 14)),
                    Text(r.confidencePercentage, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDisposalSection(ClassificationResult top) {
    final bin = binInfoFor(top.disposalType);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bin.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bin.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete, color: bin.color),
              const SizedBox(width: 6),
              Text(
                '분리수거 유형: ${top.disposalType}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(bin.name, style: TextStyle(fontSize: 13, color: bin.color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            disposalGuide(top.label),
            style: const TextStyle(fontSize: 15, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _classificationResult;
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
                    // 웹에는 카메라 대신 파일 선택이 열립니다.
                    onPressed: _isClassifying ? null : () => _pickImage(kIsWeb ? ImageSource.gallery : ImageSource.camera),
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
                    onPressed: _isClassifying ? null : () => _pickImage(ImageSource.gallery),
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
            else if (result != null)
              _buildResultSection(result),
            const SizedBox(height: 24),
            if (result != null && !_isClassifying) ...[
              _buildDisposalSection(result.topResult),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving || _isSaved || result.isDemo ? null : _saveTrashRecord,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightGreen,
                    disabledBackgroundColor: _isSaving ? Colors.lightGreen : Colors.grey[500],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const Row(
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
                      : Text(
                          result.isDemo
                              ? '웹 데모 결과는 저장할 수 없어요'
                              : _isSaved
                                  ? '저장됨 · 새 사진을 찍어 주세요'
                                  : '저장',
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                        ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }
}
