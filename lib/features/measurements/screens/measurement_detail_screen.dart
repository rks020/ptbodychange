import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/measurement.dart';
import '../../../data/models/member.dart';
import '../../../data/repositories/measurement_repository.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/glass_card.dart';

class MeasurementDetailScreen extends StatelessWidget {
  final Measurement measurement;
  final Member member;

  const MeasurementDetailScreen({
    super.key,
    required this.measurement,
    required this.member,
  });

  Future<void> _deleteMeasurement(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text('Ölçümü Sil', style: AppTextStyles.title3),
        content: Text(
          'Bu ölçüm kaydını silmek istediğinize emin misiniz?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('İptal', style: AppTextStyles.callout),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentRed,
            ),
            child: Text('Sil', style: AppTextStyles.callout),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await MeasurementRepository().delete(measurement.id!);
        // Also delete photos if needed, but repository might handle or we call deletePhoto separately
        // For simplicity, we just delete the record for now or let repository handle it.
        
        if (context.mounted) {
          CustomSnackBar.showSuccess(context, 'Ölçüm silindi');
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (context.mounted) {
          CustomSnackBar.showError(context, 'Hata oluştu: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(measurement.date);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ölçüm Detayı'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.primaryYellow,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_rounded),
            color: AppColors.accentRed,
            onPressed: () => _deleteMeasurement(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateStr, style: AppTextStyles.title2),
              const SizedBox(height: 24),

              // Photos Section
              if (measurement.frontPhotoUrl != null || 
                  measurement.sidePhotoUrl != null || 
                  measurement.backPhotoUrl != null) ...[
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    height: 300,
                    child: PageView(
                      children: [
                        if (measurement.frontPhotoUrl != null) 
                          _buildPhotoPage(measurement.frontPhotoUrl!, 'Ön'),
                        if (measurement.sidePhotoUrl != null) 
                          _buildPhotoPage(measurement.sidePhotoUrl!, 'Yan'),
                        if (measurement.backPhotoUrl != null) 
                          _buildPhotoPage(measurement.backPhotoUrl!, 'Arka'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Basic Stats
              Text('Temel Bilgiler', style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow)),
              const SizedBox(height: 12),
                GlassCard(
                  child: Wrap(
                    alignment: WrapAlignment.spaceAround,
                    runSpacing: 12,
                    spacing: 12,
                    children: [
                      _buildStatItem('Kilo', '${measurement.weight} kg'),
                      _buildStatItem('Boy', '${measurement.height} cm'),
                      if (measurement.age != null) _buildStatItem('Yaş', '${measurement.age}'),
                      _buildStatItem('BMI', measurement.bmi.toStringAsFixed(1)),
                      if (measurement.bodyFatPercentage != null)
                        _buildStatItem('Yağ', '%${measurement.bodyFatPercentage}'),
                      if (measurement.waterPercentage != null)
                        _buildStatItem('Su', '%${measurement.waterPercentage}'),
                      if (measurement.boneMass != null)
                        _buildStatItem('Kemik', '${measurement.boneMass} kg'),
                      if (measurement.visceralFatRating != null)
                        _buildStatItem('Visceral', '${measurement.visceralFatRating}'),
                      if (measurement.metabolicAge != null)
                        _buildStatItem('Met. Yaş', '${measurement.metabolicAge}'),
                      if (measurement.basalMetabolicRate != null)
                        _buildStatItem('BMR', '${measurement.basalMetabolicRate} kcal'),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
              // Circumferences
              Text('Çevre Ölçümleri', style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow)),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  children: [
                    if (measurement.chest != null) _buildRow('Göğüs', '${measurement.chest} cm'),
                    if (measurement.waist != null) _buildRow('Bel', '${measurement.waist} cm'),
                    if (measurement.hips != null) _buildRow('Kalça', '${measurement.hips} cm'),
                    const Divider(color: AppColors.glassBorder),
                    if (measurement.leftArm != null) _buildRow('Sol Kol', '${measurement.leftArm} cm'),
                    if (measurement.rightArm != null) _buildRow('Sağ Kol', '${measurement.rightArm} cm'),
                    const Divider(color: AppColors.glassBorder),
                    if (measurement.leftThigh != null) _buildRow('Sol Bacak', '${measurement.leftThigh} cm'),
                    if (measurement.rightThigh != null) _buildRow('Sağ Bacak', '${measurement.rightThigh} cm'),
                    // Calves removed
                  ],
                ),
              ),

              if (measurement.notes != null && measurement.notes!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Notlar', style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow)),
                const SizedBox(height: 12),
                GlassCard(
                  child: Text(measurement.notes!, style: AppTextStyles.body),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPage(String url, String label) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow));
          },
        ),
        Positioned(
          bottom: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: AppTextStyles.caption1.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.title3.copyWith(color: AppColors.accentGreen)),
        Text(label, style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body),
          Text(value, style: AppTextStyles.headline.copyWith(fontSize: 16)),
        ],
      ),
    );
  }
}
