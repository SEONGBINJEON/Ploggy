import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/badge_service.dart';

/// 새로 얻은 뱃지를 하나씩 차례로 축하 팝업으로 보여줍니다.
Future<void> showBadgeUnlockPopups(BuildContext context, List<String> badgeIds) async {
  if (badgeIds.isEmpty) return;
  final badgeService = context.read<BadgeService>();
  for (final badgeId in badgeIds) {
    if (!context.mounted) return;
    final badge = badgeService.badges.firstWhere((b) => b['id'] == badgeId);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BadgeUnlockPopup(
        badge: badge,
        onClose: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }
  badgeService.clearNewlyUnlockedBadge();
}

class BadgeUnlockPopup extends StatelessWidget {
  final Map<String, dynamic> badge;
  final VoidCallback onClose;

  const BadgeUnlockPopup({
    super.key,
    required this.badge,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final color = badge['color'] as Color;
    final icon = badge['icon'] as IconData;
    final title = badge['title'] as String;
    final description = badge['description'] as String;

    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 축하 아이콘
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 3),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),

              // 축하 메시지
              Text(
                '🎉 축하합니다! 🎉',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // 뱃지 제목
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // 뱃지 설명
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // 확인 버튼
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onClose,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
