import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/user.dart';

// ✅ إعادة تسمية الـ Providers بشكل واضح
final appUserDataProvider = StateProvider<AppUser?>((ref) => null);
final appUserEmailProvider = StateProvider<String?>((ref) => null);
final isLoadingProvider = StateProvider<bool>((ref) => false);
final isLoginProvider = StateProvider<bool>((ref) => false);
final currentReceiverProvider = StateProvider<AppUser?>((ref) => null);

// ✅ authServiceProvider
final authServiceProvider = Provider<AuthService>((ref) {
  final db = FirebaseDatabase.instance;
  return AuthService(db);
});

// Stream Provider للمستخدم
final currentUserStreamProvider = StreamProvider<AppUser?>((ref) {
  final service = ref.watch(authServiceProvider);
  return service.watchCurrentUser();
});

// Provider لجلب بيانات مستخدم
final userDataProvider = FutureProvider.family<AppUser?, String>((ref, email) async {
  final service = ref.watch(authServiceProvider);
  return await service.getUserByEmail(email);
});

class AuthService {
  final FirebaseDatabase db;
  String? _currentUserId;

  AuthService(this.db);

  Stream<AppUser?> watchCurrentUser() {
    // مراقبة التغييرات في المستخدم الحالي
    // يمكن توسيع هذا لمراقبة حالة المصادقة الفعلية
    return Stream.periodic(const Duration(seconds: 2), (_) async {
      final isLoggedIn = await checkLogin();
      if (isLoggedIn == true && _currentUserId != null) {
        return await getUserById(_currentUserId!);
      }
      return null;
    }).asyncMap((event) => event);
  }

