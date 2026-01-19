import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../members/screens/member_schedule_screen.dart';
import '../../diets/screens/member_diet_screen.dart';
import '../../measurements/screens/member_measurements_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../chat/screens/chat_screen.dart';
import '../../../data/models/profile.dart';
import '../../../shared/widgets/custom_snackbar.dart';

class MemberDashboardScreen extends StatefulWidget {
  const MemberDashboardScreen({super.key});

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen> {
  int _currentIndex = 0;
  final _supabase = Supabase.instance.client;

  // Tabs
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const MemberScheduleScreen(),      // Tab 0
      const MemberDietScreen(),          // Tab 1 (New)
      const MemberMeasurementsScreen(),  // Tab 2
      const ProfileScreen(),             // Tab 3
    ];
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _handleChatPress() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Fetch Member info to get trainer_id
      final memberData = await _supabase
          .from('members')
          .select('trainer_id')
          .eq('id', user.id) // Assuming members.id = auth.id
          .maybeSingle();

      if (memberData == null) {
        if (mounted) CustomSnackBar.showError(context, 'Üye kaydı bulunamadı.');
        return;
      }

      final trainerId = memberData['trainer_id'];

      if (trainerId == null) {
        if (mounted) CustomSnackBar.showError(context, 'Henüz bir antrenör atanmamış.');
        return;
      }

      // 2. Fetch Trainer Profile
      final trainerProfileData = await _supabase
          .from('profiles')
          .select()
          .eq('id', trainerId)
          .single();

      final trainerProfile = Profile.fromSupabase(trainerProfileData);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(otherUser: trainerProfile),
          ),
        );
      }
    } catch (e) {
      if (mounted) CustomSnackBar.showError(context, 'Chat başlatılamadı: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // For transparent bottom bar effect if needed
      body: AmbientBackground( // Ensure background is consistent at root
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleChatPress,
        backgroundColor: AppColors.primaryYellow,
        child: const Icon(Icons.chat_bubble_outline, color: Colors.black),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withOpacity(0.9),
          border: const Border(top: BorderSide(color: AppColors.glassBorder, width: 0.5)),
          boxShadow: [
             BoxShadow(
               color: Colors.black.withOpacity(0.3),
               blurRadius: 10,
               offset: const Offset(0, -5),
             )
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, 'Programım', Icons.calendar_today_rounded),
                _buildNavItem(1, 'Beslenme', Icons.restaurant_menu_rounded),
                _buildNavItem(2, 'Gelişimim', Icons.show_chart_rounded),
                _buildNavItem(3, 'Profil', Icons.person_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected 
            ? BoxDecoration(
                color: AppColors.primaryYellow.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaryYellow : Colors.grey,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primaryYellow,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
