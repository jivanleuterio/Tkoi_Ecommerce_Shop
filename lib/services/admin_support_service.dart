import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_ticket.dart';

class AdminSupportService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<AdminTicketSummary>> getTickets({
    String? status,
    String? category,
    String? priority,
    bool assignedToMe = false,
  }) async {
    final rows = await _client.rpc(
      'admin_list_tickets',
      params: {
        'p_status': status,
        'p_category': category,
        'p_priority': priority,
        'p_assigned_to_me': assignedToMe,
      },
    );
    return (rows as List)
        .map(
          (row) =>
              AdminTicketSummary.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<AdminTicketDetail> getTicket(String ticketId) async {
    final data = await _client.rpc(
      'admin_get_ticket_detail',
      params: {'p_ticket_id': ticketId},
    );
    return AdminTicketDetail(Map<String, dynamic>.from(data as Map));
  }

  Future<void> updateTicket({
    required String ticketId,
    required String status,
    required String priority,
    String? assignedTo,
    required String reason,
  }) => _client.rpc(
    'admin_update_ticket',
    params: {
      'p_ticket_id': ticketId,
      'p_status': status,
      'p_priority': priority,
      'p_assigned_to': assignedTo,
      'p_reason': reason.trim(),
    },
  );

  Future<void> reply({
    required String ticketId,
    required String body,
    required bool internal,
    required String reason,
  }) => _client.rpc(
    'admin_reply_ticket',
    params: {
      'p_ticket_id': ticketId,
      'p_body': body.trim(),
      'p_is_internal_note': internal,
      'p_reason': reason.trim(),
    },
  );

  Future<List<UserReport>> getReports({
    String? status,
    String? targetType,
  }) async {
    final rows = await _client.rpc(
      'admin_list_reports',
      params: {'p_status': status, 'p_target_type': targetType},
    );
    return (rows as List)
        .map((row) => UserReport.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> resolveReport({
    required String reportId,
    required String status,
    required String resolution,
    required String reason,
  }) => _client.rpc(
    'admin_resolve_report',
    params: {
      'p_report_id': reportId,
      'p_status': status,
      'p_resolution_note': resolution.trim(),
      'p_reason': reason.trim(),
    },
  );

  Future<List<AdminConversationMessage>> viewTicketConversation({
    required String ticketId,
    required String reason,
  }) async {
    final rows = await _client.rpc(
      'admin_view_ticket_conversation',
      params: {'p_ticket_id': ticketId, 'p_reason': reason.trim()},
    );
    return (rows as List)
        .map(
          (row) => AdminConversationMessage.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }
}
