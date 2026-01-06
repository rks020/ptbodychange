import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/measurement.dart';
import '../../../shared/widgets/glass_card.dart';

class MeasurementComparisonScreen extends StatelessWidget {
  final Measurement oldMeasurement;
  final Measurement newMeasurement;

  const MeasurementComparisonScreen({
    super.key,
    required this.oldMeasurement,
    required this.newMeasurement,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ölçüm Karşılaştırma'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.primaryYellow,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Dates Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Eski Ölçüm',
                        style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy', 'tr_TR').format(oldMeasurement.date),
                        style: AppTextStyles.callout.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: AppColors.primaryYellow),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Yeni Ölçüm',
                        style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy', 'tr_TR').format(newMeasurement.date),
                        style: AppTextStyles.callout.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Basic Stats Comparison
            Text('Temel Bilgiler', style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow)),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                children: [
                  _buildComparisonRow(
                    'Kilo',
                    oldMeasurement.weight,
                    newMeasurement.weight,
                    'kg',
                    reverseLogic: true, // Loss is good
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _buildComparisonRow(
                    'Yağ Oranı',
                    oldMeasurement.bodyFatPercentage,
                    newMeasurement.bodyFatPercentage,
                    '%',
                    reverseLogic: true, // Loss is good
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _buildComparisonRow(
                    'BMI',
                    oldMeasurement.bmi,
                    newMeasurement.bmi,
                    '',
                    reverseLogic: true,
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _buildComparisonRow(
                    'Su',
                    oldMeasurement.waterPercentage,
                    newMeasurement.waterPercentage,
                    '%',
                    reverseLogic: false, // Increase is good
                  ),
                   _buildComparisonRow(
                    'Kemik',
                    oldMeasurement.boneMass,
                    newMeasurement.boneMass,
                    'kg',
                    reverseLogic: false, // Increase is good
                  ),
                  const Divider(color: AppColors.glassBorder),
                  _buildComparisonRow(
                    'Visceral',
                    oldMeasurement.visceralFatRating,
                    newMeasurement.visceralFatRating,
                    '',
                    reverseLogic: true, // Decrease is good
                  ),
                   _buildComparisonRow(
                    'Met. Yaş',
                    oldMeasurement.metabolicAge != null ? oldMeasurement.metabolicAge!.toDouble() : null,
                    newMeasurement.metabolicAge != null ? newMeasurement.metabolicAge!.toDouble() : null,
                    '',
                    reverseLogic: true, // Decrease is good
                  ),
                   _buildComparisonRow(
                    'BMR',
                    oldMeasurement.basalMetabolicRate != null ? oldMeasurement.basalMetabolicRate!.toDouble() : null,
                    newMeasurement.basalMetabolicRate != null ? newMeasurement.basalMetabolicRate!.toDouble() : null,
                    'kcal',
                    reverseLogic: false, // Increase is good
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            Text('Çevre Ölçümleri', style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow)),
            const SizedBox(height: 12),
             GlassCard(
              child: Column(
                children: [
                  _buildComparisonRow('Göğüs', oldMeasurement.chest, newMeasurement.chest, 'cm', reverseLogic: false),
                  _buildComparisonRow('Bel', oldMeasurement.waist, newMeasurement.waist, 'cm', reverseLogic: true),
                  _buildComparisonRow('Kalça', oldMeasurement.hips, newMeasurement.hips, 'cm', reverseLogic: true),
                  const Divider(color: AppColors.glassBorder),
                  _buildComparisonRow('Sol Kol', oldMeasurement.leftArm, newMeasurement.leftArm, 'cm'),
                  _buildComparisonRow('Sağ Kol', oldMeasurement.rightArm, newMeasurement.rightArm, 'cm'),
                  const Divider(color: AppColors.glassBorder),
                  _buildComparisonRow('Sol Bacak', oldMeasurement.leftThigh, newMeasurement.leftThigh, 'cm'),
                  _buildComparisonRow('Sağ Bacak', oldMeasurement.rightThigh, newMeasurement.rightThigh, 'cm'),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text('Fotoğraflar', style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow)),
            const SizedBox(height: 12),
            _buildPhotoComparison('Ön', oldMeasurement.frontPhotoUrl, newMeasurement.frontPhotoUrl),
            const SizedBox(height: 16),
            _buildPhotoComparison('Yan', oldMeasurement.sidePhotoUrl, newMeasurement.sidePhotoUrl),
            const SizedBox(height: 16),
            _buildPhotoComparison('Arka', oldMeasurement.backPhotoUrl, newMeasurement.backPhotoUrl),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String label, double? oldVal, double? newVal, String unit, {bool reverseLogic = false}) {
    if (oldVal == null || newVal == null) return const SizedBox.shrink();

    final diff = newVal - oldVal;
    
    // Determine color
    Color color;
    if (diff == 0) {
      color = AppColors.primaryYellow;
    } else {
      bool isGood = (reverseLogic && diff < 0) || (!reverseLogic && diff > 0);
      color = isGood ? AppColors.accentGreen : AppColors.accentRed;
    }

    final icon = diff > 0 
        ? Icons.arrow_drop_up_rounded 
        : (diff < 0 ? Icons.arrow_drop_down_rounded : Icons.remove_rounded);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(flex: 2, child: Text(label, style: AppTextStyles.body)),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${newVal.toStringAsFixed(1)} $unit', 
                      style: AppTextStyles.headline.copyWith(fontSize: 16),
                    ),
                    Text(
                      '${oldVal.toStringAsFixed(1)} $unit', 
                      style: AppTextStyles.caption2.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 70,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 2),
                Text(
                  diff.abs().toStringAsFixed(1),
                  style: AppTextStyles.caption1.copyWith(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoComparison(String label, String? oldUrl, String? newUrl) {
    if (oldUrl == null && newUrl == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.callout),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 3/4,
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: oldUrl != null
                      ? Image.network(oldUrl, fit: BoxFit.cover)
                      : const Center(child: Text('Fotoğraf yok', style: TextStyle(color: Colors.white54))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AspectRatio(
                aspectRatio: 3/4,
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: newUrl != null
                      ? Image.network(newUrl, fit: BoxFit.cover)
                      : const Center(child: Text('Fotoğraf yok', style: TextStyle(color: Colors.white54))),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
