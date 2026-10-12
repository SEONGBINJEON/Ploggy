import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/community_post.dart';
import '../models/jog_record.dart';
import '../models/user.dart';
import '../services/badge_service.dart';
import '../services/firebase_service.dart';
import '../widgets/badge_unlock_popup.dart';
import 'community_write_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  int _selectedTab = 0; // 0: Rank, 1: Badge, 2: 모아보기

  @override
  void initState() {
    super.initState();
    _checkBadgeConditions();
  }

  Future<void> _checkBadgeConditions() async {
    final newlyUnlocked = await context.read<BadgeService>().checkBadgeConditions();
    if (!mounted) return;
    await showBadgeUnlockPopups(context, newlyUnlocked);
  }

  Future<void> _openWriteScreen() async {
    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CommunityWriteScreen()),
    );
    if (posted != true || !mounted) return;

    final newlyUnlocked = await context.read<BadgeService>().recordCommunityPost();
    if (!mounted) return;
    await showBadgeUnlockPopups(context, newlyUnlocked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Community', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TabButton(
                text: 'Rank',
                selected: _selectedTab == 0,
                onTap: () => setState(() => _selectedTab = 0),
              ),
              const SizedBox(width: 8),
              _TabButton(
                text: 'Badge',
                selected: _selectedTab == 1,
                onTap: () => setState(() => _selectedTab = 1),
              ),
              const SizedBox(width: 8),
              _TabButton(
                text: '모아보기',
                selected: _selectedTab == 2,
                onTap: () => setState(() => _selectedTab = 2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: const [
                _RankTab(),
                _BadgeTab(),
                _FeedTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 2
          ? FloatingActionButton.extended(
              backgroundColor: Colors.lightGreen,
              foregroundColor: Colors.white,
              onPressed: _openWriteScreen,
              icon: const Icon(Icons.edit),
              label: const Text('글쓰기'),
            )
          : null,
    );
  }
}

