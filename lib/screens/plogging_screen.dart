import 'dart:async';
import 'package:flutter/material.dart';

class PloggingScreen extends StatefulWidget {
  const PloggingScreen({Key? key}) : super(key: key);

  @override
  State<PloggingScreen> createState() => _PloggingScreenState();
}

class _PloggingScreenState extends State<PloggingScreen> {
  bool isRunning = false;
  bool isPaused = false;
  int seconds = 0;
  Timer? _timer;

  void _startPlog() {
    setState(() {
      isRunning = true;
      isPaused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isPaused) {
        setState(() {
          seconds++;
        });
      }
    });
  }

  void _pausePlog() {
    setState(() {
      isPaused = true;
    });
  }

  void _resumePlog() {
    setState(() {
      isPaused = false;
    });
  }

  void _endPlog() {
    _timer?.cancel();
    setState(() {
      isRunning = false;
      isPaused = false;
      seconds = 0;
    });
    // TODO: Firestore에 기록 저장
  }

  String get formattedTime {
    final h = (seconds ~/ 3600).toString().padLeft(1, '0');
    final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Plogging Record', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('Google Map\n(플로깅 경로 표시)', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _InfoColumn(label: 'Distance', value: isRunning ? '-' : '-'),
                _InfoColumn(label: 'Pace', value: isRunning ? '-' : '-'),
                _InfoColumn(label: 'Time', value: isRunning ? formattedTime : '-'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!isRunning)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _startPlog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Start', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                else if (isRunning && !isPaused) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _pausePlog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[400],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('일시정지', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _endPlog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[200],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('끝내기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ] else if (isRunning && isPaused) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _resumePlog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('재시작', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _endPlog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[200],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('끝내기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;
  const _InfoColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 15, color: Colors.grey)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
} 