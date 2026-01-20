import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../models/diet_model.dart';
import '../repositories/diet_repository.dart';
import 'dart:async';

class MemberDietScreen extends StatefulWidget {
  const MemberDietScreen({super.key});

  @override
  State<MemberDietScreen> createState() => _MemberDietScreenState();
}

class _MemberDietScreenState extends State<MemberDietScreen> {
  final _repository = DietRepository();
  bool _isLoading = true;
  Diet? _activeDiet;

  StreamSubscription? _dietSubscription;

  @override
  void initState() {
    super.initState();
    _loadDiet();
    _subscribeToDiet();
  }

  @override
  void dispose() {
    _dietSubscription?.cancel();
    super.dispose();
  }

  Future<void> _subscribeToDiet() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _dietSubscription = Supabase.instance.client
        .from('diets')
        .stream(primaryKey: ['id'])
        .eq('member_id', user.id)
        .listen((data) {
          _loadDiet();
        });
  }

  Future<void> _loadDiet() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final diet = await _repository.getActiveDiet(user.id);
      if (mounted) {
        setState(() {
          _activeDiet = diet;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading diet: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_activeDiet == null) {
      return RefreshIndicator(
        onRefresh: _loadDiet,
        color: AppColors.primaryYellow,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_rounded, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'Henüz atanmış bir beslenme programınız yok.',
              style: AppTextStyles.headline.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadDiet,
        color: AppColors.primaryYellow,
        backgroundColor: AppColors.surfaceDark,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Beslenme Programım',
                  style: AppTextStyles.title1.copyWith(fontWeight: FontWeight.bold),
                ),
                Icon(Icons.restaurant_rounded, color: AppColors.primaryYellow, size: 28),
              ],
            ),
            
            if (_activeDiet!.notes != null && _activeDiet!.notes!.isNotEmpty) ...[
              const SizedBox(height: 20),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.accentBlue, size: 20),
                        const SizedBox(width: 8),
                        Text('Notlar', style: AppTextStyles.headline.copyWith(color: AppColors.accentBlue)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _activeDiet!.notes!,
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            
            // Meals List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activeDiet!.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = _activeDiet!.items[index];
                return _buildMealCard(item);
              },
            ),
            
            const SizedBox(height: 20),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Günlük Toplam Kalori', style: AppTextStyles.headline),
                  Text(
                    '${_activeDiet!.totalCalories} kcal',
                     style: AppTextStyles.title1.copyWith(color: AppColors.primaryYellow, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
             const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMealCard(DietItem item) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.mealName,
                style: AppTextStyles.headline.copyWith(
                  color: AppColors.primaryYellow,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (item.calories != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Text(
                    '${item.calories} kcal',
                    style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.content,
            style: AppTextStyles.body.copyWith(height: 1.5, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
