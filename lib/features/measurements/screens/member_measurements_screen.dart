import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/measurement.dart';
import '../../../data/models/member.dart';
import '../../../data/repositories/measurement_repository.dart';
import '../../../shared/widgets/glass_card.dart';
import 'add_measurement_screen.dart';
import 'measurement_comparison_screen.dart';
import 'measurement_detail_screen.dart';

class MemberMeasurementsScreen extends StatefulWidget {
  final Member member;

  const MemberMeasurementsScreen({
    super.key,
    required this.member,
  });

  @override
  State<MemberMeasurementsScreen> createState() => _MemberMeasurementsScreenState();
}

class _MemberMeasurementsScreenState extends State<MemberMeasurementsScreen> {
  final _repository = MeasurementRepository();
  List<Measurement>? _measurements;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
  }

  Future<void> _loadMeasurements() async {
    setState(() => _isLoading = true);
    try {
      final measurements = await _repository.getByMemberId(widget.member.id);
      if (mounted) {
        setState(() {
          _measurements = measurements;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  final Set<String> _selectedMeasurementIds = {};
  bool _isSelectionMode = false;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedMeasurementIds.contains(id)) {
        _selectedMeasurementIds.remove(id);
      } else {
        if (_selectedMeasurementIds.length >= 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('En fazla 2 ölçüm seçebilirsiniz')),
          );
          return;
        }
        _selectedMeasurementIds.add(id);
      }
      
      _isSelectionMode = _selectedMeasurementIds.isNotEmpty;
    });
  }

  void _startComparison() {
    if (_selectedMeasurementIds.length != 2) return;
    
    final selected = _measurements!.where((m) => _selectedMeasurementIds.contains(m.id)).toList();
    // Sort by date to know which is old/new
    selected.sort((a, b) => a.date.compareTo(b.date));
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MeasurementComparisonScreen(
          oldMeasurement: selected[0],
          newMeasurement: selected[1],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode 
            ? '${_selectedMeasurementIds.length} Seçildi' 
            : '${widget.member.name} Ölçümleri'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(_isSelectionMode ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded),
          color: AppColors.primaryYellow,
          onPressed: () {
            if (_isSelectionMode) {
              setState(() {
                _selectedMeasurementIds.clear();
                _isSelectionMode = false;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (!_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              color: AppColors.primaryYellow,
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => AddMeasurementScreen(member: widget.member),
                  ),
                );
                if (result == true) {
                  _loadMeasurements();
                }
              },
            ),
          if (_isSelectionMode && _selectedMeasurementIds.length == 2)
            TextButton.icon(
              onPressed: _startComparison,
              icon: const Icon(Icons.compare_arrows_rounded, color: AppColors.primaryYellow),
              label: const Text('Karşılaştır', style: TextStyle(color: AppColors.primaryYellow, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      floatingActionButton: _isSelectionMode && _selectedMeasurementIds.length == 2
          ? FloatingActionButton.extended(
              onPressed: _startComparison,
              backgroundColor: AppColors.primaryYellow,
              label: const Text('Karşılaştır', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              icon: const Icon(Icons.compare_arrows_rounded, color: Colors.black),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow))
          : _measurements == null || _measurements!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.straighten_rounded, size: 64, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      Text(
                        'Henüz ölçüm eklenmemiş',
                        style: AppTextStyles.headline.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _measurements!.length,
                  itemBuilder: (context, index) {
                    final measurement = _measurements![index];
                    final dateStr = DateFormat('dd MMMM yyyy', 'tr_TR').format(measurement.date);
                    final isSelected = _selectedMeasurementIds.contains(measurement.id);
                    
                    return GestureDetector(
                      onTap: () async {
                        if (_isSelectionMode) {
                          _toggleSelection(measurement.id!);
                        } else {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => MeasurementDetailScreen(
                                measurement: measurement,
                                member: widget.member,
                              ),
                            ),
                          );
                          if (result == true) {
                            _loadMeasurements();
                          }
                        }
                      },
                      onLongPress: () {
                        _toggleSelection(measurement.id!);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassCard(
                          border: isSelected ? Border.all(color: AppColors.primaryYellow, width: 2) : null,
                          child: Row(
                            children: [
                              // Selection Checkbox
                              if (_isSelectionMode)
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    color: isSelected ? AppColors.primaryYellow : AppColors.textSecondary,
                                  ),
                                ),

                              // Photo Thumbnail or Placeholder
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceDark,
                                  borderRadius: BorderRadius.circular(10),
                                  image: measurement.frontPhotoUrl != null
                                      ? DecorationImage(
                                          image: NetworkImage(measurement.frontPhotoUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: measurement.frontPhotoUrl == null
                                    ? const Icon(Icons.person, color: AppColors.textSecondary)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dateStr,
                                      style: AppTextStyles.headline.copyWith(fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        _buildMetricBadge('Kilo', '${measurement.weight} kg'),
                                        if (measurement.bodyFatPercentage != null) ...[
                                          const SizedBox(width: 8),
                                          _buildMetricBadge('Yağ', '%${measurement.bodyFatPercentage}'),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              if (!_isSelectionMode)
                                const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildMetricBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryYellow.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: AppTextStyles.caption1.copyWith(
              color: AppColors.primaryYellow,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.caption1.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
