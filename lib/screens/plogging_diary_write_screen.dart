import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PloggingDiaryWriteScreen extends StatefulWidget {
  const PloggingDiaryWriteScreen({Key? key}) : super(key: key);

  @override
  State<PloggingDiaryWriteScreen> createState() => _PloggingDiaryWriteScreenState();
}

class _PloggingDiaryWriteScreenState extends State<PloggingDiaryWriteScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _title, _distance, _time, _steps, _memo;
  bool _isSaving = false;

  Future<void> _saveDiary() async {
    setState(() { _isSaving = true; });
    await FirebaseFirestore.instance.collection('plogging_diary').add({
      'title': _title,
      'distance': _distance,
      'time': _time,
      'steps': _steps,
      'memo': _memo,
      'createdAt': FieldValue.serverTimestamp(),
    });
    setState(() { _isSaving = false; });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('플로깅 기록 작성', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0.5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: '제목', fillColor: Colors.white, filled: true),
                onSaved: (v) => _title = v,
                validator: (v) => v == null || v.isEmpty ? '제목을 입력하세요' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('사진 추가'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: '거리 (km)', fillColor: Colors.white, filled: true),
                keyboardType: TextInputType.number,
                onSaved: (v) => _distance = v,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: '시간 (예: 1h 10m)', fillColor: Colors.white, filled: true),
                onSaved: (v) => _time = v,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: '스텝 수', fillColor: Colors.white, filled: true),
                keyboardType: TextInputType.number,
                onSaved: (v) => _steps = v,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: '메모', fillColor: Colors.white, filled: true),
                maxLines: 3,
                onSaved: (v) => _memo = v,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () async {
                    if (_formKey.currentState?.validate() ?? false) {
                      _formKey.currentState?.save();
                      await _saveDiary();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('저장', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 