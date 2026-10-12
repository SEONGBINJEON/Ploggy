import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
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

final ValueNotifier<int> tabIndexNotifier = ValueNotifier<int>(0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Hive 초기화
  await Hive.initFlutter();
  Hive.registerAdapter(JogRecordAdapter());
  await Hive.openBox<JogRecord>('jog_records');
  
  // Firebase 초기화 - 중복 방지
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: firebaseOptions);
      print('Firebase 초기화 성공');
    } else {
      print('Firebase가 이미 초기화되어 있습니다.');
    }
  } catch (e) {
    print('Firebase 초기화 오류: $e');
    // 기존 앱이 있으면 그것을 사용
    if (Firebase.apps.isNotEmpty) {
      print('기존 Firebase 앱을 사용합니다.');
    }
  }
  
  runApp(const PloggingApp());
}

class PloggingApp extends StatelessWidget {
  const PloggingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BadgeService()),
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
  const AuthWrapper({Key? key}) : super(key: key);

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
  const MainTabNavigator({Key? key}) : super(key: key);
  @override
  State<MainTabNavigator> createState() => _MainTabNavigatorState();
}

class _MainTabNavigatorState extends State<MainTabNavigator> {
  int _selectedIndex = 0;
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
    });
  }

  void _onItemTapped(int index) {
    tabIndexNotifier.value = index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
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
