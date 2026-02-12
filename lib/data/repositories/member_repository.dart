import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/member.dart';

class MemberRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Create
  Future<void> create(Member member) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // Fetch organization_id from current user's profile
    final profileResponse = await _client
        .from('profiles')
        .select('organization_id')
        .eq('id', userId)
        .single();
    
    final organizationId = profileResponse['organization_id'] as String?;

    await _client.from('members').upsert({
      'id': member.id,
      'name': member.name,
      'email': member.email,
      'phone': member.phone,
      'photo_url': member.photoPath,
      'is_active': member.isActive,
      'join_date': member.joinDate.toIso8601String(),
      'emergency_contact': member.emergencyContact,
      'emergency_phone': member.emergencyPhone,
      'notes': member.notes,
      // Use provided trainerId, fallback to current user
      'trainer_id': member.trainerId ?? userId,
      'organization_id': organizationId, // Critical for RLS
      'subscription_package': member.subscriptionPackage,
      'session_count': member.sessionCount,
      'is_multisport': member.isMultisport,
    });
  }

  // Helper method to enrich member data with password_changed from profiles
  Future<List<Map<String, dynamic>>> _enrichWithPasswordChanged(List<dynamic> memberData) async {
    if (memberData.isEmpty) return [];
    
    try {
      // Get all member IDs
      final memberIds = memberData.map((m) => m['id'] as String).toList();
      
      // Fetch password_changed for all members in one query
      final profilesResponse = await _client
          .from('profiles')
          .select('id, password_changed')
          .inFilter('id', memberIds);
      
      // Create a map of id -> password_changed
      final passwordChangedMap = <String, bool>{};
      for (final profile in profilesResponse as List) {
        passwordChangedMap[profile['id']] = profile['password_changed'] as bool? ?? true;
      }
      
      // Enrich member data with password_changed
      final enrichedData = <Map<String, dynamic>>[];
      for (final member in memberData) {
        final memberMap = Map<String, dynamic>.from(member);
        memberMap['password_changed'] = passwordChangedMap[member['id']] ?? true;
        enrichedData.add(memberMap);
      }
      
      return enrichedData;
    } catch (e) {
        // Enrichment failed
      // Return original data if enrichment fails
      return memberData.map((m) => Map<String, dynamic>.from(m)).toList();
    }
  }

  // Read all members
  Future<List<Member>> getAll() async {
    final response = await _client
        .from('members')
        .select('*, profiles:trainer_id(first_name, last_name)')
        .order('name', ascending: true);
    
    final enrichedData = await _enrichWithPasswordChanged(response as List);
    return enrichedData.map((json) => Member.fromSupabaseMap(json)).toList();
  }

  // Read active members
  Future<List<Member>> getActive() async {
    final response = await _client
        .from('members')
        .select('*, profiles:trainer_id(first_name, last_name)')
        .eq('is_active', true)
        .order('name', ascending: true);
    
    final enrichedData = await _enrichWithPasswordChanged(response as List);
    return enrichedData.map((json) => Member.fromSupabaseMap(json)).toList();
  }

  // Read active members for a specific trainer
  Future<List<Member>> getActiveByTrainer(String trainerId) async {
    final response = await _client
        .from('members')
        .select('*, profiles:trainer_id(first_name, last_name)')
        .eq('is_active', true)
        .eq('trainer_id', trainerId)
        .order('name', ascending: true);
    
    final enrichedData = await _enrichWithPasswordChanged(response as List);
    return enrichedData.map((json) => Member.fromSupabaseMap(json)).toList();
  }

  // Read single member
  Future<Member?> getById(String id) async {
    final response = await _client
        .from('members')
        .select('*, profiles:trainer_id(first_name, last_name)')
        .eq('id', id)
        .maybeSingle();
    
    if (response == null) return null;
    
    // Fetch password_changed from profiles table separately
    try {
      final profileResponse = await _client
          .from('profiles')
          .select('password_changed')
          .eq('id', id)
          .maybeSingle();
      
      if (profileResponse != null) {
        response['password_changed'] = profileResponse['password_changed'];
      }
    } catch (e) {
        // Failed to fetch password_changed
      // Continue without password_changed data
    }
    
    return Member.fromSupabaseMap(response);
  }

  // Search members
  Future<List<Member>> search(String query) async {
    final response = await _client
        .from('members')
        .select()
        .or('name.ilike.%$query%,email.ilike.%$query%,phone.ilike.%$query%')
        .order('name', ascending: true);
    
    return (response as List)
        .map((json) => Member.fromSupabaseMap(json))
        .toList();
  }

  // Update
  Future<void> update(Member member) async {
    final updateData = {
      'name': member.name,
      'email': member.email,
      'phone': member.phone,
      'photo_url': member.photoPath,
      'is_active': member.isActive,
      'emergency_contact': member.emergencyContact,
      'emergency_phone': member.emergencyPhone,
      'notes': member.notes,
      'updated_at': DateTime.now().toIso8601String(),
      'subscription_package': member.subscriptionPackage,
      'session_count': member.sessionCount,
      'trainer_id': member.trainerId, // Always include trainer_id (null or value)
      'is_multisport': member.isMultisport,
    };
    
    await _client.from('members').update(updateData).eq('id', member.id);
  }

  Future<void> updatePassword(String userId, String newPassword) async {
    await _client.functions.invoke(
      'update-user-password',
      body: {
        'userId': userId,
        'newPassword': newPassword,
      },
    );
  }

  // Delete
  Future<void> delete(String id) async {
    // OLD: await _client.from('members').delete().eq('id', id);
    // NEW: Call edge function to delete auth user as well
    final response = await _client.functions.invoke(
      'delete-user',
      body: {'user_id': id},
    );
    
    if (response.status != 200) {
      throw Exception('Failed to delete user: ${response.data}');
    }
  }

  // Get member count
  Future<int> getCount() async {
    final response = await _client
        .from('members')
        .select('*')
        .count();
    return response.count;
  }

  // Get active member count
  Future<int> getActiveCount() async {
    final response = await _client
        .from('members')
        .select('*')
        .eq('is_active', true)
        .count();
    return response.count;
  }

  // Get members who have measurements (Filtered by Trainer)
  Future<List<Member>> getMembersWithMeasurements() async {
    final userId = _client.auth.currentUser?.id;
    
    var query = _client
        .from('members')
        .select('*, measurements!inner(id)');

    if (userId != null) {
      query = query.eq('trainer_id', userId);
    }
    
    final response = await query.order('name', ascending: true);
    
    return (response as List)
        .map((json) => Member.fromSupabaseMap(json))
        .toList();
  }

  /// Check if email already exists in members or profiles table
  /// Returns true if email is already in use
  Future<bool> isEmailTaken(String email, {String? excludeMemberId}) async {
    try {
      final params = {
        'email_to_check': email.toLowerCase().trim(),
        'exclude_user_id': excludeMemberId,
      };
      
      return await _client.rpc<bool>('check_email_exists', params: params);
    } catch (e) {
      // Fallback or log error, but return false to not block unless critical
      // Actually if RPC fails, we should probably treat as "can't verify" -> safest to block or allow?
      // Blocking might prevent legitimate users if offline.
      // But this is a specific duplicate check.
      // Let's rethrow or return false (allow) if network error?
      // Better to return false if we can't check, but usually this means network issue.
      // Let's just return await without try-catch to propagate error to UI (it catches it).
      rethrow;
    }
  }
}
