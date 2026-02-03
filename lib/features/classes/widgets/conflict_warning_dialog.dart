import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_button.dart';

enum ConflictAction { modifyTime, skip, cancel, acceptAlternative, proceedAnyway }

class ConflictWarningDialog extends StatelessWidget {
  final List<Map<String, dynamic>> conflicts;
  final DateTime proposedStartTime;
  final DateTime proposedEndTime;
  final DateTime? alternativeStartTime;
  final DateTime? alternativeEndTime;

  const ConflictWarningDialog({
    super.key,
    required this.conflicts,
    required this.proposedStartTime,
    required this.proposedEndTime,
    this.alternativeStartTime,
    this.alternativeEndTime,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.accentOrange,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Program Çakışması',
                        style:AppTextStyles.headline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Proposed time
                Text(
                  'Seçilen Saat:',
                  style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('HH:mm').format(proposedStartTime)} - ${DateFormat('HH:mm').format(proposedEndTime)}',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentRed,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                
                if (alternativeStartTime != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Önerilen Alternatif:',
                    style: AppTextStyles.caption1.copyWith(color: AppColors.accentGreen),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accentGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 16, color: AppColors.accentGreen),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('HH:mm').format(alternativeStartTime!)} - ${DateFormat('HH:mm').format(alternativeEndTime!)}',
                          style: AppTextStyles.headline.copyWith(color: AppColors.accentGreen),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 20),

                // Conflicts list
                Text(
                  'Çakışan Dersler:',
                  style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: conflicts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final conflict = conflicts[index];
                      return _buildConflictItem(conflict);
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons (Fixed Layout)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (alternativeStartTime != null) ...[
                      CustomButton(
                        text: 'Alternatifi Kabul Et',
                        onPressed: () => Navigator.pop(context, ConflictAction.acceptAlternative),
                        backgroundColor: AppColors.accentGreen,
                        foregroundColor: Colors.white,
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    CustomButton(
                      text: 'Yine de Ekle',
                      onPressed: () => Navigator.pop(context, ConflictAction.proceedAnyway),
                      backgroundColor: AppColors.accentOrange,
                      foregroundColor: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    
                    CustomButton(
                      text: 'Farklı Saat Seç',
                      onPressed: () => Navigator.pop(context, ConflictAction.modifyTime),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Atla',
                            onPressed: () => Navigator.pop(context, ConflictAction.skip),
                            isOutlined: true,
                            foregroundColor: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomButton(
                            text: 'İptal',
                            onPressed: () => Navigator.pop(context, ConflictAction.cancel),
                            isOutlined: true,
                            foregroundColor: AppColors.accentRed,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConflictItem(Map<String, dynamic> conflict) {
    final title = conflict['title'] as String;
    final startTime = DateTime.parse(conflict['start_time'] as String).toUtc().toLocal();
    final endTime = DateTime.parse(conflict['end_time'] as String).toUtc().toLocal();
    
    // Get trainer name
    final trainerProfile = conflict['profiles'] as Map<String, dynamic>?;
    final trainerName = trainerProfile != null
        ? '${trainerProfile['first_name'] ?? ''} ${trainerProfile['last_name'] ?? ''}'.trim()
        : 'Bilinmeyen Antrenör';

    // Get enrolled members
    final enrollments = conflict['class_enrollments'] as List<dynamic>? ?? [];
    final memberNames = enrollments.map((e) {
      final member = e['members'] as Map<String, dynamic>?;
      return member?['name'] as String? ?? 'Bilinmeyen';
    }).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accentOrange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${DateFormat('EEEE, d MMMM', 'tr_TR').format(startTime)}',
            style: AppTextStyles.caption1.copyWith(
              color: AppColors.accentOrange,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${DateFormat('HH:mm').format(startTime)} - ${DateFormat('HH:mm').format(endTime)}',
            style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                'Antrenör: $trainerName',
                style: AppTextStyles.caption1,
              ),
            ],
          ),
          if (memberNames.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.group, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Üyeler: ${memberNames.join(', ')}',
                    style: AppTextStyles.caption1,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
