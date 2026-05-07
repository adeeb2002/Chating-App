import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/Provider/userProvide.dart';
import 'package:provider/Screen/home.dart';
import 'package:provider/Screen/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print('✅ Firebase initialized');
  } catch (e) {
    print('❌ Firebase error: $e');
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
