import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/member.dart';

class MemberRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Create
  Future<void> create(Member member) async {
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
      'trainer_id': _client.auth.currentUser?.id,
      'subscription_package': member.subscriptionPackage,
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
        .select()
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
    await _client.from('members').update({
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
    }).eq('id', member.id);
  }

  // Delete
  Future<void> delete(String id) async {
    await _client.from('members').delete().eq('id', id);
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

  // Get members who have measurements
  Future<List<Member>> getMembersWithMeasurements() async {
    final response = await _client
        .from('members')
        .select('*, measurements!inner(id)')
        .order('name', ascending: true);
    
    return (response as List)
        .map((json) => Member.fromSupabaseMap(json))
        .toList();
  }
}
