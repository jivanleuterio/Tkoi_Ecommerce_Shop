import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_ticket.dart';

class SupportService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<SupportTicket>> getMyTickets() async {
    final rows = await _client.rpc('get_my_support_tickets');
    return (rows as List)
        .map(
          (row) => SupportTicket.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<SupportMessage>> getMessages(String ticketId) async {
    final rows = await _client.rpc(
      'get_my_support_ticket_messages',
      params: {'p_ticket_id': ticketId},
    );
    return (rows as List)
        .map(
          (row) =>
              SupportMessage.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<String> createTicket({
    required String category,
    required String subject,
    required String body,
    String? orderId,
    String? productId,
    String? shopId,
    String? conversationId,
  }) async {
    final id = await _client.rpc(
      'create_support_ticket',
      params: {
        'p_category': category,
        'p_subject': subject.trim(),
        'p_body': body.trim(),
        'p_related_order_id': orderId,
        'p_related_product_id': productId,
        'p_related_shop_id': shopId,
        'p_related_conversation_id': conversationId,
      },
    );
    return id.toString();
  }

  Future<void> sendMessage(String ticketId, String body) => _client.rpc(
    'add_support_ticket_message',
    params: {'p_ticket_id': ticketId, 'p_body': body.trim()},
  );

  Future<void> createReport({
    required String targetType,
    required String targetId,
    required String reasonCategory,
    required String details,
  }) => _client.rpc(
    'create_report',
    params: {
      'p_target_type': targetType,
      'p_target_id': targetId,
      'p_reason_category': reasonCategory.trim(),
      'p_details': details.trim(),
    },
  );
}
