import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/Provider/chatProvider.dart';
import 'package:provider/Provider/userProvide.dart';
import 'package:provider/model/chat.dart';
import 'package:provider/model/massege.dart';

class AddChatScreen extends ConsumerStatefulWidget {
  const AddChatScreen({super.key});

  @override
  ConsumerState<AddChatScreen> createState() => _AddChatScreenState();
}

class _AddChatScreenState extends ConsumerState<AddChatScreen> {
  final receiverController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _selectedUserEmail;

  @override
  void dispose() {
    receiverController.dispose();
    super.dispose();
  }

  Future<void> _createChat() async {
    if (!_formKey.currentState!.validate()) return;
    
    final currentUser = ref.read(appUserDataProvider);
    if (currentUser == null) {
      _showSnackBar('الرجاء تسجيل الدخول أولاً');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final chatService = ref.read(chatServiceProvider);
      final receiverEmail = receiverController.text.trim();
      
      // إنشاء محادثة جديدة
      final chatId = await chatService.createChat(
        user1Email: currentUser.email,
        user2Email: receiverEmail,
      );
      
      if (mounted) {
        _showSnackBar('تم إنشاء المحادثة بنجاح', isError: false);
        
        // العودة إلى الشاشة الرئيسية مع تمرير chatId
        Navigator.pop(context, chatId);
      }
    } catch (e) {
      _showSnackBar('خطأ في إنشاء المحادثة: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(appUserDataProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('محادثة جديدة'),
        centerTitle: true,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // صورة توضيحية
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat,
                    size: 50,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'بدء محادثة جديدة',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'أدخل البريد الإلكتروني للشخص الذي تريد التحدث معه',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              
              // معلومات المستخدم الحالي
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.green,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'أنت تتحدث بصفتك',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            currentUser?.displayName ?? 'المستخدم',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // حقل البريد الإلكتروني للمستلم
              TextFormField(
                controller: receiverController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني للمستلم',
                  hintText: 'friend@example.com',
                  prefixIcon: const Icon(Icons.person_add, color: Colors.green),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال البريد الإلكتروني للمستلم';
                  }
                  if (!value.contains('@')) {
                    return 'البريد الإلكتروني غير صالح';
                  }
                  if (value == currentUser?.email) {
                    return 'لا يمكنك إنشاء محادثة مع نفسك';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // نص توضيحي
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سيتم إنشاء المحادثة فوراً، ويمكنك البدء في إرسال الرسائل',
                        style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // زر إنشاء المحادثة
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 2,
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat),
                            SizedBox(width: 8),
                            Text(
                              'بدء المحادثة',
                              style: TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}