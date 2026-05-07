class Massege {
  final String id;
  final String senderUser;
  final String resevUser;
  final String body;
  final String chatId;
  final int timestamp;
  final bool isRead;
  final MessageType type;
  
  Massege({
    required this.id,
    required this.senderUser,
    required this.resevUser,
    required this.body,
    required this.chatId,
    required this.timestamp,
    this.isRead = false,
    this.type = MessageType.text,
  });
  
  // مصنع لإنشاء رسالة جديدة
  factory Massege.create({
    required String senderUser,
    required String resevUser,
    required String body,
    required String chatId,
    MessageType type = MessageType.text,
  }) {
    final now = DateTime.now();
    return Massege(
      id: now.millisecondsSinceEpoch.toString(),
      senderUser: senderUser,
      resevUser: resevUser,
      body: body,
      chatId: chatId,
      timestamp: now.millisecondsSinceEpoch,
      isRead: false,
      type: type,
    );
  }
  
  // تحويل إلى Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderUser': senderUser,
      'resevUser': resevUser,
      'body': body,
      'chatId': chatId,
      'timestamp': timestamp,
      'isRead': isRead,
      'type': type.index,
    };
  }
  
  // تحويل من Map
  factory Massege.fromMap(Map<dynamic, dynamic> map) {
    return Massege(
      id: map['id']?.toString() ?? '',
      senderUser: map['senderUser']?.toString() ?? '',
      resevUser: map['resevUser']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      chatId: map['chatId']?.toString() ?? '',
      timestamp: map['timestamp'] is int 
          ? map['timestamp'] 
          : int.tryParse(map['timestamp']?.toString() ?? '0') ?? 0,
      isRead: map['isRead'] == true,
      type: map['type'] != null && map['type'] < MessageType.values.length
          ? MessageType.values[map['type']]
          : MessageType.text,
    );
  }
  
  // التحقق من صحة البيانات
  bool get isValid {
    return senderUser.isNotEmpty && 
           resevUser.isNotEmpty && 
           body.isNotEmpty && 
           chatId.isNotEmpty;
  }
  
  // هل الرسالة من المستخدم الحالي؟
  bool isFromUser(String userEmail) => senderUser == userEmail;
  
  // هل الرسالة للمستخدم الحالي؟
  bool isToUser(String userEmail) => resevUser == userEmail;
}

// أنواع الرسائل
enum MessageType {
  text,   // نص
  image,  // صورة
  audio,  // صوت
  video,  // فيديو
}