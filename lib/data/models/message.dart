class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    this.isRead = false,
    this.attachmentUrl,
    this.attachmentType,
  });

  factory Message.fromSupabase(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      isRead: map['is_read'] as bool? ?? false,
      attachmentUrl: map['attachment_url'] as String?,
      attachmentType: map['attachment_type'] as String?,
    );
  }

  final String? attachmentUrl;
  final String? attachmentType;

  Map<String, dynamic> toSupabase() {
    return {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      // created_at is handled by DB default usually, but we can send it if needed
      // 'is_read': isRead,
    };
  }
}
