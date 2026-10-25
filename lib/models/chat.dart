class ChatContext {
  final String conversationId;
  final String otherUserId;
  final String otherName;
  final String? otherAvatar;
  final String shopName;
  final String? productId;
  final String? productName;
  final String? productImage;
  final String? orderId;

  const ChatContext({
    required this.conversationId,
    required this.otherUserId,
    required this.otherName,
    this.otherAvatar,
    required this.shopName,
    this.productId,
    this.productName,
    this.productImage,
    this.orderId,
  });

  factory ChatContext.fromMap(Map<String, dynamic> map) => ChatContext(
    conversationId: map['conversation_id'] as String,
    otherUserId: map['other_user_id'] as String,
    otherName: map['other_name'] as String? ?? 'Tkoi user',
    otherAvatar: map['other_avatar'] as String?,
    shopName: map['shop_name'] as String? ?? 'Tkoi shop',
    productId: map['product_id'] as String?,
    productName: map['product_name'] as String?,
    productImage: map['product_image'] as String?,
    orderId: map['order_id'] as String?,
  );
}

class ChatInboxItem extends ChatContext {
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;

  const ChatInboxItem({
    required super.conversationId,
    required super.otherUserId,
    required super.otherName,
    super.otherAvatar,
    required super.shopName,
    super.productId,
    super.productName,
    super.productImage,
    super.orderId,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  factory ChatInboxItem.fromMap(Map<String, dynamic> map) => ChatInboxItem(
    conversationId: map['conversation_id'] as String,
    otherUserId: map['other_user_id'] as String,
    otherName: map['other_name'] as String? ?? 'Tkoi user',
    otherAvatar: map['other_avatar'] as String?,
    shopName: map['shop_name'] as String? ?? 'Tkoi shop',
    productId: map['product_id'] as String?,
    productName: map['product_name'] as String?,
    productImage: map['product_image'] as String?,
    orderId: map['order_id'] as String?,
    lastMessage: map['last_message'] as String? ?? 'Start the conversation',
    lastMessageAt:
        DateTime.tryParse(map['last_message_at'] as String? ?? '') ??
        DateTime.now(),
    unreadCount: (map['unread_count'] as num? ?? 0).toInt(),
  );
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final String? productId;
  final String? orderId;
  final DateTime createdAt;
  final DateTime? readAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    this.productId,
    this.orderId,
    required this.createdAt,
    this.readAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id'] as String,
    conversationId: map['conversation_id'] as String,
    senderId: map['sender_id'] as String,
    body: map['body'] as String? ?? '',
    productId: map['product_id'] as String?,
    orderId: map['order_id'] as String?,
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    readAt: DateTime.tryParse(map['read_at'] as String? ?? ''),
  );
}
