import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import '../model/chat.dart';
import '../model/massege.dart';

// Provider لقاعدة البيانات
final firebaseDatabaseProvider = Provider<FirebaseDatabase>((ref) {
  return FirebaseDatabase.instance;
});

// Provider لخدمة المحادثات
final chatServiceProvider = Provider<ChatService>((ref) {
  final db = ref.watch(firebaseDatabaseProvider);
  return ChatService(db);
});

// Stream Provider للمحادثات
final chatsProvider = StreamProvider.family<List<Chat>, String>((ref, userEmail) {
  final db = ref.watch(firebaseDatabaseProvider);

  return db.ref('chats').onValue.map((event) {
    final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
    final List<Chat> chats = [];

    data.forEach((chatId, chatData) {
      final chatMap = Map<String, dynamic>.from(chatData);
      final participants = List<String>.from(chatMap['participants'] ?? []);
      final deletedFor = Map<String, dynamic>.from(chatMap['deletedFor'] ?? {});

      if (participants.contains(userEmail) && !deletedFor.containsKey(userEmail)) {
        chats.add(Chat(
          id: chatId.toString(),
          participants: participants,
          lastMessage: chatMap['lastMessage'] ?? '',
          lastMessageTime: chatMap['lastMessageTime'] ?? 0,
          lastMessageSender: chatMap['lastMessageSender'] ?? '',
          createdAt: chatMap['createdAt'] ?? 0,
          updatedAt: chatMap['updatedAt'] ?? 0,
          deletedFor: deletedFor,
          isDeletedChatForYou: chatMap['isDeletedChatForYou'] ?? false
          ),
        );
      }
    });

    // ترتيب حسب آخر تحديث
    chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return chats;
  });
});

class ChatService {
  final FirebaseDatabase db;

  ChatService(this.db);

  // دالة لتنظيف البريد الإلكتروني من الأحرف غير المسموحة
  String _cleanEmail(String email) {
    return email
        .replaceAll('@', '_at_')
        .replaceAll('.', '_dot_')
        .replaceAll('#', '_hash_')
        .replaceAll('\$', '_dollar_')
        .replaceAll('[', '_lb_')
        .replaceAll(']', '_rb_')
        .replaceAll('/', '_slash_')
        .replaceAll('\\', '_bslash_');
  }

  // إنشاء معرف محادثة فريد وآمن
  String _generateChatId(String email1, String email2) {
    final List<String> emails = [email1, email2]..sort();
    final String clean1 = _cleanEmail(emails[0]);
    final String clean2 = _cleanEmail(emails[1]);
    return '${clean1}_$clean2';
  }

