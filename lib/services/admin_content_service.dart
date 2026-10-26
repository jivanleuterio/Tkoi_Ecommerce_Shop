import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/moderation_content.dart';

class AdminContentService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<ModerationContent>> getContent({
    required String contentType,
    String? status,
    String? search,
  }) async {
    final rows = await _client.rpc(
      'admin_list_moderation_content',
      params: {
        'p_content_type': contentType,
        'p_status': status,
        'p_search': search,
      },
    );
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(ModerationContent.fromMap)
        .toList();
  }

  Future<void> setModeration({
    required String contentType,
    required String contentId,
    required String status,
    required String reason,
    String? reportId,
    String? ticketId,
  }) => _client.rpc(
    'admin_set_content_moderation',
    params: {
      'p_content_type': contentType,
      'p_content_id': contentId,
      'p_status': status,
      'p_reason': reason.trim(),
      'p_report_id': reportId,
      'p_ticket_id': ticketId,
    },
  );
}
