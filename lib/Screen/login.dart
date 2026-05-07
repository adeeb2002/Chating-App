import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/Provider/userProvide.dart';
import 'package:provider/Screen/home.dart';
import 'package:provider/model/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isRegistering = false; // ✅ لمتابعة حالة التسجيل

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ✅ دالة حفظ الجلسة الموحدة
  Future<void> _saveUserSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLogin', true);
    await prefs.setString('userEmail', user.email);
    await prefs.setString('userId', user.id ?? '');
    await prefs.setString('userName', user.name);
    
    // تحديث الـ Providers
    ref.read(appUserDataProvider.notifier).state = user;
    ref.read(appUserEmailProvider.notifier).state = user.email;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
        context,
      );

      if (user != null && mounted) {
        // ✅ حفظ الجلسة
        await _saveUserSession(user);
        
        // ✅ التحقق من نجاح تسجيل الدخول
        final isLoggedIn = await authService.checkLogin();
        
        if (isLoggedIn && mounted) {
          _showSnackBar('تم تسجيل الدخول بنجاح', isError: false);
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          _showSnackBar('فشل تسجيل الدخول. تحقق من بياناتك');
        }
      } else {
        _showSnackBar('فشل تسجيل الدخول. تحقق من بياناتك');
      }
    } catch (e) {
      _showSnackBar('حدث خطأ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ✅ دالة التسجيل المحسنة
  Future<void> _handleRegister(String name, String email, String password) async {
    setState(() => _isRegistering = true);

    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.register(email, password, context);

      if (user != null && mounted) {
        // تحديث الاسم إذا تم إدخاله
        if (name.isNotEmpty) {
          await FirebaseDatabase.instance
              .ref('users')
              .child(user.id!)
              .update({'name': name.trim()});

          final updatedUser = AppUser(
            id: user.id,
            email: user.email,
            name: name.trim(),
            isOnline: true,
            lastSeen: DateTime.now().millisecondsSinceEpoch,
          );
          await _saveUserSession(updatedUser);
        } else {
          await _saveUserSession(user);
        }

        // ✅ التحقق من نجاح التسجيل
        final isLoggedIn = await authService.checkLogin();

        if (isLoggedIn && mounted) {
          _showSnackBar('تم إنشاء الحساب بنجاح', isError: false);
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        _showSnackBar('فشل إنشاء الحساب. حاول مرة أخرى');
      }
    } catch (e) {
      _showSnackBar('حدث خطأ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  // ✅ نافذة التسجيل المحسنة
  void _showRegisterDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passController = TextEditingController();
    final confirmPassController = TextEditingController(); // ✅ تأكيد كلمة المرور
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: !_isRegistering,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إنشاء حساب جديد'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم',
                  hintText: 'أدخل اسمك',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال الاسم';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  hintText: 'example@email.com',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال البريد الإلكتروني';
                  }
                  if (!value.contains('@')) {
                    return 'البريد الإلكتروني غير صالح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: passController,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  hintText: '********',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال كلمة المرور';
                  }
                  if (value.length < 6) {
                    return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: confirmPassController,
                decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  hintText: '********',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء تأكيد كلمة المرور';
                  }
                  if (value != passController.text) {
                    return 'كلمة المرور غير متطابقة';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isRegistering ? null : () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _isRegistering
                ? null
                : () {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(dialogContext);
                      _handleRegister(
                        nameController.text.trim(),
                        emailController.text.trim(),
                        passController.text.trim(),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: _isRegistering
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('إنشاء حساب'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF4CAF50), Color(0xFF2196F3)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // الشعار
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble,
                            size: 50,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'مرحباً بك في تطبيق المحادثات',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'سجل الدخول للاستمرار',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 30),

                        // حقل البريد الإلكتروني
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'البريد الإلكتروني',
                            hintText: 'example@email.com',
                            prefixIcon: const Icon(
                              Icons.email,
                              color: Colors.green,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(
                                color: Colors.green,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'الرجاء إدخال البريد الإلكتروني';
                            }
                            if (!value.contains('@')) {
                              return 'البريد الإلكتروني غير صالح';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // حقل كلمة المرور
                        TextFormField(
                          controller: passwordController,
                          obscureText: _obscurePassword,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'كلمة المرور',
                            hintText: '********',
                            prefixIcon: const Icon(
                              Icons.lock,
                              color: Colors.green,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(
                                color: Colors.green,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'الرجاء إدخال كلمة المرور';
                            }
                            if (value.length < 6) {
                              return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),

                        // نسيت كلمة المرور
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    _showSnackBar(
                                      'سيتم إرسال رابط إعادة تعيين كلمة المرور',
                                    );
                                  },
                            child: const Text('نسيت كلمة المرور؟'),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // زر تسجيل الدخول
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'تسجيل الدخول',
                                    style: TextStyle(fontSize: 18),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // نص تسجيل حساب جديد
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('ليس لديك حساب؟'),
                            TextButton(
                              onPressed: _isLoading ? null : _showRegisterDialog,
                              child: const Text(
                                'إنشاء حساب جديد',
                                style: TextStyle(color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}