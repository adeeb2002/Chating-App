import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/Provider/userProvide.dart';
import 'package:provider/Screen/home.dart';
import 'package:provider/Screen/login.dart';
import 'package:provider/serives/notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();

    // ✅ تهيئة إعدادات Firebase Database
    final database = FirebaseDatabase.instance;
    database.setPersistenceEnabled(true);
    database.setPersistenceCacheSizeBytes(10 * 1024 * 1024);

    // تهيئة OneSignal
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose); // هذا السطر سيطبع لك الأخطاء في الـ Terminal
  OneSignal.initialize("666e08c7-44ca-4a94-852c-4e32388a4b43");

  // طلب الإذن (مهم جداً لأندرويد 13+)
  OneSignal.Notifications.requestPermission(true);

    // ✅ تهيئة خدمة الإشعارات
    await NotificationService().initialize();
    
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _isChecking = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final authService = ref.read(authServiceProvider);
    // ✅ استخدام checkLogin هنا
    final isLoggedIn = await authService.checkLogin();

    setState(() {
      _isLoggedIn = isLoggedIn;
      _isChecking = false;
    });

    // إذا كان هناك مستخدم مسجل دخول، جلب بياناته
    if (isLoggedIn) {
      final prefs = await SharedPreferences.getInstance();
      final userEmail = prefs.getString('userEmail');
      if (userEmail != null) {
        final user = await authService.getUserByEmail(userEmail);
        if (user != null && mounted) {
          ref.read(appUserDataProvider.notifier).state = user;
          ref.read(appUserEmailProvider.notifier).state = user.email;
          ref.read(isLoadingProvider.notifier).state = true;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    print(_isLoggedIn.toString());

    return MaterialApp(
      title: 'Chat App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      // ✅ إذا كان مسجل دخول → اذهب للرئيسية، وإلا → اذهب لتسجيل الدخول
      home: _isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
