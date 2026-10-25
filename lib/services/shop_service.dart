import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/shop.dart';

class ShopService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('Please sign in again.');
    return id;
  }

  Future<Shop?> getMyShop() async {
    final data = await _client
        .from('shops')
        .select()
        .eq('owner_id', _userId)
        .maybeSingle();
    return data == null ? null : Shop.fromMap(data);
  }

  Future<Shop> getShop(String id) async {
    final data = await _client.from('shops').select().eq('id', id).single();
    return Shop.fromMap(data);
  }

  Future<Shop> saveShop({
    String? id,
    required String name,
    required String ownerName,
    required String description,
    required String contactNumber,
    required String email,
    required String location,
    String? logoUrl,
  }) async {
    final values = {
      'owner_id': _userId,
      'name': name.trim(),
      'owner_name': ownerName.trim(),
      'description': description.trim(),
      'contact_number': contactNumber.trim(),
      'email': email.trim(),
      'location': location.trim(),
      'logo_url': ?logoUrl,
    };

    final Map<String, dynamic> data;
    if (id == null) {
      data = await _client.from('shops').insert(values).select().single();
    } else {
      data = await _client
          .from('shops')
          .update(values)
          .eq('id', id)
          .select()
          .single();
    }
    return Shop.fromMap(data);
  }
}
