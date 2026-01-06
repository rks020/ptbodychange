import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/measurement.dart';
import '../../../data/models/member.dart';
import '../../../data/repositories/measurement_repository.dart';
import '../../../shared/widgets/glass_card.dart';

class ProgressChartsScreen extends StatefulWidget {
  final Member member;

  const ProgressChartsScreen({
    super.key,
    required this.member,
  });

  @override
  State<ProgressChartsScreen> createState() => _ProgressChartsScreenState();
}

class _ProgressChartsScreenState extends State<ProgressChartsScreen> {
  final _repository = MeasurementRepository();
  List<Measurement> _measurements = [];
  bool _isLoading = true;
  String _selectedMetric = 'Kilo';
  
  final Map<String, String> _metricLabels = {
    'Kilo': 'weight',
    'Yağ Oranı': 'bodyFat',
    'Su (%)': 'water',
    'Kemik (kg)': 'bone',
    'Visceral': 'visceral',
    'Metabolik Yaş': 'metabolicAge',
    'BMR': 'bmr',
    'Göğüs': 'chest',
    'Bel': 'waist',
    'Kalça': 'hips',
    'Sol Kol': 'leftArm',
    'Sağ Kol': 'rightArm',
    'Sol Bacak': 'leftThigh',
    'Sağ Bacak': 'rightThigh',
  };

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
  }

  Future<void> _loadMeasurements() async {
    try {
      final data = await _repository.getByMemberId(widget.member.id);
      // Sort by date ascending for charts
      data.sort((a, b) => a.date.compareTo(b.date));
      
      setState(() {
        _measurements = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  double? _getValue(Measurement m, String metricKey) {
    switch (metricKey) {
      case 'weight': return m.weight;
      case 'bodyFat': return m.bodyFatPercentage;
      case 'water': return m.waterPercentage;
      case 'bone': return m.boneMass;
      case 'visceral': return m.visceralFatRating;
      case 'metabolicAge': return m.metabolicAge?.toDouble();
      case 'bmr': return m.basalMetabolicRate?.toDouble();
      case 'chest': return m.chest;
      case 'waist': return m.waist;
      case 'hips': return m.hips;
      case 'leftArm': return m.leftArm;
      case 'rightArm': return m.rightArm;
      case 'leftThigh': return m.leftThigh;
      case 'rightThigh': return m.rightThigh;
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gelişim Grafikleri'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.primaryYellow,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow))
          : _measurements.isEmpty 
              ? Center(
                  child: Text(
                    'Henüz ölçüm kaydı yok', 
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      // Metric Selector
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _metricLabels.keys.map((label) {
                            final isSelected = _selectedMetric == label;
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: ChoiceChip(
                                label: Text(label),
                                selected: isSelected,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _selectedMetric = label);
                                  }
                                },
                                selectedColor: AppColors.primaryYellow,
                                backgroundColor: AppColors.surfaceDark,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Progress Summary
                      if (_measurements.length >= 2)
                        _buildProgressSummary(),
                      
                      const SizedBox(height: 24),
                      
                      // Chart
                      Expanded(
                        child: GlassCard(
                          padding: const EdgeInsets.all(24),
                          child: LineChart(
                            _buildChartData(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  LineChartData _buildChartData() {
    final metricKey = _metricLabels[_selectedMetric]!;
    
    // Create spots from measurements
    final spots = <FlSpot>[];
    double? minY, maxY;

    for (int i = 0; i < _measurements.length; i++) {
      final val = _getValue(_measurements[i], metricKey);
      if (val != null) {
        spots.add(FlSpot(i.toDouble(), val));
        
        if (minY == null || val < minY) minY = val;
        if (maxY == null || val > maxY) maxY = val;
      }
    }

    // Add some buffer to Y-axis
    if (minY != null) minY = (minY * 0.9).floorToDouble();
    if (maxY != null) maxY = (maxY * 1.1).ceilToDouble();
    
    // Default range if no data
    minY ??= 0;
    maxY ??= 100;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        getDrawingHorizontalLine: (value) => FlLine(
          color: AppColors.glassBorder.withOpacity(0.3),
          strokeWidth: 1,
        ),
        getDrawingVerticalLine: (value) => FlLine(
          color: AppColors.glassBorder.withOpacity(0.3),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1, // Show every point's date if possible, or adjust
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index >= 0 && index < _measurements.length) {
                final date = _measurements[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    DateFormat('dd/MM', 'tr_TR').format(date),
                    style: AppTextStyles.caption2.copyWith(fontSize: 10),
                  ),
                );
              }
              return const Text('');
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: AppTextStyles.caption2,
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (_measurements.length - 1).toDouble(),
      minY: minY,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.primaryYellow,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.primaryYellow.withOpacity(0.1),
            gradient: LinearGradient(
              colors: [
                AppColors.primaryYellow.withOpacity(0.3),
                AppColors.primaryYellow.withOpacity(0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          // tooltipBgColor: AppColors.surfaceDark,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((LineBarSpot touchedSpot) {
              return LineTooltipItem(
                '${touchedSpot.y}\n${DateFormat('dd MMM yyyy', 'tr_TR').format(_measurements[touchedSpot.x.toInt()].date)}',
                const TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildProgressSummary() {
    final metricKey = _metricLabels[_selectedMetric]!;
    final first = _getValue(_measurements.first, metricKey);
    final last = _getValue(_measurements.last, metricKey);

    if (first == null || last == null) return const SizedBox.shrink();

    final diff = last - first;
    final percentage = (diff / first) * 100;
    
    // Determine color
    Color color;
    if (diff == 0) {
      color = AppColors.primaryYellow;
    } else {
      bool isDecreaseGood = ['weight', 'bodyFat', 'waist', 'hips', 'visceral', 'metabolicAge'].contains(metricKey);
      bool isGood = (isDecreaseGood && diff < 0) || (!isDecreaseGood && diff > 0);
      color = isGood ? AppColors.accentGreen : AppColors.accentRed;
    }
    
    final icon = diff > 0 
        ? Icons.trending_up_rounded 
        : (diff < 0 ? Icons.trending_down_rounded : Icons.trending_flat_rounded);

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Toplam Değişim',
                  style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)}',
                      style: AppTextStyles.title2.copyWith(color: color),
                    ),
                    const SizedBox(width: 8),
                    Icon(icon, color: color, size: 20),
                  ],
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${percentage > 0 ? '+' : ''}${percentage.toStringAsFixed(1)}%',
                style: AppTextStyles.headline.copyWith(color: color, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
