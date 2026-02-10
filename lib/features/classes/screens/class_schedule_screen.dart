import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/class_session.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../shared/widgets/glass_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import 'add_class_screen.dart';
import 'add_class_screen.dart';
import 'class_detail_screen.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/profile_repository.dart';
import 'package:fitflow/shared/widgets/ambient_background.dart';


class ClassScheduleScreen extends StatefulWidget {
  final bool isEmbedded;
  const ClassScheduleScreen({super.key, this.isEmbedded = false});


  @override
  State<ClassScheduleScreen> createState() => _ClassScheduleScreenState();
}

class _ClassScheduleScreenState extends State<ClassScheduleScreen> {
  final _repository = ClassRepository();
  final _profileRepository = ProfileRepository();
  DateTime _selectedDate = DateTime.now();
  List<ClassSession> _classes = [];
  bool _isLoading = true;
  Profile? _currentProfile;
  late ScrollController _dateScrollController;

  @override
  void initState() {
    super.initState();
    // Initialize scroll controller to start at "today" (index 30)
    _dateScrollController = ScrollController(initialScrollOffset: 30 * 72.0);
    _loadCurrentUser();
    // _loadClasses(); // Moved to _loadCurrentUser completion
  }

  Future<void> _loadCurrentUser() async {
    final profile = await _profileRepository.getProfile();
    if (mounted) {
      setState(() {
        _currentProfile = profile;
      });
      // Reload classes after profile is loaded to ensure correct role is used
      _loadClasses();
    }
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    
    // Set range to full day
    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      0, 0, 0
    );
    final endOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      23, 59, 59
    );

    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final isMember = _currentProfile?.role == 'member';
      
      print('🔍 ClassScheduleScreen._loadClasses:');
      print('   currentUserId: $currentUserId');
      print('   _currentProfile: $_currentProfile');
      print('   _currentProfile?.role: ${_currentProfile?.role}');
      print('   isMember: $isMember');
      
      List<ClassSession> classes;
      if (isMember && currentUserId != null) {
        // Members see public classes + their enrolled classes
        print('   📱 Calling getSessionsForMember...');
        
        // DEBUG: Try raw query to see if ANY public class is visible
        try {
           print('   🔍 DEBUG: Testing raw visibility of public classes...');
           final testPublic = await Supabase.instance.client
             .from('class_sessions')
             .select('id, title, start_time, is_public')
             .eq('is_public', true)
             .limit(5);
           print('   🔍 DEBUG: Raw Public Result: $testPublic');
        } catch (e) {
           print('   ❌ DEBUG: Raw Query Error: $e');
        }

        classes = await _repository.getSessionsForMember(startOfDay, endOfDay, currentUserId);
      } else {
        // Trainers/admins see all classes
        print('   👨‍🏫 Calling getSessions (trainer/admin)...');
        classes = await _repository.getSessions(startOfDay, endOfDay);
      }
      
      print('   ✅ Loaded ${classes.length} classes');
      
      if (mounted) {
        setState(() {
          _classes = classes;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('   ❌ Error loading classes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onDateSelected(DateTime date) async {
    setState(() => _selectedDate = date);
    await _loadClasses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
          child: Column(
            children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Dersler',
                        style: AppTextStyles.largeTitle,
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppColors.primaryYellow),
                        onPressed: _loadClasses,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Date Selector
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      controller: _dateScrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: 120, // 30 days past + 90 days future
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        // Start from 30 days ago, so today is at index 30
                        final date = DateTime.now().subtract(const Duration(days: 30)).add(Duration(days: index));
                        final isSelected = _isSameDay(date, _selectedDate);
                        
                        return GestureDetector(
                          onTap: () => _onDateSelected(date),
                          child: Container(
                            width: 60,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryYellow
                                  : AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryYellow
                                    : AppColors.glassBorder,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _getDayName(date.weekday),
                                  style: AppTextStyles.caption1.copyWith(
                                    color: isSelected
                                        ? Colors.black
                                        : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${date.day}',
                                  style: AppTextStyles.title3.copyWith(
                                    color: isSelected
                                        ? Colors.black
                                        : AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Classes List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _classes.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _classes.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildClassItem(_classes[index]),
                        ),
            ),
          ],
        ),
      ),

      floatingActionButton: (_currentProfile?.role == 'admin' || 
                              _currentProfile?.role == 'owner' || 
                              _currentProfile?.role == 'trainer')
        ? FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddClassScreen(initialDate: _selectedDate),
            ),
          );
          if (result == true) {
            _loadClasses();
          }
        },
        backgroundColor: AppColors.primaryYellow,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: Text('Ders Ekle', style: AppTextStyles.headline.copyWith(color: Colors.black)),
      )
      : null,
    );
  }

  Widget _buildClassItem(ClassSession session) {
    return GestureDetector(
      onTap: () async {
        final currentUser = Supabase.instance.client.auth.currentUser;
        final isMember = _currentProfile?.role == 'member';
        
        // Members can view public classes or their enrolled classes
        // Trainers need ownership check (bypass for admin and owner)
        if (!isMember) {
          final isAdminOrOwner = _currentProfile?.role == 'admin' || _currentProfile?.role == 'owner';
          if (!isAdminOrOwner && session.trainerId != null && currentUser?.id != session.trainerId) {
            CustomSnackBar.showError(context, 'Lütfen Eğitmen ile iletişime geçin');
            return;
          }

          if (isAdminOrOwner && currentUser?.id != session.trainerId) {
            CustomSnackBar.showSuccess(context, 'Yönetici yetkisi ile giriş yapıldı', duration: const Duration(seconds: 2));
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }

        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ClassDetailScreen(session: session)),
        );
        if (result == true) {
          _loadClasses();
        }
      },
      child: GlassCard(
        backgroundColor: session.status == 'completed' 
            ? AppColors.accentGreen.withOpacity(0.2) 
            : null,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              children: [
                Text(
                  _formatTime(session.startTime),
                  style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow),
                ),
                Text(
                  '${session.durationMinutes} dk',
                  style: AppTextStyles.caption1,
                ),
              ],
            ),
            Container(
              height: 40,
              width: 1,
              color: AppColors.glassBorder,
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row with Badge
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          session.title,
                          style: AppTextStyles.headline,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (session.isPublic) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryYellow.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.primaryYellow.withOpacity(0.5)),
                          ),
                          child: Text(
                            'Herkese Açık',
                            style: TextStyle(
                              color: AppColors.primaryYellow,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (session.trainerName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 14, color: AppColors.primaryYellow),
                        const SizedBox(width: 4),
                        Text(
                          session.trainerName!,
                          style: AppTextStyles.caption1.copyWith(color: AppColors.primaryYellow),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.people_outline, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Kapasite: ${session.currentEnrollments}/${session.capacity}',
                        style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary, size: 16),
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
          Icon(Icons.calendar_today_rounded, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Bu tarihte ders yok',
            style: AppTextStyles.headline.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni bir ders eklemek için "+" butonuna basın',
            style: AppTextStyles.caption1,
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getDayName(int weekday) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return days[weekday - 1];
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
