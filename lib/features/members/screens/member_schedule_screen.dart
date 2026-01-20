import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../dashboard/screens/announcements_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadMyClasses();
    _subscribeToAnnouncements();
    _subscribeToClasses();
  }

  @override
  void dispose() {
    _announcementSubscription?.cancel();
    _classesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _subscribeToClasses() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      _classesSubscription = _supabase
          .from('class_sessions')
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

      final response = await _supabase
          .from('class_sessions')
          .select('*, profiles:trainer_id(first_name, last_name)')
          .eq('member_id', user.id)
          .order('start_time');

      final Map<DateTime, List<dynamic>> events = {};

      for (var session in (response as List)) {
        final startTime = DateTime.parse(session['start_time']).toLocal();
        final date = DateTime(startTime.year, startTime.month, startTime.day);

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
                      Text(
                        'Ders Programım',
                        style: AppTextStyles.title1.copyWith(fontWeight: FontWeight.bold),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: 90, // Show next 3 months
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      // Start from today or slightly before? ClassSchedule starts from today.
                      final date = DateTime.now().add(Duration(days: index));
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

  Widget _buildClassCard(dynamic session) {
    final startTime = DateTime.parse(session['start_time']).toLocal();
    final endTime = DateTime.parse(session['end_time']).toLocal();
    final trainer = session['profiles'];
    final trainerName = trainer != null 
        ? '${trainer['first_name']} ${trainer['last_name']}' 
        : 'Eğitmen';
    
    final status = session['status'] ?? 'scheduled';
    Color statusColor = AppColors.primaryYellow;
    String statusText = 'Planlandı';

    if (status == 'completed') {
      statusColor = AppColors.accentGreen;
      statusText = 'Tamamlandı';
    } else if (status == 'cancelled') {
      statusColor = AppColors.accentRed;
      statusText = 'İptal';
    }

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      border: Border.all(color: statusColor.withOpacity(0.5)),
      child: Row(
        children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('HH:mm').format(startTime),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    DateFormat('HH:mm').format(endTime),
                    style: TextStyle(
                      color: statusColor.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trainerName,
                  style: AppTextStyles.headline,
                ),
                const SizedBox(height: 4),
                Text(
                  session['notes'] ?? 'Ders notu bulunmuyor',
                  style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(
              statusText,
              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
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
