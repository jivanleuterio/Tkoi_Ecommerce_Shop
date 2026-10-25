import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_profile.dart';

class ProfileService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('Please sign in again.');
    return id;
  }

  Future<AppProfile> getMyProfile() async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', _userId)
        .single();
    return AppProfile.fromMap(data);
  }

  Future<void> updateProfile({
    required String fullName,
    required String username,
    required String mobileNumber,
    required String address,
    String? avatarUrl,
  }) async {
    await _client
        .from('profiles')
        .update({
          'full_name': fullName.trim(),
          'username': username.trim(),
          'mobile_number': mobileNumber.trim(),
          'address': address.trim(),
          'avatar_url': ?avatarUrl,
        })
        .eq('id', _userId);
  }
}
