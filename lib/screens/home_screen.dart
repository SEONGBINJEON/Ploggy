import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/jog_record.dart';
import '../services/auth_provider.dart';
import 'plogging_diary_screen.dart';
import 'trash_camera_screen.dart';
import 'jogging_screen.dart';
import 'community_screen.dart';
import '../main.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ploggy'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                final authProvider = context.read<AuthProvider>();
                try {
                  await authProvider.signOut();
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('로그아웃 중 오류가 발생했습니다: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('로그아웃', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.more_vert),
            ),
          ),
        ],
      ),
      body: const HomeMainContent(),
    );
  }
}

class HomeMainContent extends StatefulWidget {
  const HomeMainContent({Key? key}) : super(key: key);

  @override
  State<HomeMainContent> createState() => _HomeMainContentState();
}

class _HomeMainContentState extends State<HomeMainContent> {

  // 오늘의 조깅 기록 계산
  Map<String, dynamic> _getTodayJoggingStats() {
    try {
      final jogBox = Hive.box<JogRecord>('jog_records');
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      double totalDistance = 0.0;
      int totalDuration = 0;
      int totalSteps = 0;

      for (final record in jogBox.values) {
        if (record.date.isAfter(todayStart) && record.date.isBefore(todayEnd)) {
          totalDistance += record.distanceKm;
          totalDuration += record.durationSeconds;
          totalSteps += (record.distanceKm * 1300).round(); // 1km당 약 1300보로 계산
        }
      }

      return {
        'distance': totalDistance,
        'duration': totalDuration,
        'steps': totalSteps,
      };
    } catch (e) {
      print('오늘의 조깅 기록 계산 오류: $e');
      return {
        'distance': 0.0,
        'duration': 0,
        'steps': 0,
      };
    }
  }

  String _formatDuration(int seconds) {
    if (seconds == 0) return '0분';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    
    if (hours > 0) {
      return '${hours}시간 ${minutes}분';
    } else {
      return '${minutes}분';
    }
  }

  Future<void> _launchYouTubeVideo(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('영상을 열 수 없습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'icon': Icons.menu_book, 'label': 'Plogging\nDiary'},
      {'icon': Icons.delete, 'label': 'Trash\nClassification'},
      {'icon': Icons.map, 'label': 'Jogging\nRecord'},
      {'icon': Icons.people, 'label': 'Community'},
    ];
    

    
    final gallery = [];
    final runningDiary = [];

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 16),
            // 오늘의 조깅 정보 (일러스트+텍스트)
            ValueListenableBuilder(
              valueListenable: Hive.box<JogRecord>('jog_records').listenable(),
              builder: (context, Box<JogRecord> box, _) {
                final todayStats = _getTodayJoggingStats();
                final distanceText = '${todayStats['distance'].toStringAsFixed(1)}km';
                final stepsText = '${todayStats['steps'].toStringAsFixed(0)} steps';
                final durationText = _formatDuration(todayStats['duration']);
                
                return Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 120,
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
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Image.network(
                        'https://cdn.pixabay.com/photo/2017/01/31/13/14/people-2026444_1280.png',
                        width: 120,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(Icons.directions_run, size: 100, color: Colors.grey[300]),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 30,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Today', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            '$distanceText  $stepsText  $durationText',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // 카테고리
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: categories.isEmpty
                  ? const Center(child: Text('카테고리가 없습니다', style: TextStyle(color: Colors.grey, fontSize: 16)))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(categories.length, (idx) {
                        final cat = categories[idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(32),
                            onTap: () {
                              tabIndexNotifier.value = idx + 1;
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.grey[200],
                                  child: Icon(cat['icon'] as IconData, size: 32, color: Colors.black87),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  cat['label'] as String,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
            ),
            const SizedBox(height: 24),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
} 