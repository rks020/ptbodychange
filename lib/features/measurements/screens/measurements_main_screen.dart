import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/member.dart';
import '../../../data/repositories/member_repository.dart';
import '../../../shared/widgets/glass_card.dart';
import 'member_measurements_screen.dart';

class MeasurementsMainScreen extends StatefulWidget {
  const MeasurementsMainScreen({super.key});

  @override
  State<MeasurementsMainScreen> createState() => _MeasurementsMainScreenState();
}

class _MeasurementsMainScreenState extends State<MeasurementsMainScreen> {
  final MemberRepository _repository = MemberRepository();
  List<Member> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final members = await _repository.getMembersWithMeasurements();
      if (mounted) {
        setState(() {
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    'Ölçümler',
                    style: AppTextStyles.largeTitle,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryYellow),
                      ),
                    )
                  : _members.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: _members.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildMemberItem(_members[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberItem(Member member) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MemberMeasurementsScreen(member: member),
          ),
        );
      },
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cardDark,
                image: member.photoPath != null
                    ? DecorationImage(
                        image: NetworkImage(member.photoPath!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: member.photoPath == null
                  ? Center(
                      child: Text(
                        member.name[0].toUpperCase(),
                        style: AppTextStyles.headline.copyWith(
                          color: AppColors.primaryYellow,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: AppTextStyles.headline,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ölçüm Geçmişi',
                    style: AppTextStyles.caption1.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.straighten_rounded,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz ölçüm kaydı yok',
            style: AppTextStyles.headline.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Üye listesinden bir üye seçip "+" butonuna basarak ilk ölçümü ekleyebilirsiniz.',
              style: AppTextStyles.subheadline,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
