import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'dart:io';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/profile.dart'; // Assuming we have Profile model
import '../../../data/models/message.dart';
import '../../../data/repositories/message_repository.dart';
import '../../../shared/widgets/glass_card.dart';

class ChatScreen extends StatefulWidget {
  final Profile otherUser;
  const ChatScreen({super.key, required this.otherUser});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _repository = MessageRepository();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final String _myId = Supabase.instance.client.auth.currentUser!.id;
  
  bool _isEmojiVisible = false;
  final FocusNode _focusNode = FocusNode();
  File? _pickedFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _isEmojiVisible = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: widget.otherUser.avatarUrl != null
                  ? NetworkImage(widget.otherUser.avatarUrl!)
                  : null,
              backgroundColor: AppColors.accentOrange,
              child: widget.otherUser.avatarUrl == null
                  ? Text(
                      (widget.otherUser.firstName?[0] ?? '') + (widget.otherUser.lastName?[0] ?? ''),
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              '${widget.otherUser.firstName} ${widget.otherUser.lastName}',
              style: AppTextStyles.headline.copyWith(fontSize: 16),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryYellow),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _repository.subscribeToMessages(widget.otherUser.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }

                  for (final msg in messages) {
                    if (msg.receiverId == _myId && !msg.isRead) {
                      _repository.markAsRead(msg.id);
                    }
                  }
                });

                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'Mesajlaşmaya başlayın!',
                      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == _myId;
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          
          // Image Preview Area
          if (_pickedFile != null)
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
               color: Colors.black54,
               height: 100,
               child: Row(
                 children: [
                   ClipRRect(
                     borderRadius: BorderRadius.circular(8),
                     child: Image.file(_pickedFile!, width: 80, height: 80, fit: BoxFit.cover),
                   ),
                   const Spacer(),
                   IconButton(
                     icon: const Icon(Icons.close, color: Colors.white),
                     onPressed: () => setState(() => _pickedFile = null),
                   ),
                 ],
               ),
             ),

          // Input Area
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              border: Border(top: BorderSide(color: AppColors.glassBorder)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attach Button
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryYellow),
                  onPressed: _showAttachmentOptions,
                ),
                Expanded(
                  child: TextField(
                    focusNode: _focusNode,
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 5,
                    minLines: 1,
                    onTap: () {
                       if (_isEmojiVisible) setState(() => _isEmojiVisible = false);
                    },
                    decoration: InputDecoration(
                      hintText: 'Mesaj yaz...',
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isEmojiVisible ? Icons.keyboard : Icons.emoji_emotions_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          setState(() {
                             _isEmojiVisible = !_isEmojiVisible;
                             if (_isEmojiVisible) {
                               _focusNode.unfocus();
                             } else {
                               _focusNode.requestFocus();
                             }
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryYellow,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                        onPressed: _sendMessage,
                      ),
                    ),
              ],
            ),
          ),
          
          // Emoji Picker
          if (_isEmojiVisible)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  _messageController.text += emoji.emoji;
                },
                config: const Config(
                  emojiViewConfig: EmojiViewConfig(
                    columns: 7,
                    emojiSizeMax: 28,
                    backgroundColor: Color(0xFF1A1A1A),
                    buttonMode: ButtonMode.MATERIAL,
                    recentsLimit: 28,
                    noRecents: Text(
                      'Son Kullanılan Yok',
                      style: TextStyle(fontSize: 20, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    loadingIndicator: SizedBox.shrink(),
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    initCategory: Category.RECENT,
                    backgroundColor: Color(0xFF1A1A1A),
                    indicatorColor: AppColors.primaryYellow,
                    iconColor: Colors.grey,
                    iconColorSelected: AppColors.primaryYellow,
                    backspaceColor: AppColors.primaryYellow,
                    tabIndicatorAnimDuration: kTabScrollDuration,
                    categoryIcons: CategoryIcons(),
                    recentTabBehavior: RecentTabBehavior.RECENT,
                  ),
                  bottomActionBarConfig: BottomActionBarConfig(
                    enabled: false,
                    backgroundColor: Color(0xFF1A1A1A),
                    buttonColor: Color(0xFF1A1A1A),
                    buttonIconColor: Colors.grey,
                  ),
                  searchViewConfig: SearchViewConfig(
                     backgroundColor: Color(0xFF1A1A1A),
                     buttonIconColor: Colors.grey,
                  ),
                  skinToneConfig: SkinToneConfig(
                    dialogBackgroundColor: Colors.white,
                    indicatorColor: Colors.grey,
                    enabled: true,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Colors.white),
              title: const Text('Kamera', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.white),
              title: const Text('Galeri', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked != null) {
      setState(() {
        _pickedFile = File(picked.path);
      });
    }
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(4), // Reduced padding for image visual
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primaryYellow : AppColors.glassBackground,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
          border: isMe ? null : Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.attachmentUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  message.attachmentUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      height: 150,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                ),
              ),
            if (message.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      message.content,
                      style: AppTextStyles.body.copyWith(
                        color: isMe ? Colors.black : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm').format(message.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.black.withOpacity(0.6) : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty && _pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      String? attachmentUrl;
      String? attachmentType;

      if (_pickedFile != null) {
        final bytes = await _pickedFile!.readAsBytes();
        final fileName = _pickedFile!.path.split('/').last;
        attachmentUrl = await _repository.uploadAttachment(bytes, fileName);
        attachmentType = 'image';
      }

      await _repository.sendMessage(
        widget.otherUser.id, 
        content,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
      );

      _messageController.clear();
      setState(() {
        _pickedFile = null;
        _isUploading = false;
        _isEmojiVisible = false;
        _focusNode.unfocus();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }
}
