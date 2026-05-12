class Chat {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final int lastMessageTime;
  final String lastMessageSender;
  final int createdAt;
  final int updatedAt;
  bool isDeletedChatForYou = false;
  final Map<String, dynamic>? deletedFor;
  final Map<String, dynamic>? clearedFor;
  final bool? isBlocked;
  final String? blockedBy;


  Chat({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageSender,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeletedChatForYou,
    this.deletedFor,
    this.clearedFor,
     this.isBlocked,
    this.blockedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'lastMessageSender': lastMessageSender,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'clearedFor': clearedFor,
      'deletedFor': deletedFor,
      'isBlocked' : isBlocked,
      'blockedBy' : blockedBy
    };
  }

  factory Chat.fromMap(String id, Map<String, dynamic> map) {
    return Chat(
      id: id,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] ?? 0,
      lastMessageSender: map['lastMessageSender'] ?? '',
      createdAt: map['createdAt'] ?? 0,
      updatedAt: map['updatedAt'] ?? 0,
      isDeletedChatForYou: map['isDeletedChatForYou'] ?? false,
      deletedFor: map['deletedFor'] != null
          ? Map<String, dynamic>.from(map['deletedFor'])
          : null,
      clearedFor: map['clearedFor'] != null
          ? Map<String, dynamic>.from(map['clearedFor'])
          : null,
      isBlocked: map['isBlocked'] ?? false,
      blockedBy: map['blockedBy']?? ''    
    );
  }

  // الحصول على الطرف الآخر في المحادثة
  String getOtherParticipant(String currentUserEmail) {
    return participants.firstWhere(
      (p) => p != currentUserEmail,
      orElse: () => '',
    );
  }

  // هل المحادثة تحتوي على مستخدم معين؟
  bool hasParticipant(String email) => participants.contains(email);
  bool isDeletedForUser(String userId) {
    return deletedFor != null && deletedFor!.containsKey(userId);
  }
}
