import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../dashboard/screens/announcements_screen.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../data/models/class_session.dart';
import '../../classes/screens/class_detail_screen.dart';

class MemberScheduleScreen extends StatefulWidget {
  const MemberScheduleScreen({super.key});

  @override
  State<MemberScheduleScreen> createState() => _MemberScheduleScreenState();
}

class _MemberScheduleScreenState extends State<MemberScheduleScreen> {
  final _supabase = Supabase.instance.client;
  DateTime _selectedDate = DateTime.now();
  Map<DateTime, List<dynamic>> _events = {};
  StreamSubscription? _announcementSubscription;
  StreamSubscription? _classesSubscription;
  List<dynamic> _latestAnnouncements = [];
  bool _isLoading = true;
  int _unreadAnnouncements = 0;
  late ScrollController _dateScrollController;

  @override
  void initState() {
    super.initState();
    // Initialize scroll controller to start at "today" (index 30)
    // Each item is 60px wide + 12px separator = 72px
    _dateScrollController = ScrollController(initialScrollOffset: 30 * 72.0);
    _loadMyClasses();
    _subscribeToAnnouncements();
    _subscribeToClasses();
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    _announcementSubscription?.cancel();
    _classesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _subscribeToClasses() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      _classesSubscription = _supabase
          .from('class_enrollments')
          .stream(primaryKey: ['id'])
          .eq('member_id', user.id)
          .listen((data) {
            _loadMyClasses();
          });
    } catch (e) {
      debugPrint('Error subscribing to classes: $e');
    }
  }

  Future<void> _subscribeToAnnouncements() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final memberData = await _supabase
          .from('members')
          .select('organization_id')
          .eq('id', user.id)
          .maybeSingle();

      if (memberData == null || memberData['organization_id'] == null) return;
      final orgId = memberData['organization_id'];

      _announcementSubscription = _supabase
          .from('announcements')
          .stream(primaryKey: ['id'])
          .eq('organization_id', orgId)
          .listen((data) {
            if (!mounted) return;
            _latestAnnouncements = data;
            _calculateUnread();
          });
    } catch (e) {
      debugPrint('Error subscribing to announcements: $e');
    }
  }

  Future<void> _calculateUnread() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastViewedStr = prefs.getString('last_announcements_view_time');
      final lastViewed = lastViewedStr != null ? DateTime.parse(lastViewedStr) : null;
      
      int unread = 0;
      for (var item in _latestAnnouncements) {
        final created = DateTime.parse(item['created_at']);
        if (lastViewed == null || created.isAfter(lastViewed)) {
           unread++;
        }
      }

      if (mounted) {
        setState(() {
          _unreadAnnouncements = unread;
        });
      }
    } catch (e) {
      debugPrint('Error calculating unread: $e');
    }
  }

  Future<void> _refreshUnreadCount() async {
     await _calculateUnread();
  }


  Future<void> _loadMyClasses() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final repository = ClassRepository();
      // Fetch 30 days past and 90 days future. Adjust as needed.
      final start = DateTime.now().subtract(const Duration(days: 30));
      final end = DateTime.now().add(const Duration(days: 90));

      final sessions = await repository.getSessionsForMember(start, end, user.id);
      
      final Map<DateTime, List<dynamic>> events = {};
      
      for (var session in sessions) {
        final date = DateTime(session.startTime.year, session.startTime.month, session.startTime.day);
        if (events[date] == null) events[date] = [];
        events[date]!.add(session);
      }

      if (mounted) {
        setState(() {
          _events = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading classes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _getClassesForSelectedDate() {
    final dateKey = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return _events[dateKey] ?? [];
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    final todaysClasses = _getClassesForSelectedDate();

    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Text(
                            'Ders Programım',
                            style: AppTextStyles.title1.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.glassBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_none_rounded, color: AppColors.primaryYellow),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const AnnouncementsScreen()),
                                  );
                                  // Refresh unread count when returning
                                  _refreshUnreadCount();
                                },
                              ),
                              if (_unreadAnnouncements > 0)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      '$_unreadAnnouncements',
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
                        ),
                    ],
                  ),
                ),
                
                // Horizontal Date Picker (From ClassScheduleScreen)
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    controller: _dateScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                
                const SizedBox(height: 20),
                
                // Classes List
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadMyClasses,
                    color: AppColors.primaryYellow,
                    backgroundColor: AppColors.surfaceDark,
                    child: todaysClasses.isEmpty 
                      ? Stack(
                          children: [
                            ListView(), // Always scrollable for RefreshIndicator
                            _buildEmptyState(),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: todaysClasses.length,
                          itemBuilder: (context, index) {
                            final session = todaysClasses[index];
                            return _buildClassCard(session);
                          },
                        ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildClassCard(dynamic sessionData) {
    if (sessionData is! ClassSession) return const SizedBox.shrink(); // Safety check
    final session = sessionData;

    final startTime = session.startTime;
    final endTime = session.endTime;
    final trainerName = session.trainerName != null 
        ? 'PT: ${session.trainerName}' 
        : 'PT: Eğitmen';
    
    final status = session.status;
    Color statusColor = AppColors.primaryYellow;
    String statusText = 'Planlandı';

    if (status == 'completed') {
      statusColor = AppColors.accentGreen;
      statusText = 'Tamamlandı';
    } else if (status == 'cancelled') {
      statusColor = AppColors.accentRed;
      statusText = 'İptal';
    }

    final workoutName = session.workoutName;

    final isPublic = session.isPublic; 
    final isFull = session.currentEnrollments >= session.capacity;

    return GestureDetector(
      onTap: () {
        // Only allow clicking on public classes
        if (!isPublic) {
          return; // Do nothing for personal PT sessions
        }
        
        // Check if class is full
        if (isFull) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bu dersin kapasitesi doldu'),
              backgroundColor: AppColors.accentRed,
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        
        // Navigate to class detail
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClassDetailScreen(
              session: session,
            ),
          ),
        ).then((_) => _loadMyClasses()); 
      },
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        border: Border.all(color: statusColor.withOpacity(0.5)),
        child: Row(
          children: [
            // Time Column
            Column(
              children: [
                Text(
                  DateFormat('HH:mm').format(startTime),
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
            // Main Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Title Row
                   Row(
                    children: [
                      Flexible(
                        child: Text(
                          session.title,
                          style: AppTextStyles.headline,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                       if (isPublic) ...[
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
                  const SizedBox(height: 4),
                  // Trainer Row
                  if (session.trainerName != null) ...[
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
                    const SizedBox(height: 4),
                  ],
                  // Capacity / Enrollment Ratio
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
}
