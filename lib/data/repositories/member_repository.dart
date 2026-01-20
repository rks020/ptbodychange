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

    await _client.from('members').insert({
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
    });
  }

  // Read all members
  Future<List<Member>> getAll() async {
    final response = await _client
        .from('members')
        .select('*, profiles:trainer_id(first_name, last_name)')
        .order('name', ascending: true);
    
    return (response as List)
        .map((json) => Member.fromSupabaseMap(json))
        .toList();
  }

  // Read active members
  Future<List<Member>> getActive() async {
    final response = await _client
        .from('members')
        .select('*, profiles:trainer_id(first_name, last_name)')
        .eq('is_active', true)
        .order('name', ascending: true);
    
    return (response as List)
        .map((json) => Member.fromSupabaseMap(json))
        .toList();
  }

  // Read active members for a specific trainer
  Future<List<Member>> getActiveByTrainer(String trainerId) async {
    final response = await _client
        .from('members')
        .select('*, profiles:trainer_id(first_name, last_name)')
        .eq('is_active', true)
        .eq('trainer_id', trainerId)
        .order('name', ascending: true);
    
    return (response as List)
        .map((json) => Member.fromSupabaseMap(json))
        .toList();
  }

  // Read single member
  Future<Member?> getById(String id) async {
    final response = await _client
        .from('members')
        .select('*, profiles:trainer_id(first_name, last_name)')
        .eq('id', id)
        .maybeSingle();
    
    if (response == null) return null;
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
    };
    
    // Remove trainer_id key if strictly unnecessary? No, we likely want to allow setting null.
    // Ideally we only update it if it's meant to be changed. 
    // Since UI passes the dropdown value (which starts as current value), it verifies intent.
    
    await _client.from('members').update(updateData).eq('id', member.id);
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
    final normalizedEmail = email.toLowerCase().trim();
    
    // Check in members table
    var memberQuery = _client
        .from('members')
        .select('id')
        .eq('email', normalizedEmail);
    
    // Exclude current member when editing
    if (excludeMemberId != null) {
      memberQuery = memberQuery.neq('id', excludeMemberId);
    }
    
    final memberResponse = await memberQuery.maybeSingle();
    if (memberResponse != null) return true;
    
    // Check in profiles table (trainers/admins)
    final profileResponse = await _client
        .from('profiles')
        .select('id')
        .eq('email', normalizedEmail)
        .maybeSingle();
    
    return profileResponse != null;
  }
}
