import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../data/models/member.dart';
import '../../../data/models/measurement.dart';
import '../../../data/repositories/member_repository.dart';
import '../../../shared/widgets/custom_button.dart';
import 'progress_charts_screen.dart';
import 'measurement_comparison_screen.dart';

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
  final Set<int> _selectedIndices = {};
  bool _isSelectionMode = false;
  Member? _member;

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
    _loadMember();
  }

  Future<void> _loadMember() async {
    if (widget.memberId == null) return;
    
    try {
      final member = await MemberRepository().getById(widget.memberId!);
      if (mounted) {
        setState(() {
          _member = member;
        });
      }
    } catch (e) {
      debugPrint('Error loading member: $e');
    }
  }

  Future<void> _loadMeasurements() async {
    try {
      final targetUserId = widget.memberId ?? _supabase.auth.currentUser?.id;
      if (targetUserId == null) return;

      final response = await _supabase
          .from('measurements')
          .select()
          .eq('member_id', targetUserId)
          .order('measurement_date', ascending: true); // Ascending for Chart

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

  Future<void> _openDetailedAnalysis() async {
    try {
      final user = _supabase.auth.currentUser;
      final targetId = widget.memberId ?? user?.id;
      
      if (targetId == null) return;

      final member = await MemberRepository().getById(targetId);
      
      if (member != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProgressChartsScreen(member: member),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
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

    final String title = widget.memberId != null && _member != null
        ? '${_member!.name} Ölçümleri'
        : 'Gelişim Analizim';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        leading: widget.memberId != null 
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            )
          : null,
        actions: widget.memberId == null
          ? [
              TextButton.icon(
                onPressed: _openDetailedAnalysis,
                icon: const Icon(Icons.analytics_outlined, color: AppColors.primaryYellow, size: 20),
                label: const Text('Detaylı Analiz', style: TextStyle(color: AppColors.primaryYellow, fontSize: 12)),
              ),
            ]
          : null,
      ),
      body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            
            // Weight Chart - only show for members viewing their own
            if (widget.memberId == null && weightSpots.isNotEmpty)
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
               ),

            const SizedBox(height: 24),
            
            // Selection mode header
            if (_isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedIndices.clear();
                        });
                      },
                    ),
                    Text(
                      '${_selectedIndices.length} Seçildi',
                      style: AppTextStyles.headline,
                    ),
                    TextButton.icon(
                      onPressed: _selectedIndices.length == 2 ? () {
                        final indices = _selectedIndices.toList()..sort();
                        final m1 = Measurement.fromSupabaseMap(_measurements[indices[0]]);
                        final m2 = Measurement.fromSupabaseMap(_measurements[indices[1]]);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MeasurementComparisonScreen(
                              oldMeasurement: m1,
                              newMeasurement: m2,
                            ),
                          ),
                        );
                      } : null,
                      icon: const Icon(Icons.compare_arrows, color: AppColors.primaryYellow),
                      label: const Text('Karşılaştır', style: TextStyle(color: AppColors.primaryYellow)),
                    ),
                  ],
                ),
              ),
            
            Text('Ölçüm Geçmişi', style: AppTextStyles.title3),
            const SizedBox(height: 12),
            
            // History List
            Expanded(
              child: _measurements.isEmpty 
               ? Container()
               : Stack(
                  children: [
                    ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _measurements.length,
                      itemBuilder: (context, index) {
                        final currentIdx = _measurements.length - 1 - index;
                        final m = _measurements[currentIdx];
                        final date = DateTime.parse(m['measurement_date']);
                        final isSelected = _selectedIndices.contains(currentIdx);
                        
                        return GlassCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          onTap: () {
                            if (_isSelectionMode) {
                              setState(() {
                                if (isSelected) {
                                  _selectedIndices.remove(currentIdx);
                                  if (_selectedIndices.isEmpty) {
                                    _isSelectionMode = false;
                                  }
                                } else {
                                  if (_selectedIndices.length < 2) {
                                    _selectedIndices.add(currentIdx);
                                  }
                                }
                              });
                            } else {
                              setState(() {
                                _isSelectionMode = true;
                                _selectedIndices.add(currentIdx);
                              });
                            }
                          },
                          backgroundColor: isSelected ? AppColors.primaryYellow.withOpacity(0.15) : null,
                          border: isSelected ? Border.all(color: AppColors.primaryYellow, width: 2) : null,
                          child: Row(
                            children: [
                              // Selection indicator
                              if (_isSelectionMode)
                                Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  child: Icon(
                                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                                    color: isSelected ? AppColors.primaryYellow : Colors.white54,
                                    size: 24,
                                  ),
                                ),
                              
                              // Profile icon
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceDark,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.person, color: Colors.white54, size: 20),
                              ),
                              
                              const SizedBox(width: 12),
                              
                              // Date and metrics
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('dd MMMM yyyy', 'tr_TR').format(date),
                                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryYellow.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Kilo: ${m['weight'] ?? '-'} kg',
                                            style: const TextStyle(
                                              color: AppColors.primaryYellow,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Yağ: %${m['body_fat_percentage'] ?? '-'}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Arrow icon
                              if (!_isSelectionMode)
                                const Icon(Icons.chevron_right, color: Colors.white54),
                            ],
                          ),
                        );
                      },
                    ),
                    
                    // FAB for comparison
                    if (_selectedIndices.length == 2)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: FloatingActionButton.extended(
                          onPressed: () {
                            final indices = _selectedIndices.toList()..sort();
                            final m1 = Measurement.fromSupabaseMap(_measurements[indices[0]]);
                            final m2 = Measurement.fromSupabaseMap(_measurements[indices[1]]);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MeasurementComparisonScreen(
                                  oldMeasurement: m1,
                                  newMeasurement: m2,
                                ),
                              ),
                            );
                          },
                          backgroundColor: AppColors.primaryYellow,
                          icon: const Icon(Icons.compare_arrows, color: Colors.black),
                          label: const Text('Karşılaştır', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
