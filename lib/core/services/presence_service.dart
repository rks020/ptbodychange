import 'package:supabase_flutter/supabase_flutter.dart';

class PresenceService {
  final SupabaseClient _client = Supabase.instance.client;
  RealtimeChannel? _channel;

  Future<void> connect(String userId) async {
    _channel = _client.channel('online_users');
    
    await _channel?.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        // Track the user presence
        await _channel?.track({'user_id': userId, 'online_at': DateTime.now().toIso8601String()});
      }
    });
  }

  Future<void> disconnect() async {
    if (_channel != null) {
      await _channel!.unsubscribe();
      _channel = null;
    }
  }
}
