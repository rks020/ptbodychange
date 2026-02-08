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
import 'package:fitflow/features/dashboard/widgets/stat_card.dart';
import 'package:fitflow/features/dashboard/screens/announcements_screen.dart';
import '../../../core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../chat/screens/chat_screen.dart';

class MemberDashboardScreen extends StatefulWidget {
  const MemberDashboardScreen({super.key});

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen> {
  int _currentIndex = 0;
  final _supabase = Supabase.instance.client;
  int _unreadCount = 0;
  late final PageController _pageController; // Define PageController

  // Tabs
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(); // Initialize Controller
    _screens = [
      _MemberHomeScreen(onTabChange: _onTabTapped), // Tab 0: Home
      const MemberScheduleScreen(),                 // Tab 1: Program
      const MemberDietScreen(),                     // Tab 2: Diet
      const MemberMeasurementsScreen(),             // Tab 3: Progress
      const ProfileScreen(),                        // Tab 4: Profile
    ];
    _loadUnreadCount();
    _loadUnreadCount();
    _setupRealtimeSubscription();
    
    // Handle pending notification
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingNotification();
    });
  }

  @override
  void dispose() {
    _pageController.dispose(); // Dispose Controller
    super.dispose();
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

  void _handlePendingNotification() {
    final pendingMessage = NotificationService.getPendingMessage();
    if (pendingMessage != null && mounted) {
      debugPrint('🔔 MemberDashboardScreen: Processing pending notification');
      final data = pendingMessage.data;
      final type = data['type'];
      
      if (type == 'announcement') {
        debugPrint('🔔 MemberDashboardScreen: Navigating to Announcements');
        NotificationService.clearPendingMessage();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
        ); // .then((_) => _loadUnreadAnnouncements()); // Moved to MemberHomeScreen
      } else if (type == 'chat') {
        NotificationService.clearPendingMessage();
        final senderId = data['sender_id'];
        final senderName = data['sender_name'] ?? 'Kullanıcı';
        final senderAvatar = data['sender_avatar'];
         
        if (senderId != null) {
          debugPrint('🔔 MemberDashboardScreen: Navigating to Chat');
          final dummyProfile = Profile(
            id: senderId,
            firstName: senderName.split(' ').first,
            lastName: senderName.split(' ').length > 1 ? senderName.split(' ').last : '',
            avatarUrl: senderAvatar,
          );
           
          // Navigate only to ChatScreen
           Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => ChatScreen(otherUser: dummyProfile),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        }
      }
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    // Animate to page when tab is tapped
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
  
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // If not on Home tab (index 0), go back to Home first
        if (_currentIndex != 0) {
          _onTabTapped(0);
          return false; // Prevent exiting app
        }
        return true; // Exit app if already on Home
      },
      child: Scaffold(
      extendBody: true,
      body: AmbientBackground(
        child: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const BouncingScrollPhysics(), // Provide nice bounce effect
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

  int _unreadAnnouncementsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadUnreadAnnouncements();
    _setupRealtimeSubscription();
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

  Future<void> _loadUnreadAnnouncements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastViewStr = prefs.getString('last_announcements_view_time');
      final supabase = Supabase.instance.client;
      
      int count = 0;
      if (lastViewStr != null) {
        final result = await supabase
            .from('announcements')
            .select()
            .gt('created_at', lastViewStr);
        count = result.length;
      } else {
        final result = await supabase
            .from('announcements')
            .select();
        count = result.length;
      }
      
      if (mounted) setState(() => _unreadAnnouncementsCount = count);
    } catch (e) {
      debugPrint('Error loading unread announcements: $e');
    }
  }

  void _setupRealtimeSubscription() {
    Supabase.instance.client.channel('member_home_announcements')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'announcements',
        callback: (payload) => _loadUnreadAnnouncements(),
      )
      .subscribe();
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
                GestureDetector(
                  onTap: () => widget.onTabChange(4), // Navigate to Profile (Index 4)
                  child: Container(
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
                  backgroundImage: 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?q=80&w=1470&auto=format&fit=crop',
                ),
                
                // Beslenme / Diyetim
                StatCard(
                  title: 'Diyetim',
                  value: 'Öğünler',
                  icon: Icons.restaurant_menu_rounded,
                  color: const Color(0xFFF472B6), // Pink/Red
                  onTap: () => widget.onTabChange(2), // Tab 2: Diet
                  backgroundImage: 'https://images.unsplash.com/photo-1498837167922-ddd27525d352?q=80&w=1470&auto=format&fit=crop',
                ),

                // Gelişimim
                StatCard(
                  title: 'Gelişimim',
                  value: 'İstatistikler',
                  icon: Icons.show_chart_rounded,
                  color: const Color(0xFF34D399), // Green
                  onTap: () => widget.onTabChange(3), // Tab 3: Measurements
                  backgroundImage: 'https://images.unsplash.com/photo-1576678927484-cc907957088c?q=80&w=1469&auto=format&fit=crop',
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
                    ).then((_) => _loadUnreadAnnouncements());
                  },
                  backgroundImage: 'assets/images/pt_megaphone_announcement.png',
                  badgeCount: _unreadAnnouncementsCount,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
