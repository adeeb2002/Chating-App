// model/user.dart
class AppUser {
  final String? id;
  final String email;
  final String name;
  final String? imageUrl;
  final bool isOnline;
  final int lastSeen;
  final String? password; // فقط للتطوير، لا تخزن كلمة المرور بهذا الشكل في الإنتاج

  AppUser({
    this.id,
    required this.email,
    required this.name,
    this.imageUrl,
    this.isOnline = false,
    this.lastSeen = 0,
    this.password,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'imageUrl': imageUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
    };
  }

  factory AppUser.fromMap(String id, Map<String, dynamic> map) {
    return AppUser(
      id: id,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      imageUrl: map['imageUrl'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: map['lastSeen'] ?? 0,
    );
  }

  String get displayName => name.isNotEmpty ? name : email.split('@')[0];
}