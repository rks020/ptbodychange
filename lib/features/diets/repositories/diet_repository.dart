
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/diet_model.dart';

class DietRepository {
  final _supabase = Supabase.instance.client;

  Future<Diet?> getActiveDiet(String memberId) async {
    final response = await _supabase
        .from('diets')
        .select('*, diet_items(*)')
        .eq('member_id', memberId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;

    // Supabase returns items unordered or by ID, let's sort them in Dart or ask SQL
    final diet = Diet.fromJson(response);
    diet.items.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return diet;
  }

  Future<List<Diet>> getMemberDiets(String memberId) async {
    final response = await _supabase
        .from('diets')
        .select('*, diet_items(*)')
        .eq('member_id', memberId)
        .order('created_at', ascending: false);

    final List<Diet> diets = [];
    for (var d in response as List) {
      final diet = Diet.fromJson(d);
      diet.items.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      diets.add(diet);
    }
    return diets;
  }

  Future<void> createDiet(Diet diet, List<DietItem> items) async {
    // 1. Create Diet
    final dietResponse = await _supabase.from('diets').insert({
      'member_id': diet.memberId,
      'trainer_id': diet.trainerId,
      'start_date': diet.startDate.toIso8601String(),
      'end_date': diet.endDate?.toIso8601String(),
      'notes': diet.notes,
    }).select().single();

    final dietId = dietResponse['id'];

    // 2. Create Items
    final itemsData = items.map((item) {
      final json = item.toJson();
      json['diet_id'] = dietId;
      return json;
    }).toList();

    if (itemsData.isNotEmpty) {
      await _supabase.from('diet_items').insert(itemsData);
    }
  }

  Future<void> deleteDiet(String dietId) async {
    await _supabase.from('diets').delete().eq('id', dietId);
  }
}