class _TabButton extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _TabButton({required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.grey[200],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _RankTab extends StatefulWidget {
  const _RankTab();

  @override
  State<_RankTab> createState() => _RankTabState();
}

class _RankTabState extends State<_RankTab> {
  final FirebaseService _firebaseService = FirebaseService();
  late final Stream<List<PloggingUser>> _rankingStream = _firebaseService.rankingStream();

  String _formatTotalTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? '$hours시간 $minutes분' : '$minutes분';
  }

  @override
  Widget build(BuildContext context) {
    final myUid = _firebaseService.currentUser?.uid;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // 내 누적 기록 (기기에 저장된 조깅 기록 기준)
        ValueListenableBuilder(
          valueListenable: Hive.box<JogRecord>('jog_records').listenable(),
          builder: (context, Box<JogRecord> box, _) {
            final totalKm = box.values.fold<double>(0, (sum, r) => sum + r.distanceKm);
            final totalSec = box.values.fold<int>(0, (sum, r) => sum + r.durationSeconds);
            return Row(
              children: [
                Expanded(
                  child: _InfoCard(
                    label: 'Distance',
                    value: '${totalKm.toStringAsFixed(1)} km',
                    sub: '내 누적 거리',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoCard(
                    label: 'Time',
                    value: _formatTotalTime(totalSec),
                    sub: '내 누적 시간',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('누적 거리 순 · 함께 플로깅하는 사람들', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 12),
              StreamBuilder<List<PloggingUser>>(
                stream: _rankingStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('랭킹을 불러오지 못했어요: ${snapshot.error}',
                        style: TextStyle(color: Colors.grey[600]));
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(color: Colors.lightGreen)),
                    );
                  }
                  final rankList = snapshot.data!;
                  if (rankList.isEmpty) {
                    return Text('아직 랭킹 데이터가 없어요. 조깅을 기록하면 랭킹에 올라가요!',
                        style: TextStyle(color: Colors.grey[600]));
                  }
                  return Column(
                    children: List.generate(rankList.length, (i) {
                      return _RankRow(rank: i + 1, user: rankList[i], isMe: rankList[i].id == myUid);
                    }),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final PloggingUser user;
  final bool isMe;
  const _RankRow({required this.rank, required this.user, required this.isMe});

  static const List<Color> _medalColors = [Color(0xFFFFC107), Color(0xFFB0BEC5), Color(0xFFCD7F32)];

  @override
  Widget build(BuildContext context) {
    final initial = user.name.isNotEmpty ? user.name.characters.first : '?';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isMe ? Colors.lightGreen.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '$rank${_rankSuffix(rank)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: rank <= 3 ? _medalColors[rank - 1] : Colors.black87,
              ),
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[300],
            backgroundImage: user.profileImageUrl.isNotEmpty ? NetworkImage(user.profileImageUrl) : null,
            child: user.profileImageUrl.isEmpty
                ? Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isMe ? '${user.name} (나)' : user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('쓰레기 ${user.totalTrash}개 수거', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Text('${user.totalDistance.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

String _rankSuffix(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return 'th';
  if (n % 10 == 1) return 'st';
  if (n % 10 == 2) return 'nd';
  if (n % 10 == 3) return 'rd';
  return 'th';
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  const _InfoCard({required this.label, required this.value, required this.sub});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _BadgeTab extends StatelessWidget {
  const _BadgeTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<BadgeService>(
      builder: (context, badgeService, child) {
        final badges = badgeService.getBadgesWithStatus();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '뱃지 컬렉션',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '플로깅을 통해 다양한 뱃지를 획득해보세요! (${badgeService.unlockedBadges.length}/${badges.length})',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  itemCount: badges.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (context, idx) {
                    final badge = badges[idx];
                    return _BadgeCard(badge: badge);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final Map<String, dynamic> badge;

  const _BadgeCard({required this.badge});

  @override
  Widget build(BuildContext context) {
    final isUnlocked = badge['isUnlocked'] as bool;
    final color = badge['color'] as Color;
    final icon = badge['icon'] as IconData;
    final title = badge['title'] as String;
    final description = badge['description'] as String;

    return GestureDetector(
      onTap: () {
        _showBadgeDetail(context, badge);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 뱃지 아이콘
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isUnlocked ? color.withValues(alpha: 0.1) : Colors.grey[100],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isUnlocked ? color : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isUnlocked ? color : Colors.grey[400],
                    size: 28,
                  ),
                ),
                // 자물쇠 아이콘 (잠금 상태일 때만)
                if (!isUnlocked)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 뱃지 제목
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? Colors.black87 : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // 뱃지 설명
            Text(
              description,
              style: TextStyle(
                fontSize: 10,
                color: isUnlocked ? Colors.grey[600] : Colors.grey[400],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetail(BuildContext context, Map<String, dynamic> badge) {
    final isUnlocked = badge['isUnlocked'] as bool;
    final color = badge['color'] as Color;
    final icon = badge['icon'] as IconData;
    final title = badge['title'] as String;
    final description = badge['description'] as String;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 뱃지 아이콘
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isUnlocked ? color.withValues(alpha: 0.1) : Colors.grey[100],
                shape: BoxShape.circle,
                border: Border.all(
                  color: isUnlocked ? color : Colors.grey[300]!,
                  width: 3,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      icon,
                      color: isUnlocked ? color : Colors.grey[400],
                      size: 40,
                    ),
                  ),
                  if (!isUnlocked)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.grey[600],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 뱃지 제목
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? Colors.black87 : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // 뱃지 설명
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: isUnlocked ? Colors.grey[600] : Colors.grey[400],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // 상태 표시
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isUnlocked ? color.withValues(alpha: 0.1) : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isUnlocked ? '획득 완료!' : '아직 획득하지 못했습니다',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isUnlocked ? color : Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}

class _FeedTab extends StatefulWidget {
  const _FeedTab();

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  late final Stream<List<CommunityPost>> _postsStream = FirebaseService().postsStream();

  // 조깅에 도움이 되는 팁 데이터
  static const List<Map<String, dynamic>> _joggingTips = [
    {
      'title': '처음 조깅을 시작하는 분들을 위한 기본 가이드',
      'content': '초보자를 위한 조깅 가이드',
      'type': 'video',
      'thumbnail': 'https://img.youtube.com/vi/Ggbm_coe5uM/maxresdefault.jpg',
      'videoUrl': 'https://youtu.be/Ggbm_coe5uM?si=hBv0AKpGpJkgyQ9J',
      'duration': '5분',
      'category': 'beginner'
    },
    {
      'title': '조깅할 때 올바른 자세와 호흡법',
      'content': '올바른 자세와 호흡법',
      'type': 'video',
      'thumbnail': 'https://img.youtube.com/vi/Sd4M9hyK1Ss/maxresdefault.jpg',
      'videoUrl': 'https://youtu.be/Sd4M9hyK1Ss?si=BFzGYQSjYhD5eurz',
      'duration': '3분',
      'category': 'technique'
    },
    {
      'title': '조깅할 때 듣기 좋은 음악 추천',
      'content': '조깅할 때 듣기 좋은 음악',
      'type': 'playlist',
      'thumbnail': 'https://img.youtube.com/vi/5svlvTirzpg/maxresdefault.jpg',
      'videoUrl': 'https://youtu.be/5svlvTirzpg?si=G5BNG6zFjVfAdz3r',
      'duration': '60분',
      'category': 'motivation'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // 조깅 팁 섹션
        _FeedSectionTitle(icon: Icons.lightbulb, title: '조깅 팁', color: Colors.orange[600]!),
        // 조깅 팁 가로 스크롤
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _joggingTips.length,
            itemBuilder: (context, idx) {
              final tip = _joggingTips[idx];
              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: 16),
                child: _JoggingTipCard(tip: tip),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // 커뮤니티 글
        _FeedSectionTitle(icon: Icons.forum, title: '커뮤니티 글', color: Colors.teal[600]!),
        StreamBuilder<List<CommunityPost>>(
          stream: _postsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _FeedMessage(text: '글을 불러오지 못했어요: ${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(color: Colors.lightGreen)),
              );
            }
            final posts = snapshot.data!;
            if (posts.isEmpty) {
              return const _FeedMessage(text: '아직 글이 없어요. 오른쪽 아래 글쓰기 버튼으로 첫 글을 남겨보세요!');
            }
            return Column(children: posts.map((post) => _PostCard(post: post)).toList());
          },
        ),
        const SizedBox(height: 16),
        // 내 조깅 기록 (이 기기에 저장된 기록)
        _FeedSectionTitle(icon: Icons.history, title: '내 조깅 기록', color: Colors.green[600]!),
        const _JoggingHistoryList(),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _FeedSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _FeedSectionTitle({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedMessage extends StatelessWidget {
  final String text;
  const _FeedMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
    );
  }
}

class _PostCard extends StatelessWidget {
  final CommunityPost post;
  const _PostCard({required this.post});

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.lightGreen,
                  child: Text(
                    post.authorName.isNotEmpty ? post.authorName.characters.first : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text(_formatDate(post.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 10),
            Text(post.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(post.content, style: const TextStyle(fontSize: 14, height: 1.4)),
            if (post.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  post.imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _JoggingHistoryList extends StatelessWidget {
  const _JoggingHistoryList();

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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<JogRecord>('jog_records').listenable(),
      builder: (context, Box<JogRecord> box, _) {
        final records = box.values.toList().reversed.toList();

        if (records.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(
                  Icons.directions_run,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  '아직 조깅 기록이 없습니다',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '조깅을 시작하여 기록을 남겨보세요!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: records.map((record) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // 날짜 표시
                    Container(
                      width: 60,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(
                            record.date.month.toString().padLeft(2, '0'), // 월
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            record.date.day.toString().padLeft(2, '0'), // 일
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 기록 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.directions_run,
                                size: 16,
                                color: Colors.green[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '조깅 기록',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildInfoItem('거리', '${record.distanceKm.toStringAsFixed(1)}km'),
                              const SizedBox(width: 16),
                              _buildInfoItem('시간', _formatDuration(record.durationSeconds)),
                              const SizedBox(width: 16),
                              _buildInfoItem('속도', '${record.speedKmph.toStringAsFixed(1)}km/h'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 공유 버튼
                    IconButton(
                      onPressed: () => Share.share(record.toShareText()),
                      tooltip: '공유',
                      icon: Icon(
                        Icons.share,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _JoggingTipCard extends StatelessWidget {
  final Map<String, dynamic> tip;

  const _JoggingTipCard({required this.tip});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _showTipDetail(context, tip);
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 썸네일 이미지
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                ),
                child: Stack(
                  children: [
                    Image.network(
                      tip['thumbnail'],
                      width: double.infinity,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: Icon(
                            tip['type'] == 'video' ? Icons.play_circle : Icons.article,
                            size: 48,
                            color: Colors.grey[600],
                          ),
                        );
                      },
                    ),
                    // 타입 아이콘
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              tip['type'] == 'video' ? Icons.play_arrow :
                              tip['type'] == 'playlist' ? Icons.music_note : Icons.article,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              tip['duration'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 내용
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip['title'],
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tip['content'],
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTipDetail(BuildContext context, Map<String, dynamic> tip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TipDetailSheet(tip: tip),
    );
  }
}

class _TipDetailSheet extends StatelessWidget {
  final Map<String, dynamic> tip;

  const _TipDetailSheet({required this.tip});

  Future<void> _launchUrl(BuildContext context, String url) async {
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('링크 열기 실패: $e');
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영상을 열 수 없습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 핸들바
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 헤더
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  tip['type'] == 'video' ? Icons.play_circle :
                  tip['type'] == 'playlist' ? Icons.music_note : Icons.article,
                  color: Colors.green,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tip['title'],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 썸네일
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                tip['thumbnail'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Icon(
                      tip['type'] == 'video' ? Icons.play_circle : Icons.article,
                      size: 64,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
            ),
          ),
          // 내용
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip['content'],
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (tip['videoUrl'].isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _launchUrl(context, tip['videoUrl']);
                        },
                        icon: Icon(
                          tip['type'] == 'video' ? Icons.play_arrow :
                          tip['type'] == 'playlist' ? Icons.music_note : Icons.open_in_new,
                        ),
                        label: Text(
                          tip['type'] == 'video' ? '영상 보기' :
                          tip['type'] == 'playlist' ? '플레이리스트 듣기' : '자세히 보기',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
