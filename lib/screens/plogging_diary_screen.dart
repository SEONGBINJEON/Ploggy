import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/diary_entry.dart';
import '../models/jog_record.dart';
import '../services/firebase_service.dart';
import '../widgets/route_map_preview.dart';
import 'plogging_diary_write_screen.dart';

class PloggingDiaryScreen extends StatefulWidget {
  const PloggingDiaryScreen({super.key});

  @override
  State<PloggingDiaryScreen> createState() => _PloggingDiaryScreenState();
}

class _PloggingDiaryScreenState extends State<PloggingDiaryScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  Stream<List<DiaryEntry>>? _diaryStream;

  @override
  void initState() {
    super.initState();
    final user = _firebaseService.currentUser;
    if (user != null) {
      _diaryStream = _firebaseService.diaryEntriesStream(user.uid);
    }
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return '0분';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '$hours시간 $minutes분';
    } else {
      return '$minutes분';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmDelete(DiaryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('일기 삭제'),
        content: Text('"${entry.title}" 일기를 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _firebaseService.deleteDiaryEntry(entry.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('플로깅 다이어리', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionTitle(icon: Icons.directions_run, title: '오늘의 조깅'),
          ValueListenableBuilder(
            valueListenable: Hive.box<JogRecord>('jog_records').listenable(),
            builder: (context, Box<JogRecord> box, _) {
              final today = DateTime.now();
              final todayStart = DateTime(today.year, today.month, today.day);
              final todayEnd = todayStart.add(const Duration(days: 1));

              final todayRecords = box.values
                  .where((record) => !record.date.isBefore(todayStart) && record.date.isBefore(todayEnd))
                  .toList()
                  .reversed
                  .toList();

              if (todayRecords.isEmpty) {
                return const _EmptyCard(
                  message: '오늘은 아직 조깅하지 않았습니다',
                  hint: '조깅을 시작하여 오늘의 기록을 남겨보세요!',
                );
              }

              return Column(
                children: todayRecords.map(_buildJogCard).toList(),
              );
            },
          ),
          const SizedBox(height: 8),
          const _SectionTitle(icon: Icons.book, title: '내 플로깅 일기'),
          if (_diaryStream == null)
            const _EmptyCard(message: '로그인하면 일기를 볼 수 있어요')
          else
            StreamBuilder<List<DiaryEntry>>(
              stream: _diaryStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _EmptyCard(message: '일기를 불러오지 못했어요', hint: '${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(color: Colors.lightGreen)),
                  );
                }
                final entries = snapshot.data!;
                if (entries.isEmpty) {
                  return const _EmptyCard(
                    message: '아직 작성한 일기가 없어요',
                    hint: '+ 버튼으로 오늘의 플로깅을 기록해 보세요',
                  );
                }
                return Column(children: entries.map(_buildDiaryCard).toList());
              },
            ),
          const SizedBox(height: 72),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.lightGreen,
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PloggingDiaryWriteScreen()));
        },
        tooltip: '새 플로깅 기록 추가',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildJogCard(JogRecord record) {
    return Card(
      // 새 기록이 맨 위에 끼어들어도 카드(지도)가 다른 기록과 섞이지 않도록 키를 줍니다.
      key: ValueKey(record.key),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_run,
                  color: Colors.green[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '조깅 기록',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green[600],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatDate(record.date),
                    style: TextStyle(fontSize: 13, color: Colors.green[700]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Info(label: '거리', value: '${record.distanceKm.toStringAsFixed(1)}km'),
                _Info(label: '시간', value: _formatDuration(record.durationSeconds)),
                _Info(label: '속도', value: '${record.speedKmph.toStringAsFixed(1)}km/h'),
              ],
            ),
            const SizedBox(height: 16),
            RouteMapPreview(points: record.routePoints, height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildDiaryCard(DiaryEntry entry) {
    final stats = [
      if (entry.distanceKm != null) '${entry.distanceKm!.toStringAsFixed(1)}km',
      if (entry.time.isNotEmpty) entry.time,
      if (entry.steps != null) '${entry.steps} steps',
    ];
    return Card(
      key: ValueKey(entry.id),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Text(_formatDate(entry.createdAt), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.grey[500], size: 20),
                  tooltip: '삭제',
                  onPressed: () => _confirmDelete(entry),
                ),
              ],
            ),
            if (stats.isNotEmpty)
              Text(stats.join(' · '), style: TextStyle(color: Colors.green[700], fontSize: 13)),
            if (entry.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    entry.imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
            if (entry.memo.isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(entry.memo, style: const TextStyle(fontSize: 14, height: 1.4)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.green[600], size: 22),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700])),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  final String? hint;
  const _EmptyCard({required this.message, this.hint});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            message,
            style: TextStyle(fontSize: 15, color: Colors.grey[700], fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(hint!, style: TextStyle(fontSize: 13, color: Colors.grey[500]), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  const _Info({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
