import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/jog_record.dart';
import '../widgets/route_map_preview.dart';
import 'package:share_plus/share_plus.dart';

class JogHistoryScreen extends StatelessWidget {
  const JogHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final jogBox = Hive.box<JogRecord>('jog_records');

    return Scaffold(
      appBar: AppBar(
        title: const Text("📋 조깅 기록"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ValueListenableBuilder(
        valueListenable: jogBox.listenable(),
        builder: (context, Box<JogRecord> box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_run,
                    size: 100,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 20),
                  Text(
                    "조깅 기록이 없습니다.",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "조깅을 시작하여 기록을 남겨보세요!",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          final records = box.values.toList().reversed.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              return Card(
                key: ValueKey(record.key),
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(
                          Icons.directions_run,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        "${record.date.toLocal()}".split(' ')[0],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            "⏱ 시간: ${record.durationSeconds ~/ 60}분 ${record.durationSeconds % 60}초",
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            "📏 거리: ${record.distanceKm.toStringAsFixed(2)} km",
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            "🚀 평균 속도: ${record.speedKmph.toStringAsFixed(2)} km/h",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.share, color: Colors.green),
                        onPressed: () {
                          Share.share(record.toShareText());
                        },
                      ),
                    ),
                    if (record.routePoints.length >= 2)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: RouteMapPreview(points: record.routePoints, height: 120),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
