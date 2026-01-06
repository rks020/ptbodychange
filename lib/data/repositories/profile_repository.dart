import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

class ProfileRepository {
  final _supabase = Supabase.instance.client;

  Future<Profile?> getProfile() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) return null;
      return Profile.fromSupabase(data);
    } catch (e) {
      // If error (e.g. table doesn't exist or RLS issue), return null
      return null;
    }
  }

  Future<void> updateProfile(Profile profile) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Check if profile exists, if not insert, else update
    final existing = await getProfile();
    
    if (existing == null) {
      await _supabase.from('profiles').insert({
        'id': userId,
        ...profile.toSupabaseMap(),
      });
    } else {
      await _supabase.from('profiles').update(profile.toSupabaseMap()).eq('id', userId);
    }
  }

  Future<String?> uploadAvatar(File imageFile) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final fileExt = imageFile.path.split('.').last;
      final fileName = '$userId/avatar.$fileExt';
      final filePath = fileName;

      await _supabase.storage.from('avatars').upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      final imageUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);
      return imageUrl;
    } catch (e) {
      // Handle upload error
      return null;
    }
  }
}
