import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';

class MemberMeasurementsScreen extends StatefulWidget {
  final String? memberId; // Optional: If provided, viewing that member. If null, view key user.

  const MemberMeasurementsScreen({super.key, this.memberId});

  @override
  State<MemberMeasurementsScreen> createState() => _MemberMeasurementsScreenState();
}

class _MemberMeasurementsScreenState extends State<MemberMeasurementsScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _measurements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
  }

  Future<void> _loadMeasurements() async {
    try {
      final targetUserId = widget.memberId ?? _supabase.auth.currentUser?.id;
      if (targetUserId == null) return;

      final response = await _supabase
          .from('measurements')
          .select()
          .eq('member_id', targetUserId)
          .order('date', ascending: true); // Ascending for Chart

      if (mounted) {
        setState(() {
          _measurements = response as List;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading measurements: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Prepare data for chart (Weight progress)
    final weightSpots = _measurements.asMap().entries.map((entry) {
        final m = entry.value;
        final weight = (m['weight'] as num?)?.toDouble() ?? 0.0;
        return FlSpot(entry.key.toDouble(), weight);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gelişim Analizim',
              style: AppTextStyles.title1.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            // Weight Chart
            if (weightSpots.isNotEmpty)
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                   height: 200,
                   child: Column(
                     children: [
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                         children: [
                           Text('Kilo Değişimi', style: AppTextStyles.headline),
                           Icon(Icons.monitor_weight_rounded, color: AppColors.primaryYellow.withOpacity(0.5)),
                         ],
                       ),
                       const SizedBox(height: 16),
                       Expanded(
                         child: LineChart(
                           LineChartData(
                             gridData: FlGridData(show: false),
                             titlesData: FlTitlesData(show: false),
                             borderData: FlBorderData(show: false),
                             lineBarsData: [
                               LineChartBarData(
                                 spots: weightSpots,
                                 isCurved: true,
                                 color: AppColors.primaryYellow,
                                 barWidth: 3,
                                 dotData: FlDotData(show: true),
                                 belowBarData: BarAreaData(
                                   show: true,
                                   color: AppColors.primaryYellow.withOpacity(0.1),
                                 ),
                               ),
                             ],
                           ),
                         ),
                       ),
                     ],
                   ),
                ),
              )
            else
               const GlassCard(
                 padding: EdgeInsets.all(20),
                 child: Center(child: Text('Henüz ölçüm kaydı bulunmuyor.', style: TextStyle(color: Colors.white70))),
               ),

            const SizedBox(height: 24),
            Text('Ölçüm Geçmişi', style: AppTextStyles.title3),
            const SizedBox(height: 12),
            
            // History List
            Expanded(
              child: _measurements.isEmpty 
               ? Container()
               : ListView.builder(
                  itemCount: _measurements.length,
                  itemBuilder: (context, index) {
                    // Show latest first in list (reverse order of _measurements which is ASC)
                    final m = _measurements[_measurements.length - 1 - index];
                    final date = DateTime.parse(m['date']);
                    return GlassCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('d MMMM yyyy', 'tr_TR').format(date),
                                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Kilo: ${m['weight']} kg',
                                style: TextStyle(color: AppColors.primaryYellow),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Yağ: %${m['body_fat'] ?? '-'}', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text('Kas: ${m['muscle_mass'] ?? '-'} kg', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
