import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/measurement.dart';

class MeasurementRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'measurements';
  static const String _bucketName = 'measurements';

  // Create
  Future<Measurement> create(Measurement measurement) async {
    final data = await _supabase
        .from(_tableName)
        .insert(measurement.toSupabaseMap())
        .select()
        .single();
    
    return Measurement.fromSupabaseMap(data);
  }

  // Get all measurements for a member
  Future<List<Measurement>> getByMemberId(
    String memberId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _supabase
        .from(_tableName)
        .select()
        .eq('member_id', memberId);

    if (startDate != null) {
      query = query.gte('measurement_date', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lte('measurement_date', endDate.toIso8601String());
    }

    final data = await query.order('measurement_date', ascending: false);
    return (data as List).map((m) => Measurement.fromSupabaseMap(m)).toList();
  }

  // Get latest measurement for a member
  Future<Measurement?> getLatestByMemberId(String memberId) async {
    final data = await _supabase
        .from(_tableName)
        .select()
        .eq('member_id', memberId)
        .order('measurement_date', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;
    return Measurement.fromSupabaseMap(data);
  }

  // Get measurement by ID
  Future<Measurement?> getById(String id) async {
    final data = await _supabase
        .from(_tableName)
        .select()
        .eq('id', id)
        .maybeSingle();

    if (data == null) return null;
    return Measurement.fromSupabaseMap(data);
  }

  // Get measurements within date range
  Future<List<Measurement>> getByDateRange({
    required String memberId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final data = await _supabase
        .from(_tableName)
        .select()
        .eq('member_id', memberId)
        .gte('measurement_date', startDate.toIso8601String())
        .lte('measurement_date', endDate.toIso8601String())
        .order('measurement_date', ascending: true);
    
    return (data as List).map((m) => Measurement.fromSupabaseMap(m)).toList();
  }

  // Update
  Future<void> update(Measurement measurement) async {
    await _supabase
        .from(_tableName)
        .update(measurement.toSupabaseMap())
        .eq('id', measurement.id!);
  }

  // Delete
  Future<void> delete(String id) async {
    await _supabase.from(_tableName).delete().eq('id', id);
  }

  // Get total measurement count
  Future<int> getCount() async {
    final count = await _supabase
        .from(_tableName)
        .count(CountOption.exact);
    
    return count;
  }

  // Get measurement count for a member
  Future<int> getCountByMember(String memberId) async {
    final count = await _supabase
        .from(_tableName)
        .count(CountOption.exact)
        .eq('member_id', memberId);
    
    return count;
  }

  // Compare two measurements
  Future<Map<String, double>> compareWithPrevious(Measurement current) async {
    final measurements = await getByMemberId(current.memberId);
    if (measurements.length < 2) return {};

    final previous = measurements[1]; // Second most recent (first is current)
    
    return {
      'weight': current.calculateWeightChange(previous),
      if (current.bodyFatPercentage != null && previous.bodyFatPercentage != null)
        'bodyFat': current.bodyFatPercentage! - previous.bodyFatPercentage!,
      if (current.chest != null && previous.chest != null)
        'chest': current.calculateCircumferenceChange('chest', previous) ?? 0,
      if (current.waist != null && previous.waist != null)
        'waist': current.calculateCircumferenceChange('waist', previous) ?? 0,
      if (current.hips != null && previous.hips != null)
        'hips': current.calculateCircumferenceChange('hips', previous) ?? 0,
    };
  }

  // Upload photo to Supabase Storage
  Future<String> uploadPhoto(
    String memberId,
    String measurementId,
    File photo,
    String position, // 'front', 'side', or 'back'
  ) async {
    final fileName = '$memberId/$measurementId/$position.jpg';
    
    await _supabase.storage.from(_bucketName).upload(
      fileName,
      photo,
      fileOptions: const FileOptions(
        upsert: true,
        contentType: 'image/jpeg',
      ),
    );

    final publicUrl = _supabase.storage.from(_bucketName).getPublicUrl(fileName);
    return publicUrl;
  }

  // Delete photo from Supabase Storage
  Future<void> deletePhoto(String photoUrl) async {
    try {
      final uri = Uri.parse(photoUrl);
      final pathSegments = uri.pathSegments;
      final bucketIndex = pathSegments.indexOf(_bucketName);
      
      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
        await _supabase.storage.from(_bucketName).remove([filePath]);
      }
    } catch (e) {
      print('Error deleting photo: $e');
    }
  }
}
