import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'app_navigation.dart';
import 'firebase_options.dart';
import 'models/jog_record.dart';
import 'screens/home_screen.dart';
import 'screens/plogging_diary_screen.dart';
import 'screens/trash_camera_screen.dart';
import 'screens/jogging_screen.dart';
import 'screens/community_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_provider.dart';
import 'services/badge_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive 초기화
  await Hive.initFlutter();
  Hive.registerAdapter(JogRecordAdapter());
  await Hive.openBox<JogRecord>('jog_records');

  await _initializeFirebase();

  runApp(const PloggingApp());
}

// Android는 google-services.json, 웹은 firebase_options.dart 설정으로 초기화합니다.
// 네이티브 설정을 쓸 수 없는 환경이면 웹 설정으로 한 번 더 시도합니다.
Future<void> _initializeFirebase() async {
  if (Firebase.apps.isNotEmpty) return;
  try {
    await Firebase.initializeApp(options: kIsWeb ? firebaseOptions : null);
  } catch (e) {
    debugPrint('Firebase 기본 설정 초기화 실패, 웹 설정으로 재시도: $e');
    try {
      await Firebase.initializeApp(options: firebaseOptions);
    } catch (e) {
      debugPrint('Firebase 초기화 오류: $e');
    }
  }
}

class PloggingApp extends StatelessWidget {
  const PloggingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BadgeService()..initialize()),
      ],
      child: MaterialApp(
        title: 'Plogging',
        theme: ThemeData(
          primarySwatch: Colors.green,
          scaffoldBackgroundColor: Colors.white,
        ),
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (authProvider.isAuthenticated) {
          return const MainTabNavigator();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class MainTabNavigator extends StatefulWidget {
  const MainTabNavigator({super.key});
  @override
  State<MainTabNavigator> createState() => _MainTabNavigatorState();
}

class _MainTabNavigatorState extends State<MainTabNavigator> {
  int _selectedIndex = 0;
  // 한 번 열어 본 탭만 만들고, 그 뒤로는 상태를 유지합니다.
  // (조깅 중에 쓰레기 탭으로 가서 사진을 찍어도 조깅 기록이 끊기지 않도록)
  final Set<int> _visitedTabs = {0};
  final List<Widget> _screens = const [
    HomeScreen(),
    PloggingDiaryScreen(),
    TrashCameraScreen(),
    JoggingScreen(),
    CommunityScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = tabIndexNotifier.value;
    _visitedTabs.add(_selectedIndex);
    tabIndexNotifier.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    tabIndexNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {
      _selectedIndex = tabIndexNotifier.value;
      _visitedTabs.add(_selectedIndex);
    });
  }

  void _onItemTapped(int index) {
    tabIndexNotifier.value = index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          for (var i = 0; i < _screens.length; i++)
            _visitedTabs.contains(i) ? _screens[i] : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        selectedItemColor: Colors.lightGreen,
        unselectedItemColor: Colors.black,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.delete), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: ''),
        ],
      ),
    );
  }
}