  // ✅ تسجيل الدخول
  Future<AppUser?> login(String email, String password, BuildContext context) async {
    try {
      final snapshot = await db
          .ref('users')
          .orderByChild('email')
          .equalTo(email)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        if (data.isNotEmpty) {
          final entry = data.entries.first;
          final userId = entry.key.toString();
          final userData = Map<String, dynamic>.from(entry.value);

          // التحقق من كلمة المرور
          if (userData['password'] == password) {
            final user = AppUser(
              id: userId,
              email: email,
              name: userData['name'] ?? email.split('@')[0],
              imageUrl: userData['imageUrl'],
              isOnline: true,
              lastSeen: DateTime.now().millisecondsSinceEpoch,
            );

            _currentUserId = userId;
            await updateUserStatus(userId, true);
            await _saveLoginState(true, user);

            return user;
          } else {
            throw Exception('كلمة المرور غير صحيحة');
          }
        }
      }

      // إذا لم يوجد المستخدم، قم بإنشاء حساب جديد
      return await register(email, password, context);
      
    } catch (e) {
      print('❌ خطأ في تسجيل الدخول: $e');
      return null;
    }
  }

  // ✅ تسجيل حساب جديد
  Future<AppUser?> register(String email, String password, BuildContext context) async {
    try {
      // التحقق من عدم وجود المستخدم مسبقاً
      final existingUser = await getUserByEmail(email);
      if (existingUser != null) {
        throw Exception('البريد الإلكتروني مسجل مسبقاً');
      }

      final newUserRef = db.ref('users').push();
      final name = email.split('@')[0];

      final newUser = AppUser(
        id: newUserRef.key,
        email: email,
        name: name,
        isOnline: true,
        lastSeen: DateTime.now().millisecondsSinceEpoch,
        password: password,
      );

      await newUserRef.set(newUser.toMap());
      _currentUserId = newUserRef.key;
      await _saveLoginState(true, newUser);

      return newUser;
      
    } catch (e) {
      print('❌ خطأ في التسجيل: $e');
      return null;
    }
  }

  // ✅ حفظ حالة تسجيل الدخول
  Future<void> _saveLoginState(bool isLogin, AppUser? user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLogin', isLogin);
    if (user != null) {
      await prefs.setString('userEmail', user.email);
      await prefs.setString('userId', user.id ?? '');
      await prefs.setString('userName', user.name);
    }
  }

  // ✅ تسجيل الخروج
  Future<void> logout() async {
    if (_currentUserId != null) {
      await updateUserStatus(_currentUserId!, false);
    }
    
    // مسح بيانات الجلسة
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLogin');
    await prefs.remove('userEmail');
    await prefs.remove('userId');
    await prefs.remove('userName');
    
    _currentUserId = null;
    print('✅ تم تسجيل الخروج بنجاح');
  }

  // ✅ تحديث حالة المستخدم (متصل/غير متصل)
  Future<void> updateUserStatus(String userId, bool isOnline) async {
    try {
      await db.ref('users').child(userId).update({
        'isOnline': isOnline,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      });
      
      print('✅ تم تحديث حالة المستخدم: $isOnline');
      
    } catch (e) {
      print('❌ خطأ في تحديث الحالة: $e');
    }
  }

  // ✅ التحقق من حالة تسجيل الدخول
  Future<bool> checkLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLogin = prefs.getBool('isLogin') ?? false;
      
      // إذا كان هناك جلسة نشطة، تحقق من صحة المستخدم
      if (isLogin) {
        final userEmail = prefs.getString('userEmail');
        if (userEmail != null) {
          final user = await getUserByEmail(userEmail);
          return user != null;
        }
      }
      
      return false;
      
    } catch (e) {
      print('❌ خطأ في التحقق من تسجيل الدخول: $e');
      return false;
    }
  }

  // ✅ جلب مستخدم عن طريق البريد الإلكتروني
  Future<AppUser?> getUserByEmail(String email) async {
    if (email.isEmpty) return null;
    
    try {
      final snapshot = await db
          .ref('users')
          .orderByChild('email')
          .equalTo(email)
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        if (data.isNotEmpty) {
          final entry = data.entries.first;
          return AppUser.fromMap(entry.key.toString(), Map.from(entry.value));
        }
      }
      return null;
      
    } catch (e) {
      print('❌ خطأ في جلب المستخدم: $e');
      return null;
    }
  }

  // ✅ جلب مستخدم عن طريق ID
  Future<AppUser?> getUserById(String userId) async {
    if (userId.isEmpty) return null;
    
    try {
      final snapshot = await db.ref('users').child(userId).get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return AppUser.fromMap(userId, data);
      }
      return null;
      
    } catch (e) {
      print('❌ خطأ في جلب المستخدم بالـ ID: $e');
      return null;
    }
  }

  // ✅ تحديث بيانات المستخدم
  Future<void> updateUserProfile(String userId, {
    String? name,
    String? imageUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (imageUrl != null) updates['imageUrl'] = imageUrl;
      updates['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
      
      await db.ref('users').child(userId).update(updates);
      print('✅ تم تحديث بيانات المستخدم');
      
    } catch (e) {
      print('❌ خطأ في تحديث بيانات المستخدم: $e');
      rethrow;
    }
  }

  // ✅ تغيير كلمة المرور
  Future<bool> changePassword(String userId, String oldPassword, String newPassword) async {
    try {
      final snapshot = await db.ref('users').child(userId).get();
      
      if (!snapshot.exists) {
        throw Exception('المستخدم غير موجود');
      }
      
      final userData = Map<String, dynamic>.from(snapshot.value as Map);
      
      if (userData['password'] != oldPassword) {
        throw Exception('كلمة المرور القديمة غير صحيحة');
      }
      
      await db.ref('users').child(userId).update({
        'password': newPassword,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      
      print('✅ تم تغيير كلمة المرور بنجاح');
      return true;
      
    } catch (e) {
      print('❌ خطأ في تغيير كلمة المرور: $e');
      return false;
    }
  }

  // ✅ حذف حساب المستخدم
  Future<bool> deleteAccount(String userId) async {
    try {
      // حذف جميع محادثات المستخدم
      final chatsSnapshot = await db.ref('chats').get();
      if (chatsSnapshot.exists) {
        final chats = chatsSnapshot.value as Map<dynamic, dynamic>? ?? {};
        
        for (var chatEntry in chats.entries) {
          final chatId = chatEntry.key.toString();
          final chatData = Map<String, dynamic>.from(chatEntry.value);
          final participants = List<String>.from(chatData['participants'] ?? []);
          
          if (participants.contains(userId)) {
            // إما حذف المحادثة أو إزالة المستخدم منها
            await db.ref('chats').child(chatId).update({
              'deletedFor': {
                ...Map<String, dynamic>.from(chatData['deletedFor'] ?? {}),
                userId: DateTime.now().millisecondsSinceEpoch,
              }
            });
          }
        }
      }
      
      // حذف المستخدم
      await db.ref('users').child(userId).remove();
      
      // مسح الجلسة
      await logout();
      
      print('✅ تم حذف الحساب بنجاح');
      return true;
      
    } catch (e) {
      print('❌ خطأ في حذف الحساب: $e');
      return false;
    }
  }
}

// ✅ Provider مساعد لمراقبة حالة تسجيل الدخول
final authStateProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(authServiceProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) async {
    return await service.checkLogin();
  }).asyncMap((event) => event);
});

// ✅ Provider للحصول على المستخدم الحالي من SharedPreferences
final cachedUserProvider = FutureProvider<AppUser?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final userEmail = prefs.getString('userEmail');
  final userId = prefs.getString('userId');
  final userName = prefs.getString('userName');
  
  if (userEmail != null && userId != null) {
    return AppUser(
      id: userId,
      email: userEmail,
      name: userName ?? userEmail.split('@')[0],
      isOnline: true,
      lastSeen: DateTime.now().millisecondsSinceEpoch,
    );
  }
  
  return null;
});