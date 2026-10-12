import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/community_post.dart';
import '../services/firebase_service.dart';
import '../widgets/photo_picker_field.dart';

class CommunityWriteScreen extends StatefulWidget {
  const CommunityWriteScreen({super.key});

  @override
  State<CommunityWriteScreen> createState() => _CommunityWriteScreenState();
}

class _CommunityWriteScreenState extends State<CommunityWriteScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseService _firebaseService = FirebaseService();
  String? _title, _content;
  Uint8List? _imageBytes;
  bool _isSaving = false;

  Future<void> _savePost() async {
    final user = _firebaseService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    setState(() { _isSaving = true; });
    try {
      // 사진 업로드에 실패해도 글은 올립니다.
      final imageBytes = _imageBytes;
      final imageUrl = imageBytes == null
          ? ''
          : await _firebaseService.tryUploadSharedImage(imageBytes, 'community_images') ?? '';
      final photoFailed = imageBytes != null && imageUrl.isEmpty;

      final displayName = user.displayName ?? '';
      final synced = await _firebaseService.createPost(CommunityPost(
        userId: user.uid,
        authorName: displayName.isNotEmpty ? displayName : '플로거',
        title: _title!.trim(),
        content: _content!.trim(),
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
      ));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text([
            synced ? '글이 등록되었습니다!' : '오프라인이라 기기에 먼저 저장했어요. 연결되면 자동으로 올라가요.',
            if (photoFailed) '사진은 올리지 못해서 글만 등록했어요.',
          ].join('\n')),
        ),
      );
      // true를 돌려주면 커뮤니티 화면에서 글 작성 뱃지를 확인합니다.
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() { _isSaving = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('글 저장 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('커뮤니티 글쓰기', style: TextStyle(color: Colors.black)),
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
              TextFormField(
                decoration: const InputDecoration(labelText: '내용', fillColor: Colors.white, filled: true),
                maxLines: 6,
                onSaved: (v) => _content = v,
                validator: (v) => v == null || v.trim().isEmpty ? '내용을 입력하세요' : null,
              ),
              const SizedBox(height: 16),
              PhotoPickerField(
                imageBytes: _imageBytes,
                enabled: !_isSaving,
                onChanged: (bytes) => setState(() => _imageBytes = bytes),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () async {
                    if (_formKey.currentState?.validate() ?? false) {
                      _formKey.currentState?.save();
                      await _savePost();
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