  // إنشاء محادثة جديدة
  Future<String> createChat({
    required String user1Email,
    required String user2Email,
    String? initialMessage,
  }) async {
    try {
      if (user1Email.isEmpty || user2Email.isEmpty) {
        throw Exception('البريد الإلكتروني لا يمكن أن يكون فارغاً');
      }

      final chatId = _generateChatId(user1Email, user2Email);
      final chatRef = db.ref('chats').child(chatId);
      final snapshot = await chatRef.get();
      
      if (snapshot.exists) {
        print('✅ المحادثة موجودة مسبقاً: $chatId');
        return chatId;
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      await chatRef.set({
        'participants': [user1Email, user2Email],
        'createdAt': now,
        'updatedAt': now,
        'lastMessage': initialMessage ?? '',
        'lastMessageTime': now,
        'lastMessageSender': user1Email,
        'deletedFor': {},
        'clearedFor': {},
      });

      print('✅ تم إنشاء المحادثة بنجاح: $chatId');

      if (initialMessage != null && initialMessage.isNotEmpty) {
        final messageService = MessageService(db);
        final message = Massege.create(
          senderUser: user1Email,
          resevUser: user2Email,
          body: initialMessage,
          chatId: chatId,
        );
        await messageService.sendMessage(message);
      }

      return chatId;
    } catch (e) {
      print('❌ خطأ في إنشاء المحادثة: $e');
      throw Exception('فشل إنشاء المحادثة: ${e.toString()}');
    }
  }

  // ✅ مسح جميع رسائل المحادثة (مع الاحتفاظ بالمحادثة)
  Future<void> clearChat(String chatId) async {
    try {
      final chatRef = db.ref('chats').child(chatId);
      final snapshot = await chatRef.get();

      if (!snapshot.exists) {
        throw Exception('المحادثة غير موجودة');
      }

      // حذف جميع الرسائل
      final messagesRef = chatRef.child('messages');
      await messagesRef.remove();

      // تحديث بيانات المحادثة الرئيسية
      final now = DateTime.now().millisecondsSinceEpoch;
      await chatRef.update({
        'lastMessage': '',
        'lastMessageTime': now,
        'lastMessageSender': '',
        'lastMessageId': '',
        'updatedAt': now,
        'clearedAt': now,
      });

      print('✅ تم مسح جميع رسائل المحادثة: $chatId');
    } catch (e) {
      print('❌ خطأ في مسح رسائل المحادثة: $e');
      rethrow;
    }
  }

  // ✅ مسح رسائل المحادثة لمستخدم معين فقط
  Future<void> clearChatForUser(String chatId, String userId) async {
    try {
      final chatRef = db.ref('chats').child(chatId);
      final snapshot = await chatRef.get();

      if (!snapshot.exists) {
        throw Exception('المحادثة غير موجودة');
      }

      final chatData = snapshot.value as Map<dynamic, dynamic>?;
      if (chatData == null) {
        throw Exception('بيانات المحادثة غير صالحة');
      }

      final clearedFor = Map<String, dynamic>.from(chatData['clearedFor'] ?? {});
      clearedFor[userId] = DateTime.now().millisecondsSinceEpoch;

      await chatRef.update({
        'clearedFor': clearedFor,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      print('✅ تم مسح رسائل المحادثة للمستخدم $userId');
    } catch (e) {
      print('❌ خطأ في مسح رسائل المحادثة للمستخدم: $e');
      rethrow;
    }
  }

  // ✅ حذف محادثة لمستخدم معين (إخفاء المحادثة من المستخدم)
  Future<void> deleteChatForUser(String chatId, String userId) async {
    try {
      final chatRef = db.ref('chats').child(chatId);
      final snapshot = await chatRef.get();

      if (!snapshot.exists) {
        throw Exception('المحادثة غير موجودة');
      }

      final chatData = snapshot.value as Map<dynamic, dynamic>?;
      if (chatData == null) {
        throw Exception('بيانات المحادثة غير صالحة');
      }

      final deletedFor = Map<String, dynamic>.from(chatData['deletedFor'] ?? {});
      deletedFor[userId] = DateTime.now().millisecondsSinceEpoch;

      await chatRef.update({
        'deletedFor': deletedFor,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });

      print('✅ تم حذف المحادثة للمستخدم $userId');
    } catch (e) {
      print('❌ خطأ في حذف المحادثة للمستخدم: $e');
      rethrow;
    }
  }

  // ✅ حذف المحادثة بالكامل من قاعدة البيانات (للمسؤول فقط)
  Future<void> deleteChatComplete(String chatId) async {
    try {
      final chatRef = db.ref('chats').child(chatId);
      final snapshot = await chatRef.get();

      if (!snapshot.exists) {
        throw Exception('المحادثة غير موجودة');
      }

      await chatRef.remove();
      print('✅ تم حذف المحادثة بالكامل: $chatId');
    } catch (e) {
      print('❌ خطأ في حذف المحادثة بالكامل: $e');
      rethrow;
    }
  }

  // ✅ دالة موحدة لحذف المحادثة (مصححة)
  Future<void> deleteChat(String chatId, {bool forEveryone = false}) async {
    try {
      if (chatId.isEmpty) {
        throw Exception('معرف المحادثة لا يمكن أن يكون فارغاً');
      }

      if (forEveryone) {
        await deleteChatComplete(chatId);
      } else {
        // يتم تمرير userId من الخارج
        print('⚠️ يرجى استخدام deleteChatForUser بدلاً من هذه الدالة');
        throw Exception('يرجى تحديد userId للمستخدم');
      }
    } catch (e) {
      print('❌ خطأ في حذف المحادثة: $e');
      rethrow;
    }
  }

  // ✅ استعادة محادثة محذوفة لمستخدم معين
  Future<void> restoreDeletedChat(String chatId, String userId) async {
    try {
      final chatRef = db.ref('chats').child(chatId);
      final snapshot = await chatRef.get();

      if (!snapshot.exists) {
        throw Exception('المحادثة غير موجودة');
      }

      final chatData = snapshot.value as Map<dynamic, dynamic>?;
      if (chatData == null) {
        throw Exception('بيانات المحادثة غير صالحة');
      }

      final deletedFor = Map<String, dynamic>.from(chatData['deletedFor'] ?? {});
      
      if (deletedFor.containsKey(userId)) {
        deletedFor.remove(userId);
        await chatRef.update({
          'deletedFor': deletedFor,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
        print('✅ تم استعادة المحادثة للمستخدم $userId');
      } else {
        print('⚠️ المحادثة غير محذوفة لهذا المستخدم');
      }
    } catch (e) {
      print('❌ خطأ في استعادة المحادثة: $e');
      rethrow;
    }
  }

  // ✅ دالة للحصول على البريد الإلكتروني من chatId
  String extractEmailFromChatId(String chatId, String currentUserEmail) {
    final parts = chatId.split('_');
    for (var part in parts) {
      try {
        String restored = part
            .replaceAll('_at_', '@')
            .replaceAll('_dot_', '.')
            .replaceAll('_hash_', '#')
            .replaceAll('_dollar_', '\$')
            .replaceAll('_lb_', '[')
            .replaceAll('_rb_', ']')
            .replaceAll('_slash_', '/')
            .replaceAll('_bslash_', '\\');

        if (restored != currentUserEmail && restored.contains('@')) {
          return restored;
        }
      } catch (e) {
        continue;
      }
    }
    return '';
  }

  // ✅ الحصول على جميع محادثات المستخدم (بما فيها المحذوفة - اختياري)
  Future<List<Chat>> getAllUserChats(String userEmail, {bool includeDeleted = false}) async {
    try {
      final snapshot = await db.ref('chats').get();
      final data = snapshot.value as Map<dynamic, dynamic>? ?? {};
      final List<Chat> chats = [];

      data.forEach((chatId, chatData) {
        final chatMap = Map<String, dynamic>.from(chatData);
        final participants = List<String>.from(chatMap['participants'] ?? []);
        final deletedFor = Map<String, dynamic>.from(chatMap['deletedFor'] ?? {});

        if (participants.contains(userEmail)) {
          if (includeDeleted || !deletedFor.containsKey(userEmail)) {
            chats.add(Chat(
              id: chatId.toString(),
              participants: participants,
              lastMessage: chatMap['lastMessage'] ?? '',
              lastMessageTime: chatMap['lastMessageTime'] ?? 0,
              lastMessageSender: chatMap['lastMessageSender'] ?? '',
              createdAt: chatMap['createdAt'] ?? 0,
              updatedAt: chatMap['updatedAt'] ?? 0,
              deletedFor: deletedFor,
              isDeletedChatForYou: chatMap['isDeletedChatForYou'] ?? false
              ),
            );
          }
        }
      });

      chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return chats;
    } catch (e) {
      print('❌ خطأ في جلب المحادثات: $e');
      return [];
    }
  }
}

// خدمة الرسائل
class MessageService {
  final FirebaseDatabase db;

  MessageService(this.db);

  Future<void> sendMessage(Massege message) async {
    if (!message.isValid) {
      throw Exception('بيانات الرسالة غير صالحة');
    }

    try {
      final chatRef = db.ref('chats').child(message.chatId).child('messages');
      final newMessageRef = chatRef.push();

      final messageWithId = message.toMap();
      messageWithId['id'] = newMessageRef.key;

      await newMessageRef.set(messageWithId);

      await db.ref('chats').child(message.chatId).update({
        'lastMessage': message.body,
        'lastMessageTime': message.timestamp,
        'lastMessageSender': message.senderUser,
        'updatedAt': message.timestamp,
      });
    } catch (e) {
      print('❌ خطأ في إرسال الرسالة: $e');
      rethrow;
    }
  }

  Future<void> markMessagesAsRead(String chatId, String userEmail) async {
    try {
      final messagesRef = db.ref('chats').child(chatId).child('messages');
      final snapshot = await messagesRef.get();

      if (!snapshot.exists) return;

      final messages = snapshot.value as Map<dynamic, dynamic>? ?? {};
      final updates = <String, dynamic>{};

      messages.forEach((key, value) {
        final messageData = Map<String, dynamic>.from(value);
        if (messageData['resevUser'] == userEmail && messageData['isRead'] != true) {
          updates['$key/isRead'] = true;
        }
      });

      if (updates.isNotEmpty) {
        await messagesRef.update(updates);
      }
    } catch (e) {
      print('❌ خطأ في تحديث حالة القراءة: $e');
    }
  }
}