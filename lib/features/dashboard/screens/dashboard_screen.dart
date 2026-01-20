import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../members/screens/members_list_screen.dart';
import '../../workouts/screens/workouts_hub_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../chat/screens/inbox_screen.dart';
import '../widgets/stat_card.dart';
import '../../../shared/widgets/glass_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/repositories/member_repository.dart';
import '../../../data/repositories/measurement_repository.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../members/screens/add_edit_member_screen.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import 'package:fitflow/shared/widgets/ambient_background.dart';
import 'package:fitflow/features/dashboard/screens/trainers_list_screen.dart';
import 'package:fitflow/features/dashboard/screens/member_dashboard_screen.dart';
import 'package:fitflow/features/profile/screens/change_password_screen.dart';
import 'announcements_screen.dart';
import '../../../core/services/presence_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  late PageController _pageController;
  bool _isLoading = true;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    try {
      final profile = await ProfileRepository().getProfile();
      if (mounted) {
        setState(() {
          _userRole = profile?.role;
          _isLoading = false;
        });
        
        // Check if user needs to change password on first login
        // SKIP for Google Auth users (they don't use passwords)
        final user = Supabase.instance.client.auth.currentUser;
        final isGoogleAuth = user?.appMetadata['provider'] == 'google';
        
        if (!isGoogleAuth && profile != null && !profile.passwordChanged) {
          // Navigate to password change screen
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const ChangePasswordScreen(isFirstLogin: true),
                ),
              );
            }
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Show Loading
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2. Member Dispatch
    if (_userRole == 'member') {
      return const MemberDashboardScreen();
    }

    // 3. Owner/Trainer Dashboard (Existing)
    void switchToTab(int index) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    final List<Widget> _screens = [
      _DashboardHome(onNavigate: switchToTab),
      const MembersListScreen(),
      const WorkoutsHubScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true, 
      body: AmbientBackground(
        child: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.glassBorder,
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.surfaceDark,
          selectedItemColor: AppColors.primaryYellow,
          unselectedItemColor: AppColors.textSecondary,
          showUnselectedLabels: true,
          selectedLabelStyle: AppTextStyles.caption1.copyWith(
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: AppTextStyles.caption2,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Ana Sayfa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_rounded),
              label: 'Üyeler',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center_rounded),
              label: 'Antrenman',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHome extends StatefulWidget {
  final Function(int) onNavigate;
  const _DashboardHome({required this.onNavigate});

  @override
  State<_DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<_DashboardHome> {
  int _totalMembers = 0;
  int _activeMembers = 0;
  int _totalMeasurements = 0;
  int _todayClasses = 0;
  int _onlineTrainersCount = 0;
  int _unreadMessageCount = 0;
  bool _isLoading = true;
  bool _isOnline = false;
  String _userInitials = 'PT';
  RealtimeChannel? _monitorChannel;
  final _presenceService = PresenceService();

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadUnreadCount(); 
    _setupRealtimeSubscription();
    _setupPresence();
    _loadProfile();
  }

  Future<void> _loadUnreadCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final count = await Supabase.instance.client
          .from('messages')
          .count(CountOption.exact)
          .eq('receiver_id', userId)
          .eq('is_read', false);
      
      if (mounted) {
        setState(() => _unreadMessageCount = count);
      }
    } catch (e) {
      debugPrint('Error loading unread count: $e');
    }
  }

  Future<void> _setupPresence() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      await _presenceService.connect(userId);
      if (mounted) {
        setState(() => _isOnline = true);
      }
    }
  }

  void _setupRealtimeSubscription() {
    _monitorChannel = Supabase.instance.client.channel('dashboard_stats');
    _monitorChannel
      ?.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'members',
        callback: (payload) => _loadStats(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'measurements',
        callback: (payload) => _loadStats(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'class_sessions',
        callback: (payload) => _loadStats(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        callback: (payload) => _loadUnreadCount(),
      )
      .subscribe();
  }

  @override
  void dispose() {
    _presenceService.disconnect();
    if (_monitorChannel != null) {
      Supabase.instance.client.removeChannel(_monitorChannel!);
    }
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final repository = ProfileRepository();
      final profile = await repository.getProfile();
      
      if (profile != null && mounted) {
        String initials = 'PT';
        if (profile.firstName != null && profile.firstName!.isNotEmpty) {
          if (profile.lastName != null && profile.lastName!.isNotEmpty) {
            initials = '${profile.firstName![0]}${profile.lastName![0]}'.toUpperCase();
          } else {
            initials = profile.firstName![0].toUpperCase();
          }
        }
        
        setState(() {
          _userInitials = initials;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final memberRepo = MemberRepository();
      final measurementRepo = MeasurementRepository();
      final classRepo = ClassRepository();

      final totalMembers = await memberRepo.getCount();
      final activeMembers = await memberRepo.getActiveCount();
      // final totalMeasurements = await measurementRepo.getCount(); // Not used
      final todayClasses = await classRepo.getTodaySessionCount();

      // Get count of profiles/trainers
      final trainersCount = await Supabase.instance.client
          .from('profiles')
          .count(CountOption.exact)
          .or('role.eq.trainer,role.eq.admin,role.eq.owner,role.eq.manager');

      if (mounted) {
        setState(() {
          _totalMembers = totalMembers;
          _activeMembers = activeMembers;
          _activeMembers = activeMembers;
          // _totalMeasurements = totalMeasurements;
          _todayClasses = todayClasses;
          _onlineTrainersCount = trainersCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadStats();
            await _loadProfile();
          },
          color: AppColors.primaryYellow,
          backgroundColor: AppColors.surfaceDark,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                  Expanded(
                                    child: RichText(
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: 'Fit',
                                            style: AppTextStyles.largeTitle.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.primaryYellow,
                                              fontSize: 32,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                          TextSpan(
                                            text: 'Flow',
                                            style: AppTextStyles.largeTitle.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.neonCyan, // Cyan/Blue
                                              fontSize: 32,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Stats icons remain unchanged
                                  Row(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (context) => const InboxScreen()),
                                              ).then((_) => _loadUnreadCount());
                                            },
                                            child: GlassCard(
                                              padding: const EdgeInsets.all(8),
                                              borderRadius: BorderRadius.circular(50),
                                              backgroundColor: AppColors.primaryYellow.withOpacity(0.2),
                                              border: Border.all(color: AppColors.primaryYellow, width: 2),
                                              child: const SizedBox(
                                                width: 26,
                                                height: 26,
                                                child: Center(
                                                  child: Icon(
                                                    Icons.mail_outline_rounded,
                                                    color: Colors.white,
                                                    size: 22,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (_unreadMessageCount > 0)
                                            Positioned(
                                              right: -4,
                                              top: -4,
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                constraints: const BoxConstraints(
                                                  minWidth: 18,
                                                  minHeight: 18,
                                                ),
                                                child: Text(
                                                  '$_unreadMessageCount',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => const ProfileScreen(),
                                            ),
                                          ).then((_) => _loadProfile());
                                        },
                                        child: Stack(
                                          children: [
                                            GlassCard(
                                              padding: const EdgeInsets.all(8),
                                              borderRadius: BorderRadius.circular(50),
                                              backgroundColor: AppColors.primaryYellow.withOpacity(0.2),
                                              border: Border.all(color: AppColors.primaryYellow, width: 2),
                                              child: SizedBox(
                                                width: 26,
                                                height: 26,
                                                child: Center(
                                                  child: Text(
                                                    _userInitials,
                                                    style: AppTextStyles.headline.copyWith(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            if (_isOnline)
                                              Positioned(
                                                right: 0,
                                                bottom: 0,
                                                child: Container(
                                                  width: 12,
                                                  height: 12,
                                                  decoration: BoxDecoration(
                                                    color: AppColors.accentGreen,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: AppColors.surfaceDark,
                                                      width: 2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sporcu Takip Sistemi',
                                style: AppTextStyles.subheadline.copyWith(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Stats Grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.35,
                ),
                  delegate: SliverChildListDelegate([
                    StatCard(
                      title: 'Toplam Üye',
                      value: '$_totalMembers',
                      icon: Icons.people_rounded,
                      color: AppColors.accentBlue,
                      onTap: () => widget.onNavigate(1), // Navigate to Members
                      backgroundImage: 'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?q=80&w=1470&auto=format&fit=crop',
                    ),
                    StatCard(
                      title: 'Duyurular',
                      value: '',
                      icon: Icons.campaign_rounded,
                      color: AppColors.primaryYellow,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
                      ),
                      backgroundImage: 'assets/images/pt_megaphone_announcement.png',
                    ),
                     StatCard(
                      title: 'Bugünkü Dersler',
                      value: '$_todayClasses',
                      icon: Icons.fitness_center_rounded,
                      color: AppColors.primaryYellow,
                      onTap: () => widget.onNavigate(2), // Navigate to Classes
                      backgroundImage: 'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?q=80&w=2669&auto=format&fit=crop',
                    ),
                    StatCard(
                      title: 'Eğitmenler',
                      value: '$_onlineTrainersCount',
                      icon: Icons.assignment_ind_rounded,
                      color: AppColors.accentOrange,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const TrainersListScreen(),
                          ),
                        );
                      },
                      backgroundImage: 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?q=80&w=1470&auto=format&fit=crop',
                    ),
                  ]),
                ),
              ),

              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Hızlı İşlemler',
                        style: AppTextStyles.title3.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      _QuickActionButton(
                        icon: Icons.person_add_rounded,
                        title: 'Yeni Üye Ekle',
                        subtitle: 'Sisteme yeni sporcu kaydet',
                        color: AppColors.accentBlue,
                        backgroundImage: 'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?q=80&w=1470&auto=format&fit=crop',
                        onTap: () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const AddEditMemberScreen(),
                            ),
                          );
                          if (result == true) {
                            if (context.mounted) {
                              CustomSnackBar.showSuccess(
                                context, 
                                'Üye başarıyla eklendi',
                              );
                            }
                            _loadStats();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _QuickActionButton(
                        icon: Icons.straighten_rounded,
                        title: 'Ölçüm Yap',
                        subtitle: 'Sporcunun ölçümlerini kaydet',
                        color: AppColors.accentOrange,
                        backgroundImage: 'https://images.unsplash.com/photo-1576678927484-cc907957088c?q=80&w=1469&auto=format&fit=crop',
                        onTap: () {
                          widget.onNavigate(1);
                          CustomSnackBar.showError(
                            context,
                            'Lütfen ölçüm eklemek istediğiniz üyeyi seçin.',
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _QuickActionButton(
                        icon: Icons.add_circle_rounded,
                        title: 'Ders Oluştur',
                        subtitle: 'Yeni ders programı ekle',
                        color: AppColors.primaryYellow,
                        backgroundImage: 'https://images.unsplash.com/photo-1601422407692-ec4eeec1d9b3?q=80&w=1450&auto=format&fit=crop',
                        onTap: () {
                          widget.onNavigate(2);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? backgroundImage;

  const _QuickActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.backgroundImage,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Background Image
          if (backgroundImage != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: backgroundImage!,
                  fit: BoxFit.cover,
                  color: Colors.black.withOpacity(0.7),
                  colorBlendMode: BlendMode.darken,
                ),
              ),
            ),
            
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: backgroundImage != null 
                        ? Colors.white.withOpacity(0.1) 
                        : color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: backgroundImage != null
                        ? Border.all(color: Colors.white.withOpacity(0.2))
                        : null,
                  ),
                  child: Icon(
                    icon,
                    color: backgroundImage != null ? Colors.white : color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.headline.copyWith(
                          color: backgroundImage != null ? Colors.white : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTextStyles.subheadline.copyWith(
                           color: backgroundImage != null 
                              ? Colors.white.withOpacity(0.7) 
                              : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: backgroundImage != null 
                      ? Colors.white.withOpacity(0.5) 
                      : AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
