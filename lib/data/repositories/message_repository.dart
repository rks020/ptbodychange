import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message.dart';

class MessageRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Get conversation with another user
  Future<List<Message>> getMessages(String otherUserId) async {
    final myId = _client.auth.currentUser!.id;

    final response = await _client
        .from('messages')
        .select()
        .or('and(sender_id.eq.$myId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$myId)')
        .order('created_at', ascending: true); // Oldest first for chat view usually, or desc for load more

    return (response as List).map((e) => Message.fromSupabase(e)).toList();
  }

  // Send a message
  Future<void> sendMessage(
    String receiverId, 
    String content, {
    String? attachmentUrl, 
    String? attachmentType,
  }) async {
    final myId = _client.auth.currentUser!.id;

    await _client.from('messages').insert({
      'sender_id': myId,
      'receiver_id': receiverId,
      'content': content,
      'attachment_url': attachmentUrl,
      'attachment_type': attachmentType,
    });
  }

  // Upload attachment
  Future<String?> uploadAttachment(List<int> bytes, String fileName) async {
    try {
      final myId = _client.auth.currentUser!.id;
      // Using a folder per user or just per chat
      final path = '$myId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      await _client.storage.from('chat_attachments').uploadBinary(
        path,
        bytes as dynamic, // Supabase Flutter requires Uint8List usually, handled by caller
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      final url = _client.storage.from('chat_attachments').getPublicUrl(path);
      return url;
    } catch (e) {
      print('Upload Error: $e');
      return null;
    }
  }

  // Subscribe to real-time messages
  Stream<List<Message>> subscribeToMessages(String otherUserId) {
    final myId = _client.auth.currentUser!.id;
    
    // We can't do complex OR filtering efficiently in realtime filter string,
    // so we typically listen to all 'messages' where we are sender or receiver
    // Filter logic needs to be client side or mapped carefully.
    // Supabase Stream API allows simple eq filters.
    // simpler approach: Simple stream query is not fully supported with complex OR yet in client lib easy way.
    // We will use the .stream() feature which is powerful.
    
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((maps) {
          return maps
              .map((e) => Message.fromSupabase(e))
              .where((msg) => 
                (msg.senderId == myId && msg.receiverId == otherUserId) ||
                (msg.senderId == otherUserId && msg.receiverId == myId)
              )
              .toList();
        });
  }

  // Mark as read (optional helper)
  Future<void> markAsRead(String messageId) async {
     await _client.from('messages').update({'is_read': true}).eq('id', messageId);
  }

  // Get Inbox Items (Recent conversations)
  Future<List<InboxItem>> getInboxItems() async {
    final myId = _client.auth.currentUser!.id;

    // 1. Fetch all messages
    final response = await _client
        .from('messages')
        .select()
        .or('sender_id.eq.$myId,receiver_id.eq.$myId')
        .order('created_at', ascending: false);
    
    final allMessages = (response as List).map((e) => Message.fromSupabase(e)).toList();

    // 2. Identify unique other users
    final Set<String> otherUserIds = {};
    for (final msg in allMessages) {
      if (msg.senderId != myId) otherUserIds.add(msg.senderId);
      if (msg.receiverId != myId) otherUserIds.add(msg.receiverId);
    }

    if (otherUserIds.isEmpty) return [];

    // 3. Fetch profiles for these users
    final profilesResponse = await _client
        .from('profiles')
        .select('id, first_name, last_name, avatar_url')
        .filter('id', 'in', otherUserIds.toList());
    
    final Map<String, Map<String, dynamic>> profilesMap = {};
    for (final p in (profilesResponse as List)) {
      profilesMap[p['id'] as String] = p as Map<String, dynamic>;
    }

    // 4. Build Inbox Items
    final Map<String, InboxItem> conversationMap = {};

    for (final msg in allMessages) {
        final otherId = msg.senderId == myId ? msg.receiverId : msg.senderId;
        
        // Skip if we somehow don't have this user's profile (deleted user?)
        // or just show backup name
        final profile = profilesMap[otherId];
        final otherName = profile != null 
             ? '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim() 
             : 'Kullanıcı';
        final otherAvatar = profile != null ? profile['avatar_url'] as String? : null;
        
        if (!conversationMap.containsKey(otherId)) {
          conversationMap[otherId] = InboxItem(
            userId: otherId,
            userName: otherName.isEmpty ? 'İsimsiz' : otherName,
            userAvatar: otherAvatar,
            lastMessage: msg.content,
            lastMessageTime: msg.createdAt,
            unreadCount: 0,
          );
        }

        // Increment unread count if I am receiver and not read
        if (msg.receiverId == myId && !msg.isRead) {
           conversationMap[otherId]!.unreadCount++;
        }
    }

    return conversationMap.values.toList();
  }
}

class InboxItem {
  final String userId;
  final String userName;
  final String? userAvatar;
  final String lastMessage;
  final DateTime lastMessageTime;
  int unreadCount;

  InboxItem({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
  });
}
