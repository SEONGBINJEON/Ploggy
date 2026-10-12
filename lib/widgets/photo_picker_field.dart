import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// 글쓰기 화면의 "사진 추가" 버튼. 고른 사진을 미리 보여주고 바이트를 넘겨줍니다.
class PhotoPickerField extends StatelessWidget {
  final Uint8List? imageBytes;
  final ValueChanged<Uint8List?> onChanged;
  final bool enabled;

  const PhotoPickerField({
    super.key,
    required this.imageBytes,
    required this.onChanged,
    this.enabled = true,
  });

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (picked == null) return;
    onChanged(await picked.readAsBytes());
  }

  @override
  Widget build(BuildContext context) {
    final bytes = imageBytes;
    if (bytes == null) {
      return ElevatedButton.icon(
        onPressed: enabled ? _pick : null,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('사진 추가'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.lightGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes, width: double.infinity, height: 180, fit: BoxFit.cover),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: IconButton.filledTonal(
            onPressed: enabled ? () => onChanged(null) : null,
            icon: const Icon(Icons.close),
            tooltip: '사진 빼기',
          ),
        ),
      ],
    );
  }
}
