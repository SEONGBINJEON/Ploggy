import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/diary_entry.dart';
import '../services/firebase_service.dart';
import '../widgets/photo_picker_field.dart';

class PloggingDiaryWriteScreen extends StatefulWidget {
  const PloggingDiaryWriteScreen({super.key});

  @override
  State<PloggingDiaryWriteScreen> createState() => _PloggingDiaryWriteScreenState();
}

class _PloggingDiaryWriteScreenState extends State<PloggingDiaryWriteScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();
  String? _title, _distance, _time, _steps, _memo;
  Uint8List? _imageBytes;
  bool _isSaving = false;

  Future<void> _saveDiary() async {
    final user = _firebaseService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() { _isSaving = true; });
    try {
      // 사진 업로드에 실패해도 일기는 저장합니다.
      final imageBytes = _imageBytes;
      final imageUrl = imageBytes == null
          ? ''
          : await _firebaseService.tryUploadSharedImage(imageBytes, 'diary_images') ?? '';
      final photoFailed = imageBytes != null && imageUrl.isEmpty;

      final synced = await _firebaseService.saveDiaryEntry(DiaryEntry(
        userId: user.uid,
        title: _title!.trim(),
        distanceKm: double.tryParse(_distance?.trim() ?? ''),
        time: _time?.trim() ?? '',
        steps: int.tryParse(_steps?.trim() ?? ''),
        memo: _memo?.trim() ?? '',
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
      ));
      if (!mounted) return;
      final notices = [
        if (!synced) '오프라인이라 기기에 먼저 저장했어요. 연결되면 자동으로 올라가요.',
        if (photoFailed) '사진은 올리지 못해서 일기만 저장했어요.',
      ];
      if (notices.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(notices.join('\n'))),
        );
      }
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() { _isSaving = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  String? _validateNumber(String? value, {bool integer = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final ok = integer ? int.tryParse(text) != null : double.tryParse(text) != null;
    return ok ? null : '숫자로 입력해주세요';
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
                validator: (v) => v == null || v.trim().isEmpty ? '제목을 입력하세요' : null,
              ),
              const SizedBox(height: 16),
              PhotoPickerField(
                imageBytes: _imageBytes,
                enabled: !_isSaving,
                onChanged: (bytes) => setState(() => _imageBytes = bytes),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: '거리 (km)', fillColor: Colors.white, filled: true),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onSaved: (v) => _distance = v,
                validator: (v) => _validateNumber(v),
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
                validator: (v) => _validateNumber(v, integer: true),
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
