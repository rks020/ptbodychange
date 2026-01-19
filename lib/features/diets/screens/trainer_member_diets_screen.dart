
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../shared/widgets/ambient_background.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_snackbar.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../models/diet_model.dart';
import '../repositories/diet_repository.dart';
import 'create_diet_screen.dart';

class TrainerMemberDietsScreen extends StatefulWidget {
  final String memberId;
  final String memberName;

  const TrainerMemberDietsScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });

  @override
  State<TrainerMemberDietsScreen> createState() => _TrainerMemberDietsScreenState();
}

class _TrainerMemberDietsScreenState extends State<TrainerMemberDietsScreen> {
  final _repository = DietRepository();
  bool _isLoading = true;
  List<Diet> _diets = [];

  @override
  void initState() {
    super.initState();
    _loadDiets();
  }

  Future<void> _loadDiets() async {
    setState(() => _isLoading = true);
    try {
      final diets = await _repository.getMemberDiets(widget.memberId);
      if (mounted) {
        setState(() {
          _diets = diets;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Diyetler yüklenirken hata oluştu: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteDiet(String dietId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text('Diyeti Sil', style: AppTextStyles.title3),
        content: Text('Bu diyet programını silmek istediğinize emin misiniz?', style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('İptal', style: AppTextStyles.callout),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accentRed),
            child: Text('Sil', style: AppTextStyles.callout),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repository.deleteDiet(dietId);
        _loadDiets(); // Reload
        if (mounted) CustomSnackBar.showSuccess(context, 'Diyet silindi.');
      } catch (e) {
        if (mounted) CustomSnackBar.showError(context, 'Silme işlemi başarısız: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('${widget.memberName} - Diyetler', style: AppTextStyles.headline),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _diets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.restaurant_menu_rounded, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
                                const SizedBox(height: 16),
                                Text(
                                  'Henüz bir diyet programı oluşturulmamış.',
                                  style: AppTextStyles.headline.copyWith(color: AppColors.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(20),
                            itemCount: _diets.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final diet = _diets[index];
                              return _buildDietCard(diet);
                            },
                          ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: CustomButton(
                  text: 'Yeni Diyet Programı Ekle',
                  icon: Icons.add,
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateDietScreen(
                          memberId: widget.memberId,
                          memberName: widget.memberName,
                        ),
                      ),
                    );
                    if (result == true) {
                      _loadDiets();
                    }
                  },
                  backgroundColor: AppColors.primaryYellow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDietCard(Diet diet) {
    return Dismissible(
      key: Key(diet.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {}, // Handled by confirmDismiss
      confirmDismiss: (_) async {
        await _deleteDiet(diet.id);
        return false; // We reload the list manually instead of using Dismissible's remove logic which can be tricky with async list updates
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: ExpansionTile(
          shape: Border.all(color: Colors.transparent),
          collapsedShape: Border.all(color: Colors.transparent),
          tilePadding: EdgeInsets.zero,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Oluşturulma: ${DateFormat('dd MMM yyyy HH:mm', 'tr_TR').format(diet.createdAt)}',
                style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                diet.notes != null && diet.notes!.isNotEmpty ? diet.notes! : 'Not yok',
                style: AppTextStyles.body.copyWith(
                  fontStyle: diet.notes == null || diet.notes!.isEmpty ? FontStyle.italic : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          children: [
            const Divider(color: AppColors.glassBorder),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: diet.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = diet.items[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.mealName,
                        style: AppTextStyles.caption1.copyWith(color: AppColors.primaryYellow, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.content, style: AppTextStyles.body),
                          if (item.calories != null)
                            Text('${item.calories} kcal', style: AppTextStyles.caption2.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const Divider(color: AppColors.glassBorder),
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                   Text(
                    'Toplam:',
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${diet.totalCalories} kcal',
                    style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
