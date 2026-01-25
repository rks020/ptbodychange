import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../members/screens/member_schedule_screen.dart';
import '../../diets/screens/member_diet_screen.dart';
import '../../measurements/screens/member_measurements_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../chat/screens/inbox_screen.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/message_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../widgets/stat_card.dart';
import 'announcements_screen.dart';

class MemberDashboardScreen extends StatefulWidget {
  const MemberDashboardScreen({super.key});

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen> {
  int _currentIndex = 0;
  final _supabase = Supabase.instance.client;
  int _unreadCount = 0;

  // Tabs
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      _MemberHomeScreen(onTabChange: _onTabTapped), // Tab 0: Home
      const MemberScheduleScreen(),                 // Tab 1: Program
      const MemberDietScreen(),                     // Tab 2: Diet
      const MemberMeasurementsScreen(),             // Tab 3: Progress
      const ProfileScreen(),                        // Tab 4: Profile
    ];
    _loadUnreadCount();
    _setupRealtimeSubscription();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final repo = MessageRepository();
      final count = await repo.getUnreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (e) {
      debugPrint('Error loading unread count: $e');
    }
  }

  void _setupRealtimeSubscription() {
    _supabase.channel('member_dashboard_messages')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        callback: (payload) => _loadUnreadCount(),
      )
      .subscribe();
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AmbientBackground(
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      // Only show chat FAB on Home
      floatingActionButton: _currentIndex == 0 ? Stack(
        alignment: Alignment.topRight,
        children: [
          FloatingActionButton(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const InboxScreen()),
              );
              _loadUnreadCount();
            },
            backgroundColor: AppColors.primaryYellow,
            child: const Icon(Icons.chat_bubble_outline, color: Colors.black),
          ),
          if (_unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.accentRed,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ) : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E).withOpacity(0.95),
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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
               width: MediaQuery.of(context).size.width,
               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
               child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(0, 'Ana Sayfa', Icons.home_rounded),
                  _buildNavItem(1, 'Program', Icons.calendar_today_rounded),
                  _buildNavItem(2, 'Beslenme', Icons.restaurant_menu_rounded),
                  _buildNavItem(3, 'Gelişim', Icons.show_chart_rounded),
                  _buildNavItem(4, 'Profil', Icons.person_rounded),
                ],
              ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 12, vertical: 8),
        decoration: isSelected 
            ? BoxDecoration(
                color: AppColors.primaryYellow.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaryYellow : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primaryYellow : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberHomeScreen extends StatefulWidget {
  final Function(int) onTabChange;
  const _MemberHomeScreen({required this.onTabChange});

  @override
  State<_MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<_MemberHomeScreen> {
  Profile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ProfileRepository().getProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow));
    }

    final firstName = _profile?.firstName ?? '';
    final lastName = _profile?.lastName ?? '';
    final fullName = '$firstName $lastName'.trim();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoş Geldiniz,',
                      style: AppTextStyles.body.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fullName.isNotEmpty ? fullName : 'Sporcu',
                      style: AppTextStyles.title1.copyWith(color: Colors.white),
                    ),
                  ],
                ),
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryYellow, width: 2),
                    image: _profile?.avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(_profile!.avatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _profile?.avatarUrl == null
                      ? Center(
                          child: Text(
                            firstName.isNotEmpty ? firstName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: AppColors.primaryYellow,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            Text(
              'Hızlı Erişim',
              style: AppTextStyles.title3.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 16),

            // Cards Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                // Ders Programım
                StatCard(
                  title: 'Ders Programım',
                  value: 'Programı Gör',
                  icon: Icons.calendar_today_rounded,
                  color: const Color(0xFFFACC15), // Yellow
                  onTap: () => widget.onTabChange(1), // Tab 1: Schedule
                ),
                
                // Beslenme / Diyetim
                StatCard(
                  title: 'Diyetim',
                  value: 'Öğünler',
                  icon: Icons.restaurant_menu_rounded,
                  color: const Color(0xFFF472B6), // Pink/Red
                  onTap: () => widget.onTabChange(2), // Tab 2: Diet
                ),

                // Gelişimim
                StatCard(
                  title: 'Gelişimim',
                  value: 'İstatistikler',
                  icon: Icons.show_chart_rounded,
                  color: const Color(0xFF34D399), // Green
                  onTap: () => widget.onTabChange(3), // Tab 3: Measurements
                ),

                // Duyurular
                StatCard(
                  title: 'Duyurular',
                  value: 'Bildirimler',
                  icon: Icons.campaign_rounded,
                  color: const Color(0xFF60A5FA), // Blue
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AnnouncementsScreen()),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
