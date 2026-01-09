import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment.dart';

class PaymentRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // Create
  Future<void> create(Payment payment) async {
    await _client.from('payments').insert(payment.toSupabaseMap());
  }

  // Read member payments
  Future<List<Payment>> getMemberPayments(String memberId) async {
    final response = await _client
        .from('payments')
        .select()
        .eq('member_id', memberId)
        .order('date', ascending: false);
    
    return (response as List)
        .map((json) => Payment.fromSupabaseMap(json))
        .toList();
  }

  // Get total income for a date range
  Future<Map<String, double>> getIncomeReport(DateTime start, DateTime end) async {
    final response = await _client
        .from('payments')
        .select('amount, type')
        .gte('date', start.toIso8601String())
        .lte('date', end.toIso8601String());
    
    double total = 0;
    double cash = 0;
    double card = 0;
    double transfer = 0;

    for (var item in (response as List)) {
      final amount = (item['amount'] as num).toDouble();
      final type = item['type'] as String;
      
      total += amount;
      if (type == 'cash') cash += amount;
      else if (type == 'credit_card') card += amount;
      else if (type == 'transfer') transfer += amount;
    }

    return {
      'total': total,
      'cash': cash,
      'card': card,
      'transfer': transfer,
    };
  }

  // Delete
  Future<void> delete(String id) async {
    await _client.from('payments').delete().eq('id', id);
  }
}
