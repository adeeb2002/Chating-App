import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../model/massege.dart';

final firebaseDatabaseProvider = Provider<FirebaseDatabase>((ref) {
  return FirebaseDatabase.instance;
});

final messageServiceProvider = Provider<MessageService>((ref) {
  final db = ref.watch(firebaseDatabaseProvider);
  return MessageService(db);
});

final messagesProvider = StreamProvider.family<List<Massege>, String>((ref, chatId) {
  final db = ref.watch(firebaseDatabaseProvider);
  final currentUserEmail = ref.watch(currentUserEmailProvider);
  
  return db.ref('chats').child(chatId).child('messages').onValue.map((event) {
    final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
    
    final messages = data.entries.map((entry) {
      return Massege.fromMap(entry.value as Map<dynamic, dynamic>);
    }).toList();
    
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    if (currentUserEmail != null && messages.isNotEmpty) {
      _markUnreadMessages(db, chatId, currentUserEmail, messages);
    }
    
    return messages;
  });
});

void _markUnreadMessages(
  FirebaseDatabase db,
  String chatId,
  String currentUserEmail,
  List<Massege> messages,
) {
  final unreadMessages = messages.where((msg) => 
    msg.resevUser == currentUserEmail && !msg.isRead
  ).toList();
  
  if (unreadMessages.isNotEmpty) {
    final messagesRef = db.ref('chats').child(chatId).child('messages');
    for (var message in unreadMessages) {
      messagesRef.child(message.id).update({'isRead': true});
    }
  }
}

// ✅ إعادة تسمية هذا الـ Provider لتجنب التعارض
final currentUserEmailProvider = StateProvider<String?>((ref) => null);

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
        if (messageData['resevUser'] == userEmail && 
            messageData['isRead'] != true) {
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