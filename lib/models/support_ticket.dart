class SupportTicket {
  final String id;
  final String category;
  final String subject;
  final String status;
  final String priority;
  final String? relatedOrderId;
  final String? relatedProductId;
  final String? relatedShopId;
  final String? relatedConversationId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String lastMessage;

  const SupportTicket({
    required this.id,
    required this.category,
    required this.subject,
    required this.status,
    required this.priority,
    this.relatedOrderId,
    this.relatedProductId,
    this.relatedShopId,
    this.relatedConversationId,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessage,
  });

  factory SupportTicket.fromMap(Map<String, dynamic> map) => SupportTicket(
    id: map['id'] as String,
    category: map['category'] as String? ?? 'other',
    subject: map['subject'] as String? ?? 'Support request',
    status: map['status'] as String? ?? 'open',
    priority: map['priority'] as String? ?? 'normal',
    relatedOrderId: map['related_order_id'] as String?,
    relatedProductId: map['related_product_id'] as String?,
    relatedShopId: map['related_shop_id'] as String?,
    relatedConversationId: map['related_conversation_id'] as String?,
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
    lastMessage: map['last_message'] as String? ?? '',
  );
}

class SupportMessage {
  final String id;
  final String senderId;
  final String senderType;
  final String senderName;
  final String? senderAvatar;
  final String body;
  final bool isInternalNote;
  final DateTime createdAt;

  const SupportMessage({
    required this.id,
    required this.senderId,
    required this.senderType,
    required this.senderName,
    this.senderAvatar,
    required this.body,
    required this.isInternalNote,
    required this.createdAt,
  });

  bool get isAgent => senderType == 'agent';

  factory SupportMessage.fromMap(Map<String, dynamic> map) => SupportMessage(
    id: map['id'] as String,
    senderId: map['sender_id'] as String? ?? '',
    senderType: map['sender_type'] as String? ?? 'user',
    senderName:
        map['sender_name'] as String? ??
        ((map['sender_type'] as String?) == 'agent' ? 'Tkoi support' : 'You'),
    senderAvatar: map['sender_avatar'] as String?,
    body: map['body'] as String? ?? '',
    isInternalNote: map['is_internal_note'] as bool? ?? false,
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}

class AdminTicketSummary {
  final SupportTicket ticket;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String? assignedTo;
  final int messageCount;

  const AdminTicketSummary({
    required this.ticket,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.assignedTo,
    required this.messageCount,
  });

  factory AdminTicketSummary.fromMap(Map<String, dynamic> map) =>
      AdminTicketSummary(
        ticket: SupportTicket.fromMap(map),
        userId: map['user_id'] as String,
        userName: map['user_name'] as String? ?? 'Tkoi user',
        userAvatar: map['user_avatar'] as String?,
        assignedTo: map['assigned_to'] as String?,
        messageCount: (map['message_count'] as num? ?? 0).toInt(),
      );
}

class AdminTicketDetail {
  final Map<String, dynamic> data;

  const AdminTicketDetail(this.data);

  String get id => data['id'] as String;
  String get userId => data['user_id'] as String;
  String get userName => data['user_name'] as String? ?? 'Tkoi user';
  String get username => data['username'] as String? ?? '';
  String get category => data['category'] as String? ?? 'other';
  String get subject => data['subject'] as String? ?? 'Support request';
  String get status => data['status'] as String? ?? 'open';
  String get priority => data['priority'] as String? ?? 'normal';
  String? get assignedTo => data['assigned_to'] as String?;
  String? get relatedConversationId =>
      data['related_conversation_id'] as String?;
  List<SupportMessage> get messages => (data['messages'] as List? ?? const [])
      .map(
        (row) => SupportMessage.fromMap(Map<String, dynamic>.from(row as Map)),
      )
      .toList();
}

class UserReport {
  final String id;
  final String reporterId;
  final String reporterName;
  final String targetType;
  final String targetId;
  final String reasonCategory;
  final String details;
  final String status;
  final String? ticketId;
  final String? resolutionNote;
  final DateTime createdAt;

  const UserReport({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.targetType,
    required this.targetId,
    required this.reasonCategory,
    required this.details,
    required this.status,
    this.ticketId,
    this.resolutionNote,
    required this.createdAt,
  });

  factory UserReport.fromMap(Map<String, dynamic> map) => UserReport(
    id: map['id'] as String,
    reporterId: map['reporter_id'] as String? ?? '',
    reporterName: map['reporter_name'] as String? ?? 'Tkoi user',
    targetType: map['target_type'] as String? ?? 'product',
    targetId: map['target_id'] as String,
    reasonCategory: map['reason_category'] as String? ?? 'Other',
    details: map['details'] as String? ?? '',
    status: map['status'] as String? ?? 'open',
    ticketId: map['ticket_id'] as String?,
    resolutionNote: map['resolution_note'] as String?,
    createdAt:
        DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}

class AdminConversationMessage {
  final String id;
  final String senderName;
  final String? senderAvatar;
  final String body;
  final DateTime createdAt;
  final String? productId;
  final String? orderId;

  const AdminConversationMessage({
    required this.id,
    required this.senderName,
    this.senderAvatar,
    required this.body,
    required this.createdAt,
    this.productId,
    this.orderId,
  });

  factory AdminConversationMessage.fromMap(Map<String, dynamic> map) =>
      AdminConversationMessage(
        id: map['message_id'] as String,
        senderName: map['sender_name'] as String? ?? 'Tkoi user',
        senderAvatar: map['sender_avatar'] as String?,
        body: map['body'] as String? ?? '',
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '') ??
            DateTime.now(),
        productId: map['product_id'] as String?,
        orderId: map['order_id'] as String?,
      );
}
