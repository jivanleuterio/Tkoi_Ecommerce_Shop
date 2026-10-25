import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat.dart';

class ChatService {
  final SupabaseClient _client = Supabase.instance.client;

  String get currentUserId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('Please sign in again.');
    return id;
  }

  Future<String> getOrCreateConversation({
    required String sellerId,
    String? productId,
    String? orderId,
  }) async {
    final id = await _client.rpc(
      'get_or_create_conversation',
      params: {
        'p_seller_id': sellerId,
        'p_product_id': productId,
        'p_order_id': orderId,
      },
    );
    return id as String;
  }

  Future<List<ChatInboxItem>> getInbox() async {
    final rows = await _client.rpc('get_chat_inbox');
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(ChatInboxItem.fromMap)
        .toList();
  }

  Future<ChatContext> getContext(String conversationId) async {
    final rows = await _client.rpc(
      'get_chat_context',
      params: {'p_conversation_id': conversationId},
    );
    final list = (rows as List).whereType<Map<String, dynamic>>().toList();
    if (list.isEmpty) throw Exception('Conversation not found.');
    return ChatContext.fromMap(list.single);
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) => _client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at', ascending: true)
      .map((rows) {
        final messages = rows.map(ChatMessage.fromMap).toList();
        messages.sort((first, second) {
          final byTime = first.createdAt.compareTo(second.createdAt);
          return byTime != 0 ? byTime : first.id.compareTo(second.id);
        });
        return List<ChatMessage>.unmodifiable(messages);
      });

  Future<void> sendMessage({
    required String conversationId,
    required String body,
    String? productId,
    String? orderId,
  }) async {
    await _client.rpc(
      'send_chat_message',
      params: {
        'p_conversation_id': conversationId,
        'p_body': body.trim(),
        'p_product_id': productId,
        'p_order_id': orderId,
      },
    );
  }

  Future<void> markRead(String conversationId) => _client.rpc(
    'mark_conversation_read',
    params: {'p_conversation_id': conversationId},
  );
}
